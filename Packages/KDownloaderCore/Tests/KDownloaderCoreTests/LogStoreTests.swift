import Foundation
import Testing
@testable import KDownloaderCore

struct LogStoreTests {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "LogStoreTests-\(UUID().uuidString)")
    }

    private func logFiles() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".log") }.sorted()
    }

    @Test func createsDirectoryAndFile() throws {
        let store = try LogStore(directory: directory)
        #expect(FileManager.default.fileExists(atPath: store.fileURL.path))
        #expect(store.fileURL.lastPathComponent.hasPrefix("kDownloader-"))
    }

    @Test func keepsAtMostTenFiles() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for day in 1...10 {
            let name = String(format: "kDownloader-2020-01-%02d_00-00-00.log", day)
            FileManager.default.createFile(atPath: directory.appending(path: name).path, contents: nil)
        }
        FileManager.default.createFile(atPath: directory.appending(path: "unrelated.txt").path, contents: nil)

        let store = try LogStore(directory: directory)

        let files = try logFiles()
        #expect(files.count == 10)
        #expect(!files.contains("kDownloader-2020-01-01_00-00-00.log"))
        #expect(files.contains("kDownloader-2020-01-02_00-00-00.log"))
        #expect(files.contains(store.fileURL.lastPathComponent))
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "unrelated.txt").path))
    }

    @Test func writesTimestampedLines() async throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let store = try LogStore(directory: directory, clock: { date })

        await store.write("first\nsecond", category: "yt-dlp")

        let lines = await store.contents().split(separator: "\n").map(String.init)
        #expect(lines.count == 2)
        let pattern = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3} \[yt-dlp\] (first|second)$/
        for line in lines {
            #expect(line.wholeMatch(of: pattern) != nil, "\(line)")
        }
    }

    @Test func publishesNewLines() async throws {
        let store = try LogStore(directory: directory)
        let stream = await store.subscribe()

        await store.write("hello")

        var iterator = stream.makeAsyncIterator()
        let line = await iterator.next()
        #expect(line?.hasSuffix("[app] hello") == true)
    }
}
