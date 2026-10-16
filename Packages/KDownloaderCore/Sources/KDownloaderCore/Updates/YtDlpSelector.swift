import Foundation

/// The yt-dlp the app uses right now.
public struct ActiveYtDlp: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        case bundled
        case updated
    }

    public var version: YtDlpVersion
    public var executable: URL
    public var source: Source

    public init(version: YtDlpVersion, executable: URL, source: Source) {
        self.version = version
        self.executable = executable
        self.source = source
    }
}

/// Picks the yt-dlp to use: the newest installed update that is newer than the
/// bundled one and runs, otherwise the bundled one.
public struct YtDlpSelector: Sendable {
    private let installer: YtDlpInstaller
    private let log: LogStore?

    public init(installer: YtDlpInstaller, log: LogStore?) {
        self.installer = installer
        self.log = log
    }

    /// - Parameters:
    ///   - bundled: path of the bundled yt-dlp.
    ///   - bundledVersion: the version the bundled yt-dlp reported at launch.
    public func choose(bundled: URL, bundledVersion: YtDlpVersion) async -> ActiveYtDlp {
        for candidate in installer.installed() where candidate.version > bundledVersion {
            let reported = try? await installer.version(of: candidate.executable)
            if reported == candidate.version {
                return ActiveYtDlp(version: candidate.version, executable: candidate.executable, source: .updated)
            }
            await log?.write("installed yt-dlp \(candidate.version) does not run correctly, skipping it", category: "update")
        }
        return ActiveYtDlp(version: bundledVersion, executable: bundled, source: .bundled)
    }

    /// "Use Bundled Version": removes every installed update.
    public func revertToBundled(bundled: URL, bundledVersion: YtDlpVersion) async throws -> ActiveYtDlp {
        do {
            try installer.removeAll()
        } catch {
            throw UpdateError.installFailed("cannot remove the installed updates: \(error.localizedDescription)")
        }
        await log?.write("switched to the bundled yt-dlp \(bundledVersion)", category: "update")
        return ActiveYtDlp(version: bundledVersion, executable: bundled, source: .bundled)
    }
}
