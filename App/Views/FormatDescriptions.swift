import KDownloaderCore
import SwiftUI

extension MediaFormat {
    /// e.g. "1080p60 · H.264 · mp4 · 245.7 MB"
    var summary: String {
        var parts: [String] = []
        if hasVideo {
            if let height {
                let fpsSuffix = fps.map { $0 > 30 ? String(Int($0.rounded())) : "" } ?? ""
                parts.append("\(height)p\(fpsSuffix)")
            }
            parts.append(Self.codecName(videoCodec))
            if hasAudio {
                parts.append(Self.codecName(audioCodec))
            }
        } else {
            parts.append(Self.codecName(audioCodec))
            if let bitrate {
                parts.append("\(Int(bitrate.rounded())) kbps")
            }
        }
        parts.append(fileExtension)
        if let fileSize {
            parts.append(fileSize.formatted(.byteCount(style: .file)))
        }
        return parts.joined(separator: " · ")
    }

    static func codecName(_ codec: String?) -> String {
        guard let codec = codec?.lowercased() else { return String(localized: "unknown codec") }
        let names: [(String, String)] = [
            ("avc", "H.264"), ("hvc1", "HEVC"), ("hev1", "HEVC"), ("vp09", "VP9"), ("vp9", "VP9"),
            ("vp8", "VP8"), ("av01", "AV1"), ("mp4a", "AAC"), ("opus", "Opus"), ("vorbis", "Vorbis"),
            ("mp3", "MP3"), ("flac", "FLAC"), ("ac-3", "AC-3"), ("ec-3", "E-AC-3"),
        ]
        return names.first { codec.hasPrefix($0.0) }?.1 ?? codec
    }
}

extension FormatBadge {
    var text: LocalizedStringKey {
        switch self {
        case .mayNotOpenInQuickTime: "May not open in QuickTime"
        case .hardwareDecodingM3: "Hardware decoding only on M3 and later"
        }
    }
}

extension DownloadPlan {
    var fileExtension: String { container.rawValue }
}
