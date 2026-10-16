import Foundation
import KDownloaderCore
import Observation

/// Checking for, installing and reverting yt-dlp updates.
@MainActor
@Observable
final class UpdatesModel {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case installing(progress: Double)
        case failed(UpdateError)
    }

    private(set) var status: Status = .idle
    /// Bumped whenever the stored check state changes, so views re-read it.
    private var revision = 0

    private unowned let app: AppModel
    private let state = UpdateState()
    private let source = YtDlpReleaseSource(http: URLSessionHTTPClient())

    init(app: AppModel) {
        self.app = app
    }

    /// A newer yt-dlp than the active one is known.
    var availableVersion: YtDlpVersion? {
        _ = revision
        guard let active = app.activeYtDlp?.version else { return nil }
        return state.availableUpdate(active: active)
    }

    var canInstall: Bool {
        availableVersion != nil && !app.operationInProgress && !isInstalling
    }

    var isInstalling: Bool {
        if case .installing = status { true } else { false }
    }

    /// The automatic check at launch, at most once a day.
    func checkIfDue() {
        guard state.isCheckDue(now: .now) else { return }
        Task { await check(automatic: true) }
    }

    /// "Check for Updates".
    func checkNow() {
        Task { await check(automatic: false) }
    }

    private func check(automatic: Bool) async {
        guard !isInstalling else { return }
        if !automatic { status = .checking }
        do {
            let latest = try await source.latest()
            state.recordCheck(latest: latest.version, at: .now)
            await app.log?.write("latest yt-dlp release: \(latest.version)", category: "update")
            status = availableVersion == nil && !automatic ? .upToDate : .idle
        } catch let error as UpdateError {
            state.recordFailedCheck(at: .now)
            await app.log?.write("update check failed: \(error)", category: "update")
            status = automatic ? .idle : .failed(error)
        } catch {
            status = automatic ? .idle : .failed(.network(error.localizedDescription))
        }
        revision += 1
    }

    /// "Install": downloads, verifies and activates the latest release.
    func install() {
        guard canInstall else { return }
        status = .installing(progress: 0)
        Task {
            do {
                // Always ask again: the known version may be stale.
                let release = try await source.latest()
                state.recordCheck(latest: release.version, at: .now)
                if let active = app.activeYtDlp?.version, release.version <= active {
                    status = .upToDate
                    revision += 1
                    return
                }
                let installed = try await app.installer.install(release) { progress in
                    Task { @MainActor in
                        if case .installing = self.status { self.status = .installing(progress: progress) }
                    }
                }
                await app.activate(ActiveYtDlp(version: installed.version, executable: installed.executable, source: .updated))
                status = .idle
            } catch let error as UpdateError {
                await app.log?.write("update failed: \(error)", category: "update")
                status = .failed(error)
            } catch {
                status = .failed(.installFailed(error.localizedDescription))
            }
            revision += 1
        }
    }

    var lastCheck: Date? {
        _ = revision
        return state.lastCheck
    }

    /// "Use Bundled Version".
    func useBundledVersion() {
        guard let bundledVersion = app.bundledYtDlpVersion, !app.operationInProgress, !isInstalling else { return }
        Task {
            do {
                let active = try await YtDlpSelector(installer: app.installer, log: app.log)
                    .revertToBundled(bundled: app.bundledTools.ytDlp, bundledVersion: bundledVersion)
                await app.activate(active)
                status = .idle
            } catch let error as UpdateError {
                status = .failed(error)
            } catch {
                status = .failed(.installFailed(error.localizedDescription))
            }
            revision += 1
        }
    }
}
