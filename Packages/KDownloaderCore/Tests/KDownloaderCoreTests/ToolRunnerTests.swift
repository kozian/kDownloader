import Foundation
import Testing
@testable import KDownloaderCore

struct ToolRunnerTests {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "ToolRunnerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func script(_ body: String) throws -> URL {
        let url = directory.appending(path: "tool-\(UUID().uuidString).sh")
        try ("#!/bin/sh\n" + body).write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private func waitForFile(_ url: URL, timeout: Duration = .seconds(3)) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if FileManager.default.fileExists(atPath: url.path) { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
    }

    @Test func streamsLinesAndExitCode() async throws {
        let tool = try script("printf 'one\\ntwo\\n'\nprintf 'oops\\n' >&2\nprintf 'tail'\nexit 3\n")
        var events: [ToolEvent] = []
        for try await event in ToolRunner(log: nil).run(ToolInvocation(executable: tool, arguments: [])) {
            events.append(event)
        }
        let stdout = events.compactMap { if case .standardOutput(let line) = $0 { line } else { nil } }
        let stderr = events.compactMap { if case .standardError(let line) = $0 { line } else { nil } }
        #expect(stdout == ["one", "two", "tail"])
        #expect(stderr == ["oops"])
        #expect(events.last == .exited(3))
    }

    @Test func usesOnlyTheGivenEnvironment() async throws {
        setenv("KD_INHERITED", "1", 1)
        let tool = try script("echo \"$KD_TEST:${KD_INHERITED:-unset}\"\n")
        let invocation = ToolInvocation(executable: tool, arguments: [], environment: ["KD_TEST": "yes"])
        var output: [String] = []
        for try await case .standardOutput(let line) in ToolRunner(log: nil).run(invocation) {
            output.append(line)
        }
        #expect(output == ["yes:unset"])
    }

    @Test func writesToLog() async throws {
        let log = try LogStore(directory: directory.appending(path: "logs"))
        let tool = try script("echo out\necho err >&2\nexit 0\n")
        for try await _ in ToolRunner(log: log).run(ToolInvocation(executable: tool, arguments: ["--flag", "a b"])) {}
        let contents = await log.contents()
        #expect(contents.contains("--flag 'a b'"))
        #expect(contents.contains("] out"))
        #expect(contents.contains(":stderr] err"))
        #expect(contents.contains("exit code 0"))
    }

    @Test func launchFailureThrows() async throws {
        let missing = directory.appending(path: "missing-tool")
        await #expect(throws: ToolRunnerError.self) {
            for try await _ in ToolRunner(log: nil).run(ToolInvocation(executable: missing, arguments: [])) {}
        }
    }

    @Test func cancellingSendsInterrupt() async throws {
        let marker = directory.appending(path: "interrupted")
        let tool = try script("trap 'touch \"\(marker.path)\"; exit 130' INT\necho ready\nwhile true; do sleep 0.05; done\n")
        let task = Task {
            for try await event in ToolRunner(log: nil).run(ToolInvocation(executable: tool, arguments: [])) {
                if event == .standardOutput("ready") {
                    withUnsafeCurrentTask { $0?.cancel() }
                }
            }
        }
        _ = await task.result
        #expect(await waitForFile(marker))
    }

    @Test func terminatesWhenInterruptIsIgnored() async throws {
        let marker = directory.appending(path: "terminated")
        let tool = try script("trap '' INT\ntrap 'touch \"\(marker.path)\"; exit 143' TERM\necho ready\nwhile true; do sleep 0.05; done\n")
        let runner = ToolRunner(log: nil, interruptGracePeriod: .milliseconds(200))
        let task = Task {
            for try await event in runner.run(ToolInvocation(executable: tool, arguments: [])) {
                if event == .standardOutput("ready") {
                    withUnsafeCurrentTask { $0?.cancel() }
                }
            }
        }
        _ = await task.result
        #expect(await waitForFile(marker))
    }
}
