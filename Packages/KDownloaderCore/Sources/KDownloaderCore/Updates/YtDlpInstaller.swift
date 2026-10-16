import CryptoKit
import Foundation

/// A yt-dlp update installed by the app.
public struct InstalledYtDlp: Equatable, Sendable {
    public var version: YtDlpVersion
    public var directory: URL
    public var executable: URL { directory.appending(path: YtDlpInstaller.executableName) }
}

/// Downloads, verifies and installs yt-dlp releases into the app's own folder.
public struct YtDlpInstaller: Sendable {
    static let executableName = "yt-dlp_macos"
    /// Versions kept on disk: the active one and the previous one.
    static let keptVersions = 2

    /// `~/Library/Application Support/kDownloader/yt-dlp`.
    public let root: URL
    private let http: HTTPClient
    private let runner: ToolRunner
    private let log: LogStore?

    public init(root: URL = YtDlpInstaller.defaultRoot, http: HTTPClient, runner: ToolRunner, log: LogStore?) {
        self.root = root
        self.http = http
        self.runner = runner
        self.log = log
    }

    public static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/kDownloader/yt-dlp")
    }

    /// Installed updates that look complete, newest first. Folders being
    /// installed (`.incoming-…`) and unknown names are ignored.
    public func installed() -> [InstalledYtDlp] {
        let entries = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return entries
            .compactMap { url -> InstalledYtDlp? in
                guard let version = YtDlpVersion(url.lastPathComponent) else { return nil }
                let item = InstalledYtDlp(version: version, directory: url)
                return FileManager.default.isExecutableFile(atPath: item.executable.path) ? item : nil
            }
            .sorted { $0.version > $1.version }
    }

    /// Installs `release`. On any failure nothing changes on disk except
    /// the removed temporary folder.
    public func install(_ release: YtDlpRelease, progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> InstalledYtDlp {
        let fileManager = FileManager.default
        let incoming = root.appending(path: ".incoming-\(UUID().uuidString)")
        do {
            try fileManager.createDirectory(at: incoming, withIntermediateDirectories: true)
        } catch {
            throw UpdateError.installFailed("cannot create \(incoming.path): \(error.localizedDescription)")
        }
        defer { try? fileManager.removeItem(at: incoming) }

        await log?.write("installing yt-dlp \(release.version) from \(release.archiveURL.absoluteString)", category: "update")
        let archive = incoming.appending(path: YtDlpReleaseSource.archiveName)
        do {
            try await http.download(from: release.archiveURL, to: archive) { progress($0 * 0.8) }
        } catch let error as UpdateError {
            throw error
        } catch {
            throw UpdateError.network(error.localizedDescription)
        }
        try Task.checkCancellation()

        let actual = try Self.sha256(of: archive)
        guard actual == release.sha256.lowercased() else {
            await log?.write("checksum mismatch: expected \(release.sha256), got \(actual)", category: "update")
            throw UpdateError.damagedDownload
        }

        let unpacked = incoming.appending(path: "files")
        try await run("/usr/bin/ditto", ["-x", "-k", archive.path, unpacked.path], failure: "cannot extract the archive")
        progress(0.85)

        for framework in try FrameworkRepair.repair(in: unpacked) {
            // yt-dlp runs even with a broken framework signature; the smoke test below decides.
            do {
                try await run("/usr/bin/codesign", ["--force", "--sign", "-", "--timestamp=none", framework.path], failure: "cannot sign \(framework.lastPathComponent)")
            } catch {
                await log?.write("warning: \(error)", category: "update")
            }
        }
        progress(0.9)

        let executable = unpacked.appending(path: Self.executableName)
        let reported = try await version(of: executable)
        guard reported == release.version else {
            throw UpdateError.invalidUpdate("yt-dlp reports \(reported.map(String.init(describing:)) ?? "no version"), expected \(release.version)")
        }

        let destination = root.appending(path: release.version.description)
        do {
            try? fileManager.removeItem(at: destination)
            try fileManager.moveItem(at: unpacked, to: destination)
        } catch {
            throw UpdateError.installFailed("cannot move the update into place: \(error.localizedDescription)")
        }
        removeOldVersions()
        progress(1)
        await log?.write("yt-dlp \(release.version) installed", category: "update")
        return InstalledYtDlp(version: release.version, directory: destination)
    }

    /// Removes every installed update ("Use Bundled Version").
    public func removeAll() throws {
        for item in installed() {
            try FileManager.default.removeItem(at: item.directory)
        }
    }

    /// The version a yt-dlp executable reports, or nil if it does not run.
    public func version(of executable: URL, timeout: Duration = .seconds(30)) async throws -> YtDlpVersion? {
        let invocation = ToolInvocation(executable: executable, arguments: ["--version"])
        let runner = runner
        let run = Task { () -> YtDlpVersion? in
            var first: String?
            var status: Int32 = -1
            for try await event in runner.run(invocation) {
                switch event {
                case .standardOutput(let line): if first == nil { first = line }
                case .standardError: break
                case .exited(let code): status = code
                }
            }
            guard status == 0, let first else { return nil }
            return YtDlpVersion(first)
        }
        let watchdog = Task {
            try await Task.sleep(for: timeout)
            run.cancel()
        }
        defer { watchdog.cancel() }
        return try? await run.value
    }

    private func removeOldVersions() {
        for item in installed().dropFirst(Self.keptVersions) {
            try? FileManager.default.removeItem(at: item.directory)
        }
    }

    private func run(_ tool: String, _ arguments: [String], failure: String) async throws {
        var errors: [String] = []
        var status: Int32 = -1
        do {
            for try await event in runner.run(ToolInvocation(executable: URL(filePath: tool), arguments: arguments)) {
                switch event {
                case .standardError(let line): errors.append(line)
                case .exited(let code): status = code
                case .standardOutput: break
                }
            }
        } catch {
            throw UpdateError.installFailed("\(failure): \(error)")
        }
        guard status == 0 else {
            throw UpdateError.installFailed("\(failure): \(errors.last ?? "exit code \(status)")")
        }
    }

    static func sha256(of file: URL) throws -> String {
        guard let handle = try? FileHandle(forReadingFrom: file) else {
            throw UpdateError.installFailed("cannot read \(file.lastPathComponent)")
        }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// Zip archives do not keep symlinks, so frameworks inside them arrive with
/// copies instead of the standard symlinks and an invalid signature. Same
/// algorithm as `scripts/fetch-tools.sh`.
enum FrameworkRepair {
    /// Restores the symlinks of every flattened framework below `directory`
    /// and returns the version folders that need re-signing.
    static func repair(in directory: URL) throws -> [URL] {
        let fileManager = FileManager.default
        var repaired: [URL] = []
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
            return []
        }
        var frameworks: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "framework" {
            frameworks.append(url)
            enumerator.skipDescendants()
        }
        for framework in frameworks {
            let name = framework.deletingPathExtension().lastPathComponent
            let versions = framework.appending(path: "Versions")
            let current = versions.appending(path: "Current")
            guard isRealDirectory(current) else { continue }
            let candidates = (try fileManager.contentsOfDirectory(atPath: versions.path)).filter { $0 != "Current" }
            guard candidates.count == 1, let version = candidates.first else {
                throw UpdateError.installFailed("cannot repair \(framework.lastPathComponent): expected exactly one version")
            }
            try fileManager.removeItem(at: current)
            try fileManager.createSymbolicLink(atPath: current.path, withDestinationPath: version)
            for entry in [name, "Resources"] {
                let url = framework.appending(path: entry)
                if fileManager.fileExists(atPath: url.path), !isSymlink(url) {
                    try fileManager.removeItem(at: url)
                    try fileManager.createSymbolicLink(atPath: url.path, withDestinationPath: "Versions/Current/\(entry)")
                }
            }
            // A copy of the framework binary next to the framework was a symlink too.
            let sibling = framework.deletingLastPathComponent().appending(path: name)
            let binary = versions.appending(path: "\(version)/\(name)")
            if fileManager.fileExists(atPath: sibling.path), !isSymlink(sibling),
               fileManager.contentsEqual(atPath: sibling.path, andPath: binary.path) {
                try fileManager.removeItem(at: sibling)
                try fileManager.createSymbolicLink(atPath: sibling.path, withDestinationPath: "\(name).framework/Versions/Current/\(name)")
            }
            repaired.append(versions.appending(path: version))
        }
        return repaired
    }

    private static func isSymlink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private static func isRealDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return !isSymlink(url) && FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
