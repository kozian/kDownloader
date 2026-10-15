import Foundation
import Testing
@testable import KDownloaderCore

struct AppSettingsTests {
    let defaults: UserDefaults
    let downloads = URL(filePath: "/Users/someone/Downloads", directoryHint: .isDirectory)

    init() {
        let suite = "AppSettingsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    private var settings: AppSettings { AppSettings(defaults: defaults, downloadsDirectory: downloads) }

    @Test func defaultsToDownloads() {
        let folder = settings.destinationFolder()
        #expect(folder.url == downloads)
        #expect(!folder.savedFolderMissing)
    }

    @Test func remembersChosenFolder() throws {
        let movies = FileManager.default.temporaryDirectory.appending(path: "Movies-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: movies, withIntermediateDirectories: true)
        settings.setDestinationFolder(movies)

        // A new instance reads what the previous one saved, like after a relaunch.
        let folder = AppSettings(defaults: defaults, downloadsDirectory: downloads).destinationFolder()
        #expect(folder.url.path == movies.path)
        #expect(!folder.savedFolderMissing)
    }

    @Test func fallsBackWhenFolderIsGone() {
        settings.setDestinationFolder(URL(filePath: "/Volumes/Unplugged/Videos"))
        let folder = settings.destinationFolder()
        #expect(folder.url == downloads)
        #expect(folder.savedFolderMissing)
    }

    @Test func showAllFormatsIsOffByDefaultAndRemembered() {
        #expect(!settings.showAllFormats)
        settings.setShowAllFormats(true)
        #expect(AppSettings(defaults: defaults, downloadsDirectory: downloads).showAllFormats)
    }
}
