import Foundation
import Testing
@testable import KDownloaderCore

/// Builds fake yt-dlp archives shaped like the real onedir zip.
struct FakeArchive {
    static func make(reporting version: String, in directory: URL, flattenedFramework: Bool = true) throws -> URL {
        let fileManager = FileManager.default
        let content = directory.appending(path: "content-\(UUID().uuidString)")
        try fileManager.createDirectory(at: content.appending(path: "_internal/Python.framework/Versions/3.14/Resources"), withIntermediateDirectories: true)
        let script = content.appending(path: "yt-dlp_macos")
        try "#!/bin/sh\necho \(version)\n".write(to: script, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let binary = Data("not really a binary".utf8)
        let framework = content.appending(path: "_internal/Python.framework")
        try binary.write(to: framework.appending(path: "Versions/3.14/Python"))
        if flattenedFramework {
            // What a zip without symlinks produces.
            try fileManager.createDirectory(at: framework.appending(path: "Versions/Current/Resources"), withIntermediateDirectories: true)
            try binary.write(to: framework.appending(path: "Versions/Current/Python"))
            try binary.write(to: framework.appending(path: "Python"))
            try fileManager.createDirectory(at: framework.appending(path: "Resources"), withIntermediateDirectories: true)
            try binary.write(to: content.appending(path: "_internal/Python"))
        }
        let zip = directory.appending(path: "yt-dlp_macos-\(UUID().uuidString).zip")
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", content.path, zip.path]
        try process.run()
        process.waitUntilExit()
        return zip
    }
}

struct YtDlpInstallerTests {
    let directory: URL
    let root: URL
    let archiveURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/download/2026.10.01/yt-dlp_macos.zip")!

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "YtDlpInstallerTests-\(UUID().uuidString)")
        root = directory.appending(path: "install")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func installer(serving archive: URL) -> YtDlpInstaller {
        let http = FakeHTTPClient()
        http.serveFile(archive, at: archiveURL)
        return YtDlpInstaller(root: root, http: http, runner: ToolRunner(log: nil), log: nil)
    }

    private func release(_ version: String, archive: URL) throws -> YtDlpRelease {
        YtDlpRelease(version: try #require(YtDlpVersion(version)), archiveURL: archiveURL, sha256: try YtDlpInstaller.sha256(of: archive))
    }

    private func incomingFolders() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []).filter { $0.hasPrefix(".incoming") }
    }

    @Test func installsAndRepairsFramework() async throws {
        let archive = try FakeArchive.make(reporting: "2026.10.01", in: directory)
        let installer = installer(serving: archive)
        let installed = try await installer.install(try release("2026.10.01", archive: archive))

        #expect(installed.directory.lastPathComponent == "2026.10.01")
        #expect(FileManager.default.isExecutableFile(atPath: installed.executable.path))
        let current = installed.directory.appending(path: "_internal/Python.framework/Versions/Current")
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: current.path) == "3.14")
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: installed.directory.appending(path: "_internal/Python").path)
                == "Python.framework/Versions/Current/Python")
        let listed = installer.installed()
        #expect(listed.map(\.version) == [installed.version])
        #expect(listed.first?.directory.resolvingSymlinksInPath().path == installed.directory.resolvingSymlinksInPath().path)
        #expect(incomingFolders().isEmpty)
    }

    @Test func checksumMismatchKeepsNothing() async throws {
        let archive = try FakeArchive.make(reporting: "2026.10.01", in: directory)
        var bad = try release("2026.10.01", archive: archive)
        bad.sha256 = String(repeating: "0", count: 64)
        await #expect(throws: UpdateError.damagedDownload) {
            try await installer(serving: archive).install(bad)
        }
        #expect(installer(serving: archive).installed().isEmpty)
        #expect(incomingFolders().isEmpty)
    }

    @Test func wrongVersionIsRejected() async throws {
        let archive = try FakeArchive.make(reporting: "2026.09.01", in: directory)
        do {
            _ = try await installer(serving: archive).install(try release("2026.10.01", archive: archive))
            Issue.record("expected an error")
        } catch let error as UpdateError {
            guard case .invalidUpdate = error else {
                Issue.record("unexpected \(error)")
                return
            }
        }
        #expect(installer(serving: archive).installed().isEmpty)
        #expect(incomingFolders().isEmpty)
    }

    @Test func keepsOnlyTwoVersions() async throws {
        for version in ["2026.09.01", "2026.10.01", "2026.10.15"] {
            let archive = try FakeArchive.make(reporting: version, in: directory)
            _ = try await installer(serving: archive).install(try release(version, archive: archive))
        }
        let installer = YtDlpInstaller(root: root, http: FakeHTTPClient(), runner: ToolRunner(log: nil), log: nil)
        #expect(installer.installed().map(\.version.description) == ["2026.10.15", "2026.10.01"])
    }

    @Test func removeAllDeletesUpdates() async throws {
        let archive = try FakeArchive.make(reporting: "2026.10.01", in: directory)
        let installer = installer(serving: archive)
        _ = try await installer.install(try release("2026.10.01", archive: archive))
        try installer.removeAll()
        #expect(installer.installed().isEmpty)
    }

    @Test func checksumOfFile() throws {
        let file = directory.appending(path: "abc.txt")
        try Data("abc".utf8).write(to: file)
        #expect(try YtDlpInstaller.sha256(of: file) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
