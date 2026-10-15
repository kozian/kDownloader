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
    let tools: ToolLocator
    let ytDlp: YtDlpClient
    let settings = AppSettings()
    private(set) var toolState: ToolState = .checking
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

    init(bundle: Bundle = .main) {
        let log = try? LogStore(directory: LogStore.defaultDirectory)
        self.log = log
        self.runner = ToolRunner(log: log)
        self.tools = ToolLocator(appBundle: bundle.bundleURL)
        self.ytDlp = YtDlpClient(tools: tools, runner: runner)
        self.showAllFormats = settings.showAllFormats
        UNUserNotificationCenter.current().delegate = notifications
        Task { await start() }
    }

    /// Runs the launch-time tool check once.
    private func start() async {
        await log?.write("kDownloader \(Self.appVersion) launched")
        let result = await ToolChecker(locator: tools, runner: runner).check()
        switch result {
        case .ready(let versions):
            let summary = Tool.allCases.map { "\($0.rawValue) \(versions[$0] ?? "?")" }.joined(separator: ", ")
            await log?.write("tools: \(summary)")
            toolState = .ready(versions: versions)
        case .broken(let tool, let reason):
            await log?.write("tool check failed: \(tool.rawValue): \(reason)")
            toolState = .broken(tool: tool, reason: reason)
        }
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
