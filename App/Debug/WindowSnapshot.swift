#if DEBUG
import AppKit

/// Debug-only: renders app windows to PNG files and triggers menu items on
/// request, so the UI can be checked from the command line without Screen
/// Recording or Accessibility permissions.
///
///     scripts/snapshot.swift <output-directory>
///     scripts/snapshot.swift --menu "About kDownloader"
enum WindowSnapshot {
    static let snapshotNotification = Notification.Name("com.kozian.kDownloader.debug.snapshot")
    static let menuNotification = Notification.Name("com.kozian.kDownloader.debug.menu")

    @MainActor
    static func install() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: snapshotNotification, object: nil, queue: .main) { note in
            guard let directory = note.object as? String else { return }
            MainActor.assumeIsolated { capture(into: URL(filePath: directory)) }
        }
        center.addObserver(forName: menuNotification, object: nil, queue: .main) { note in
            guard let title = note.object as? String else { return }
            MainActor.assumeIsolated {
                if let mainMenu = NSApp.mainMenu {
                    perform(title, in: mainMenu)
                }
            }
        }
    }

    @MainActor
    private static func popUpButtons(in view: NSView) -> [NSPopUpButton] {
        (view as? NSPopUpButton).map { [$0] } ?? view.subviews.flatMap(popUpButtons)
    }

    @MainActor
    private static func scrollViews(in view: NSView) -> [NSScrollView] {
        (view as? NSScrollView).map { [$0] } ?? view.subviews.flatMap(scrollViews)
    }

    @MainActor
    @discardableResult
    private static func perform(_ title: String, in menu: NSMenu) -> Bool {
        menu.update()
        for (index, item) in menu.items.enumerated() {
            if item.title == title {
                menu.performActionForItem(at: index)
                return true
            }
            if let submenu = item.submenu, perform(title, in: submenu) {
                return true
            }
        }
        return false
    }

    @MainActor
    private static func capture(into directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (index, window) in NSApp.windows.enumerated() where window.isVisible {
            guard let view = window.contentView?.superview ?? window.contentView,
                  let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let name = window.title.isEmpty ? "window-\(index)" : window.title
            let url = directory.appending(path: "\(name).png")
            try? bitmap.representation(using: .png, properties: [:])?.write(to: url)
            let scrollInfo = scrollViews(in: view).map { scrollView in
                let visible = scrollView.documentVisibleRect
                let height = scrollView.documentView?.frame.height ?? 0
                return "visible y=\(Int(visible.minY))…\(Int(visible.maxY)) of \(Int(height))"
            }
            let menus = popUpButtons(in: view).map { button in
                let items = button.itemArray.map { ($0.isSeparatorItem ? "----" : $0.title) + ($0 == button.selectedItem ? "  ← selected" : "") }
                return (button.isEnabled ? "[enabled]" : "[disabled]") + "\n  " + items.joined(separator: "\n  ")
            }
            if !menus.isEmpty {
                try? menus.joined(separator: "\n").write(to: directory.appending(path: "\(name)-menus.txt"), atomically: true, encoding: .utf8)
            }
            if !scrollInfo.isEmpty {
                try? scrollInfo.joined(separator: "\n").write(to: directory.appending(path: "\(name)-scroll.txt"), atomically: true, encoding: .utf8)
            }
        }
    }
}
#endif
