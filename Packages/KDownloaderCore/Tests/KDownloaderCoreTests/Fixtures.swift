import Foundation
@testable import KDownloaderCore

enum Fixtures {
    static func data(_ path: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: "Fixtures/\(path)", withExtension: nil) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: path])
        }
        return try Data(contentsOf: url)
    }

    static func text(_ path: String) throws -> String {
        String(decoding: try data(path), as: UTF8.self)
    }

    static func analysis(_ name: String) throws -> AnalysisResponse {
        try AnalysisResponse.decode(data("analysis/\(name).json"))
    }

    static func video(_ name: String) throws -> VideoInfo {
        guard case .video(let video) = try analysis(name).kind else {
            throw CocoaError(.coderInvalidValue)
        }
        return video
    }
}
