import Foundation
@testable import KDownloaderCore

/// Serves fixed responses by URL and records the requests.
final class FakeHTTPClient: HTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [URL: Result<Data, UpdateError>] = [:]
    private var files: [URL: URL] = [:]
    private(set) var requested: [URL] = []

    func respond(to url: URL, with data: Data) {
        lock.withLock { responses[url] = .success(data) }
    }

    func fail(_ url: URL, with error: UpdateError) {
        lock.withLock { responses[url] = .failure(error) }
    }

    func serveFile(_ file: URL, at url: URL) {
        lock.withLock { files[url] = file }
    }

    func data(from url: URL) async throws -> Data {
        let response = lock.withLock { () -> Result<Data, UpdateError>? in
            requested.append(url)
            return responses[url]
        }
        guard let response else { throw UpdateError.network("HTTP 404 for \(url)") }
        return try response.get()
    }

    func download(from url: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        let file = lock.withLock { () -> URL? in
            requested.append(url)
            return files[url]
        }
        guard let file else { throw UpdateError.network("HTTP 404 for \(url)") }
        progress(0.5)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: file, to: destination)
        progress(1)
    }
}
