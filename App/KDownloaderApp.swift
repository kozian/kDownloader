import SwiftUI

@main
struct KDownloaderApp: App {
    @State private var model = AppModel()

    init() {
        #if DEBUG
        WindowSnapshot.install()
        #endif
    }

    var body: some Scene {
        // A WindowGroup opens reliably at launch; "New Window" is removed so
        // there is only ever one main window.
        WindowGroup("kDownloader", id: WindowID.main) {
            ContentView()
                .environment(model)
        }
        .windowResizability(.contentSize)
        .commands {
            AboutCommand()
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environment(model)
        }

        Window("Log", id: WindowID.log) {
            LogWindow()
                .environment(model)
        }
        .defaultSize(width: 760, height: 480)

        Window("About kDownloader", id: WindowID.about) {
            AboutView()
                .environment(model)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}

enum WindowID {
    static let main = "main"
    static let about = "about"
    static let log = "log"
}

private struct AboutCommand: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About kDownloader") {
                openWindow(id: WindowID.about)
            }
        }
    }
}
