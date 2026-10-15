import KDownloaderCore
import SwiftUI

/// Thumbnail, title, author and duration of an analyzed video, or a
/// placeholder before analysis.
struct VideoPreview: View {
    let video: VideoInfo?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AsyncImage(url: video?.thumbnail) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Rectangle().fill(.quaternary)
                        Image(systemName: "film")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            // A new identity drops the previous image when the video changes.
            .id(video?.id)
            .frame(width: 160, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                if let video {
                    Text(video.title)
                        .font(.headline)
                        .lineLimit(2)
                        .textSelection(.enabled)
                    if let author = video.author {
                        Text(author)
                            .foregroundStyle(.secondary)
                    }
                    if let duration = video.duration {
                        Text(Self.format(duration: duration))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No video yet")
                        .font(.headline)
                        .foregroundStyle(.tertiary)
                    Text("Paste a link to a video and press Analyze.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }

    static func format(duration: TimeInterval) -> String {
        let pattern: Duration.TimeFormatStyle.Pattern = duration >= 3600 ? .hourMinuteSecond : .minuteSecond
        return Duration.seconds(duration.rounded()).formatted(.time(pattern: pattern))
    }
}
