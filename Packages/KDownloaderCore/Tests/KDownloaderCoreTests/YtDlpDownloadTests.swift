import Foundation
import Testing
@testable import KDownloaderCore

struct YtDlpDownloadTests {
    let url = URL(string: "https://www.youtube.com/watch?v=jNQXAC9IVRw")!
    let plan = DownloadPlan(formatSelector: "134+140", container: .mp4)

    private func destination() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "Downloads-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func reportsProgressAndFinishedFile() async throws {
        let directory = try destination()
        let result = directory.appending(path: "Me at the zoo.mp4")
        let fake = try FakeYtDlp(body: """
            echo 'KDPROGRESS downloading 100 1000 NA 50 9 avc1.4D400C'
            echo 'KDPROGRESS finished 1000 1000 NA 50 NA avc1.4D400C'
            echo 'KDPROGRESS finished 300 300 NA 50 NA none'
            echo '[Merger] Merging formats into "\(result.path)"'
            touch '\(result.path)'
            echo 'KDFILE \(result.path)'

            """)

        var events: [DownloadEvent] = []
        for try await event in fake.client.download(url, plan: plan, to: directory, baseName: "Me at the zoo") {
            events.append(event)
        }

        #expect(events.first == .progress(.preparing))
        #expect(events.contains(.progress(DownloadProgress(stage: .downloadingVideo, downloadedBytes: 100, totalBytes: 1000, speed: 50, remainingTime: 9))))
        #expect(events.contains(.progress(DownloadProgress(stage: .processing))))
        #expect(events.last == .finished(result))

        let arguments = try fake.recordedArguments()
        #expect(arguments.contains("134+140"))
        #expect(arguments.contains("--merge-output-format"))
        let output = try #require(arguments.firstIndex(of: "-o").map { arguments[$0 + 1] })
        #expect(output == directory.appending(path: "Me at the zoo").path + ".%(ext)s")
        #expect(arguments.suffix(2) == ["--", url.absoluteString])
    }

    @Test func escapesPercentInName() async throws {
        let directory = try destination()
        let fake = try FakeYtDlp(body: "echo 'KDFILE /tmp/x.mp4'\n")
        for try await _ in fake.client.download(url, plan: plan, to: directory, baseName: "100% real") {}
        let arguments = try fake.recordedArguments()
        let output = try #require(arguments.firstIndex(of: "-o").map { arguments[$0 + 1] })
        #expect(output.hasSuffix("100%% real.%(ext)s"))
    }

    @Test func failureIsClassifiedAndPartialFilesStay() async throws {
        let directory = try destination()
        let partial = directory.appending(path: "Me at the zoo.f134.mp4.part")
        let fake = try FakeYtDlp(body: "touch '\(partial.path)'\necho 'ERROR: unable to write data: [Errno 28] No space left on device' >&2\nexit 1\n")
        do {
            for try await _ in fake.client.download(url, plan: plan, to: directory, baseName: "Me at the zoo") {}
            Issue.record("expected an error")
        } catch let error as AppError {
            #expect(error.category == .notEnoughDiskSpace)
        }
        #expect(FileManager.default.fileExists(atPath: partial.path))
    }

    @Test func cancellationLeavesPartialFiles() async throws {
        let directory = try destination()
        let partial = directory.appending(path: "Me at the zoo.f134.mp4.part")
        let interrupted = directory.appending(path: "interrupted")
        let fake = try FakeYtDlp(body: """
            trap 'touch "\(interrupted.path)"; exit 1' INT
            touch '\(partial.path)'
            echo 'KDPROGRESS downloading 100 1000 NA 50 9 avc1.4D400C'
            while true; do sleep 0.05; done

            """)
        let task = Task {
            for try await event in fake.client.download(url, plan: plan, to: directory, baseName: "Me at the zoo") {
                if case .progress(let progress) = event, progress.stage == .downloadingVideo {
                    withUnsafeCurrentTask { $0?.cancel() }
                }
            }
        }
        _ = await task.result

        let deadline = ContinuousClock.now + .seconds(3)
        while !FileManager.default.fileExists(atPath: interrupted.path), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(FileManager.default.fileExists(atPath: interrupted.path))
        #expect(FileManager.default.fileExists(atPath: partial.path))
    }

    @Test func successWithoutFileIsAnError() async throws {
        let fake = try FakeYtDlp(body: "exit 0\n")
        await #expect(throws: AppError.self) {
            for try await _ in fake.client.download(url, plan: plan, to: try destination(), baseName: "x") {}
        }
    }
}
