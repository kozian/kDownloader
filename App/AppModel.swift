import AppKit
import Foundation
import KDownloaderCore
import Observation
import UserNotifications

/// State shared by all windows of the app.
@MainActor
@Observable
final class AppModel {
    enum ToolState: Equatable {
        case checking
        case ready(versions: [Tool: String])
        case broken(tool: Tool, reason: String)
    }

    let log: LogStore?
    let runner: ToolRunner
    /// Tools inside the app bundle.
    let bundledTools: ToolLocator
    /// Client for the active yt-dlp; rebuilt when an update is installed or reverted.
    private(set) var ytDlp: YtDlpClient
    let settings = AppSettings()
    private(set) var toolState: ToolState = .checking
    /// The yt-dlp in use: bundled or installed by the app.
    private(set) var activeYtDlp: ActiveYtDlp?
    private(set) var bundledYtDlpVersion: YtDlpVersion?
    /// An analysis or download is running; updates wait for it.
    var operationInProgress = false
    let installer: YtDlpInstaller
    private(set) var updates: UpdatesModel?
    /// The "Show all formats" setting, persisted.
    var showAllFormats: Bool {
        didSet { settings.setShowAllFormats(showAllFormats) }
    }
    private let notifications = DownloadNotifications()

    var toolsReady: Bool {
        if case .ready = toolState { true } else { false }
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    /// Folder name for logs and installed updates: "kDownloader" for the regular
    /// app, "kDownloader-<suffix>" for test builds with another bundle identifier.
    static func storageName(for bundle: Bundle) -> String {
        let regular = "com.kozian.kDownloader"
        guard let identifier = bundle.bundleIdentifier, identifier != regular,
              identifier.hasPrefix(regular + ".") else { return "kDownloader" }
        return "kDownloader-" + identifier.dropFirst(regular.count + 1)
    }

    init(bundle: Bundle = .main) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let storage = Self.storageName(for: bundle)
        let log = try? LogStore(directory: home.appending(path: "Library/Logs/\(storage)"))
        self.log = log
        self.runner = ToolRunner(log: log)
        self.bundledTools = ToolLocator(appBundle: bundle.bundleURL)
        self.ytDlp = YtDlpClient(tools: bundledTools, runner: runner)
        self.installer = YtDlpInstaller(
            root: home.appending(path: "Library/Application Support/\(storage)/yt-dlp"),
            http: URLSessionHTTPClient(), runner: runner, log: log
        )
        self.showAllFormats = settings.showAllFormats
        UNUserNotificationCenter.current().delegate = notifications
        self.updates = UpdatesModel(app: self)
        Task { await start() }
    }

    /// Runs the launch-time tool check once.
    private func start() async {
        await log?.write("kDownloader \(Self.appVersion) launched")
        let result = await ToolChecker(locator: bundledTools, runner: runner).check()
        switch result {
        case .ready(let versions):
            let summary = Tool.allCases.map { "\($0.rawValue) \(versions[$0] ?? "?")" }.joined(separator: ", ")
            await log?.write("bundled tools: \(summary)")
            toolState = .ready(versions: versions)
            if let bundledVersion = versions[.ytDlp].flatMap(YtDlpVersion.init) {
                bundledYtDlpVersion = bundledVersion
                let active = await YtDlpSelector(installer: installer, log: log)
                    .choose(bundled: bundledTools.ytDlp, bundledVersion: bundledVersion)
                await activate(active)
                updates?.checkIfDue()
            } else {
                await log?.write("bundled yt-dlp reports an unknown version; in-app updates are off")
            }
        case .broken(let tool, let reason):
            await log?.write("tool check failed: \(tool.rawValue): \(reason)")
            toolState = .broken(tool: tool, reason: reason)
        }
    }

    /// Switches to `active` for the next operations; a running one keeps its client.
    func activate(_ active: ActiveYtDlp) async {
        activeYtDlp = active
        let tools = ToolLocator(ytDlp: active.executable, ffmpeg: bundledTools.ffmpeg, ffprobe: bundledTools.ffprobe, deno: bundledTools.deno)
        ytDlp = YtDlpClient(tools: tools, runner: runner)
        if case .ready(var versions) = toolState {
            versions[.ytDlp] = active.version.description
            toolState = .ready(versions: versions)
        }
        let source = active.source == .updated ? "updated" : "bundled"
        await log?.write("using \(source) yt-dlp \(active.version): \(active.executable.path)")
    }

    /// Posts "Download complete"; clicking it reveals the file in Finder.
    /// Without permission the download simply completes silently.
    func notifyDownloadFinished(title: String, file: URL) {
        let log = log
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else {
                await log?.write("notifications are not allowed")
                return
            }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Download complete")
            content.body = title
            content.sound = .default
            content.userInfo = [DownloadNotifications.fileKey: file.path]
            try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}

/// Reveals the downloaded file when the user clicks the notification.
final class DownloadNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let fileKey = "file"

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let path = response.notification.request.content.userInfo[Self.fileKey] as? String else { return }
        await MainActor.run {
            NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: path)])
        }
    }

    /// Show the banner even when kDownloader is the active app.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
