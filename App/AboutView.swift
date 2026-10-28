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

            VStack(alignment: .leading, spacing: 6) {
                Text("Bundled dependencies")
                    .font(.callout.weight(.semibold))
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                    GridRow {
                        Text(Tool.ytDlp.displayName)
                        HStack(spacing: 6) {
                            Text(version(of: .ytDlp))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            if model.activeYtDlp?.source == .updated {
                                Text("updated")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    GridRow {
                        Text(verbatim: "FFmpeg")
                        Text(version(of: .ffmpeg))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    GridRow {
                        Text(Tool.deno.displayName)
                        Text(version(of: .deno))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .font(.callout)
            .padding(.top, 4)

            Button("Show Licenses in Finder") {
                if let folder = Bundle.main.resourceURL?.appendingPathComponent("Licenses", isDirectory: true) {
                    NSWorkspace.shared.open(folder)
                }
            }
            .buttonStyle(.link)
            .font(.callout)
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
