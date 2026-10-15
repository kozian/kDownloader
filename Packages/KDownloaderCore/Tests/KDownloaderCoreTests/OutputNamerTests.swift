import Foundation
import Testing
@testable import KDownloaderCore

struct OutputNamerTests {
    @Test(arguments: [
        ("Me at the zoo", "Me at the zoo"),
        ("A/B: test", "A-B- test"),
        ("  padded  ", "padded"),
        ("line\nbreak\ttab", "line-break-tab"),
        ("...hidden", "hidden"),
        ("Привет, мир 🎃", "Привет, мир 🎃"),
    ])
    func sanitizes(title: String, expected: String) {
        #expect(OutputNamer.sanitizedName(title, fallback: "id") == expected)
    }

    @Test func fallsBackToID() {
        #expect(OutputNamer.sanitizedName("  ", fallback: "jNQXAC9IVRw") == "jNQXAC9IVRw")
        #expect(OutputNamer.sanitizedName("", fallback: "") == "video")
    }

    @Test func limitsLengthWithoutSplittingCharacters() {
        let name = OutputNamer.sanitizedName(String(repeating: "ж", count: 150), fallback: "id")
        #expect(name.utf8.count <= 200)
        #expect(name == String(repeating: "ж", count: 100))
    }

    @Test func addsSuffixWhenFileExists() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "OutputNamerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #expect(OutputNamer.uniqueBaseName("Video", fileExtension: "mp4", in: directory) == "Video")

        FileManager.default.createFile(atPath: directory.appending(path: "Video.mp4").path, contents: nil)
        #expect(OutputNamer.uniqueBaseName("Video", fileExtension: "mp4", in: directory) == "Video (2)")
        #expect(OutputNamer.uniqueBaseName("Video", fileExtension: "m4a", in: directory) == "Video")

        FileManager.default.createFile(atPath: directory.appending(path: "Video (2).mp4").path, contents: nil)
        #expect(OutputNamer.uniqueBaseName("Video", fileExtension: "mp4", in: directory) == "Video (3)")
    }
}
