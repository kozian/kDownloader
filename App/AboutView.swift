import KDownloaderCore
import SwiftUI

struct AboutView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            Text("kDownloader")
                .font(.title2.bold())
            Text("Version \(AppModel.appVersion)")
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                ForEach([Tool.ytDlp, .ffmpeg, .deno], id: \.self) { tool in
                    GridRow {
                        Text(tool.displayName)
                        Text(version(of: tool))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .font(.callout)
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 300)
    }

    private func version(of tool: Tool) -> String {
        switch model.toolState {
        case .checking: "…"
        case .ready(let versions): versions[tool] ?? "?"
        case .broken: "?"
        }
    }
}

extension Tool {
    var displayName: String {
        switch self {
        case .ytDlp: "yt-dlp"
        case .ffmpeg: "ffmpeg"
        case .ffprobe: "ffprobe"
        case .deno: "Deno"
        }
    }
}
