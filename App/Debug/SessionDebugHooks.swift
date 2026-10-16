#if DEBUG
import Foundation
import KDownloaderCore

/// Debug-only: lets `scripts/snapshot.swift --session <command>` drive the main
/// window, e.g. `type:https://…`, `analyze`, `cancel`, `retry`,
/// `video:best|none|<height>|f:<format id>`, `audio:<id>|none`, `all:on|off`,
/// `folder:<path>`, `download`, `cancelDownload`, `newDownload`, `showInFinder`,
/// `browser:<id>|none` (answers the browser dialog), `update:check|install|bundled`.
extension SessionModel {
    static let debugNotification = Notification.Name("com.kozian.kDownloader.debug.session")

    func installDebugHooks() {
        DistributedNotificationCenter.default().addObserver(
            forName: Self.debugNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let command = note.object as? String else { return }
            MainActor.assumeIsolated { self?.runDebugCommand(command) }
        }
    }

    private func runDebugCommand(_ command: String) {
        let parts = command.split(separator: ":", maxSplits: 1).map(String.init)
        if parts.count == 2 {
            let value = parts[1]
            switch parts[0] {
            case "type": urlText = value
            case "video":
                videoChoice = switch value {
                case "best": .bestCompatible
                case "none": .none
                case _ where value.hasPrefix("f:"): .format(String(value.dropFirst(2)))
                default: .height(Int(value) ?? 0)
                }
            case "audio": audioChoice = value == "none" ? .none : .track(value)
            case "all": app.showAllFormats = value == "on"
            case "update":
                switch value {
                case "check": app.updates?.checkNow()
                case "install": app.updates?.install()
                case "bundled": app.updates?.useBundledVersion()
                default: break
                }
            case "folder": setDestination(URL(filePath: value, directoryHint: .isDirectory))
            case "browser": answerBrowserRequest(CookieBrowser.named(value).map(CookieBrowserChoice.browser) ?? .declined)
            default: break
            }
            return
        }
        switch command {
        case "analyze": analyze()
        case "cancel": cancelAnalysis()
        case "retry": retry()
        case "download": download()
        case "cancelDownload": cancelDownload()
        case "newDownload": startNewDownload()
        case "showInFinder": showInFinder()
        default: break
        }
    }
}
#endif
