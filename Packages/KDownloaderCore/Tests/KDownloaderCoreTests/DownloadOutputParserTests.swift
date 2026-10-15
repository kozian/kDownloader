import Foundation
import Testing
@testable import KDownloaderCore

struct DownloadOutputParserTests {
    @Test func parsesRecordedDownload() throws {
        let lines = try Fixtures.text("download/youtube-134+140.txt").split(separator: "\n").map(String.init)
        let outputs = lines.compactMap(DownloadOutputParser.parse)

        let progress = outputs.compactMap { if case .progress(let p) = $0 { p } else { nil } }
        #expect(progress.count == 20)
        #expect(progress.first == DownloadProgress(
            stage: .downloadingVideo, downloadedBytes: 1024, totalBytes: 322379, speed: 250610.76531683977, remainingTime: 1
        ))
        #expect(progress.last?.stage == .downloadingAudio)
        #expect(progress.last?.fraction == 1)

        let stages = outputs.map { output -> String in
            switch output {
            case .progress(let p): "\(p.stage)"
            case .processing: "processing"
            case .finishedFile: "file"
            }
        }
        #expect(stages.firstIndex(of: "processing")! > stages.lastIndex(of: "downloadingAudio")!)
        #expect(outputs.last == .finishedFile("/Users/someone/Downloads/Me at the zoo.mp4"))
    }

    @Test func usesEstimatedTotalAndToleratesMissingValues() {
        let output = DownloadOutputParser.parse("KDPROGRESS downloading 500 NA 1000 NA NA avc1.64001f")
        #expect(output == .progress(DownloadProgress(stage: .downloadingVideo, downloadedBytes: 500, totalBytes: 1000)))
        if case .progress(let progress) = output {
            #expect(progress.fraction == 0.5)
        }
        let unknown = DownloadOutputParser.parse("KDPROGRESS downloading 500 NA NA NA NA NA")
        if case .progress(let progress) = unknown {
            #expect(progress.fraction == nil)
            #expect(progress.stage == .downloadingVideo)
        }
    }

    @Test func recognizesProcessingAndIgnoresOtherLines() {
        #expect(DownloadOutputParser.parse("[ExtractAudio] Destination: a.m4a") == .processing)
        #expect(DownloadOutputParser.parse("[VideoRemuxer] Remuxing video from mp4 to mkv") == .processing)
        #expect(DownloadOutputParser.parse("[download] Destination: a.f134.mp4") == nil)
        #expect(DownloadOutputParser.parse("KDPROGRESS garbage") == nil)
    }

    @Test func templateMatchesParser() {
        let arguments = DownloadOutputParser.arguments
        let template = try! #require(arguments.firstIndex(of: "--progress-template").map { arguments[$0 + 1] })
        #expect(template.hasPrefix("download:KDPROGRESS "))
        #expect(arguments.contains("--no-simulate"))
    }
}
