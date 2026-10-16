import Foundation

/// A yt-dlp release version: `YYYY.MM.DD` with an optional `.N` for extra
/// releases on the same day.
public struct YtDlpVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    public let components: [Int]

    public init?(_ string: String) {
        let parts = string.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".", omittingEmptySubsequences: false)
        guard (3...4).contains(parts.count) else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy(\.isNumber), let number = Int(part) else { return nil }
            numbers.append(number)
        }
        components = numbers
    }

    public var description: String {
        // Keeps the zero padding of month and day, as in the release tags.
        let date = components.prefix(3).enumerated().map { index, value in
            index == 0 ? String(value) : String(format: "%02d", value)
        }
        return (date + components.dropFirst(3).map(String.init)).joined(separator: ".")
    }

    public static func < (lhs: YtDlpVersion, rhs: YtDlpVersion) -> Bool {
        // A missing fourth component counts as 0: 2026.08.19 < 2026.08.19.1.
        let left = lhs.components + Array(repeating: 0, count: 4 - lhs.components.count)
        let right = rhs.components + Array(repeating: 0, count: 4 - rhs.components.count)
        return left.lexicographicallyPrecedes(right)
    }

    public static func == (lhs: YtDlpVersion, rhs: YtDlpVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    public func hash(into hasher: inout Hasher) {
        var normalized = components
        while normalized.count > 3, normalized.last == 0 { normalized.removeLast() }
        hasher.combine(normalized)
    }
}
