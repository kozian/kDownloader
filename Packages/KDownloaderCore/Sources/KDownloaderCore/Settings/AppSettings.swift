import Foundation

/// User choices that persist between launches.
public struct AppSettings: @unchecked Sendable {
    // UserDefaults is thread-safe; it is not marked Sendable on macOS 14.
    let defaults: UserDefaults
    private let downloadsDirectory: URL

    static let destinationKey = "destinationFolderPath"

    public init(
        defaults: UserDefaults = .standard,
        downloadsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Downloads")
    ) {
        self.defaults = defaults
        self.downloadsDirectory = downloadsDirectory
    }

    /// The folder to save into and whether the saved folder was missing, in
    /// which case Downloads is used instead.
    public func destinationFolder() -> (url: URL, savedFolderMissing: Bool) {
        guard let path = defaults.string(forKey: Self.destinationKey) else {
            return (downloadsDirectory, false)
        }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
            return (URL(filePath: path, directoryHint: .isDirectory), false)
        }
        return (downloadsDirectory, true)
    }

    public func setDestinationFolder(_ url: URL) {
        defaults.set(url.path, forKey: Self.destinationKey)
    }

    static let showAllFormatsKey = "showAllFormats"

    /// List every format in the Video and Audio menus, not only compatible ones. Off by default.
    public var showAllFormats: Bool {
        defaults.bool(forKey: Self.showAllFormatsKey)
    }

    public func setShowAllFormats(_ value: Bool) {
        defaults.set(value, forKey: Self.showAllFormatsKey)
    }
}
