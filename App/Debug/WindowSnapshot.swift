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
    static let clickNotification = Notification.Name("com.kozian.kDownloader.debug.click")
    static let keyNotification = Notification.Name("com.kozian.kDownloader.debug.key")

    @MainActor
    static func install() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: snapshotNotification, object: nil, queue: .main) { note in
            guard let directory = note.object as? String else { return }
            MainActor.assumeIsolated { capture(into: URL(filePath: directory)) }
        }
        // "x,y" in points from the top-left corner of the main window: a click there.
        center.addObserver(forName: clickNotification, object: nil, queue: .main) { note in
            guard let text = note.object as? String else { return }
            MainActor.assumeIsolated { click(text) }
        }
        center.addObserver(forName: keyNotification, object: nil, queue: .main) { note in
            guard let key = note.object as? String else { return }
            MainActor.assumeIsolated { press(key) }
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
    private static func click(_ text: String) {
        // "<window title>@x,y" clicks in another window than the main one.
        let parts = text.split(separator: "@", maxSplits: 1).map(String.init)
        let title = parts.count == 2 ? parts[0] : "kDownloader"
        let numbers = parts.last!.replacingOccurrences(of: "move:", with: "").split(separator: ",").compactMap { Double($0) }
        guard numbers.count == 2,
              let window = NSApp.windows.first(where: { $0.isVisible && $0.title == title }),
              let content = window.contentView else { return }
        let point = NSPoint(x: numbers[0], y: content.bounds.height - numbers[1])
        let types: [NSEvent.EventType] = parts.last!.hasPrefix("move") ? [.mouseMoved] : [.leftMouseDown, .leftMouseUp]
        for type in types {
            if let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                              windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) {
                NSApp.postEvent(event, atStart: false)
            }
        }
    }

    @MainActor
    private static func press(_ key: String) {
        let codes: [String: (UInt16, String)] = ["escape": (53, "\u{1b}"), "down": (125, ""), "return": (36, "\r")]
        guard let (code, characters) = codes[key], let window = NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible) else { return }
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            if let event = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                            windowNumber: window.windowNumber, context: nil, characters: characters,
                                            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code) {
                NSApp.postEvent(event, atStart: false)
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
            var classes: [String: Int] = [:]
            func collect(_ view: NSView) {
                classes[String(describing: type(of: view)), default: 0] += 1
                view.subviews.forEach(collect)
            }
            collect(view)
            try? classes.sorted { $0.key < $1.key }.map { "\($0.value)\t\($0.key)" }.joined(separator: "\n")
                .write(to: directory.appending(path: "\(name)-views.txt"), atomically: true, encoding: .utf8)
            if !scrollInfo.isEmpty {
                try? scrollInfo.joined(separator: "\n").write(to: directory.appending(path: "\(name)-scroll.txt"), atomically: true, encoding: .utf8)
            }
        }
    }
}
#endif
