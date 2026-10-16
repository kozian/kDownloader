import Foundation

/// The network operations the updater needs; faked in tests.
public protocol HTTPClient: Sendable {
    func data(from url: URL) async throws -> Data
    /// Downloads `url` to `destination`, reporting progress from 0 to 1.
    func download(from url: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void) async throws
}

public enum UpdateError: Error, Equatable, Sendable {
    /// The request failed or returned a non-success status.
    case network(String)
    /// The response could not be understood.
    case unexpectedResponse(String)
    /// The archive does not match the published checksum.
    case damagedDownload
    /// The downloaded yt-dlp does not run or reports another version.
    case invalidUpdate(String)
    /// Extracting, repairing or moving the files failed.
    case installFailed(String)
    /// An analysis or a download is running.
    case busy
}

/// `URLSession` with a User-Agent, which the GitHub API requires.
public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    private func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("kDownloader", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        return request
    }

    public func data(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(for: request(url))
        try Self.check(response, url: url)
        return data
    }

    public func download(from url: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        let delegate = ProgressDelegate(progress: progress)
        let (location, response) = try await session.download(for: request(url), delegate: delegate)
        try Self.check(response, url: url)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: location, to: destination)
        progress(1)
    }

    private static func check(_ response: URLResponse, url: URL) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw UpdateError.network("HTTP \(http.statusCode) for \(url.absoluteString)")
        }
    }
}

private final class ProgressDelegate: NSObject, URLSessionDownloadDelegate, Sendable {
    let progress: @Sendable (Double) -> Void

    init(progress: @escaping @Sendable (Double) -> Void) {
        self.progress = progress
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        progress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}
