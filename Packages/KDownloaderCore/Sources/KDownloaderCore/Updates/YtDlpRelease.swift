import Foundation

/// A yt-dlp release that can be installed.
public struct YtDlpRelease: Equatable, Sendable {
    public var version: YtDlpVersion
    public var archiveURL: URL
    /// SHA-256 of the archive, from the checksum file of the same release.
    public var sha256: String
}

/// Finds the latest stable yt-dlp release on GitHub.
public struct YtDlpReleaseSource: Sendable {
    static let archiveName = "yt-dlp_macos.zip"
    static let checksumsName = "SHA2-256SUMS"

    private let http: HTTPClient
    private let latestURL: URL

    public init(
        http: HTTPClient,
        latestURL: URL = URL(string: "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest")!
    ) {
        self.http = http
        self.latestURL = latestURL
    }

    public func latest() async throws -> YtDlpRelease {
        let release: GitHubRelease
        do {
            release = try JSONDecoder().decode(GitHubRelease.self, from: try await http.data(from: latestURL))
        } catch let error as UpdateError {
            throw error
        } catch let error as DecodingError {
            throw UpdateError.unexpectedResponse("GitHub release: \(error)")
        } catch {
            throw UpdateError.network(error.localizedDescription)
        }
        guard let version = YtDlpVersion(release.tagName) else {
            throw UpdateError.unexpectedResponse("unknown tag \(release.tagName)")
        }
        guard let archive = release.assets.first(where: { $0.name == Self.archiveName }),
              let checksums = release.assets.first(where: { $0.name == Self.checksumsName }) else {
            throw UpdateError.unexpectedResponse("release \(release.tagName) has no \(Self.archiveName) or \(Self.checksumsName)")
        }
        let sums: Data
        do {
            sums = try await http.data(from: checksums.url)
        } catch let error as UpdateError {
            throw error
        } catch {
            throw UpdateError.network(error.localizedDescription)
        }
        guard let sha256 = Self.checksum(for: Self.archiveName, in: String(decoding: sums, as: UTF8.self)) else {
            throw UpdateError.unexpectedResponse("no checksum for \(Self.archiveName)")
        }
        return YtDlpRelease(version: version, archiveURL: archive.url, sha256: sha256)
    }

    /// The hash for `file` in a `sha256sum`-style list ("<hash>  <file>").
    static func checksum(for file: String, in list: String) -> String? {
        for line in list.split(separator: "\n") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count == 2 else { continue }
            let name = parts[1].hasPrefix("*") ? parts[1].dropFirst() : parts[1]
            let hash = parts[0].lowercased()
            if name == file, hash.count == 64, hash.allSatisfy(\.isHexDigit) {
                return hash
            }
        }
        return nil
    }
}

private struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        var name: String
        var url: URL
        enum CodingKeys: String, CodingKey {
            case name
            case url = "browser_download_url"
        }
    }

    var tagName: String
    var assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }
}
