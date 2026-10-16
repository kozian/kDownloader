import AppKit
import KDownloaderCore
import SwiftUI

/// "Save to: Downloads [Change…]" with a notice when the saved folder is gone.
/// "Save to: [folder] Change…" as a row of the main window's grid.
struct DestinationRow: View {
    @Bindable var session: SessionModel

    var body: some View {
        GridRow {
            Text("Save to:")
                .gridColumnAlignment(.trailing)
            HStack(spacing: 6) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: session.destination.path))
                    .resizable()
                    .frame(width: 16, height: 16)
                Text(FileManager.default.displayName(atPath: session.destination.path))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(session.destination.path)
                Button("Change…", action: chooseFolder)
                    .controlSize(.small)
                    .disabled(isDownloading)
            }
            // The control column takes the rest of the width; the label column stays as wide as its labels.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        if session.savedDestinationMissing {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                Label("The previously selected folder is not available, so Downloads is used.", systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isDownloading: Bool {
        if case .downloading = session.state { true } else { false }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = session.destination
        panel.prompt = String(localized: "Choose")
        if panel.runModal() == .OK, let url = panel.url {
            session.setDestination(url)
        }
    }
}

/// Stage, progress bar, speed, remaining time and size of a running download.
struct DownloadProgressView: View {
    let progress: DownloadProgress
    let cancel: () -> Void

    var body: some View {
        StatusCard(kind: .info, systemImage: "arrow.down.circle.fill") {
            Text(stageTitle)
                .font(.headline)
            HStack {
                if progress.stage == .processing || progress.stage == .preparing || progress.fraction == nil {
                    ProgressView()
                        .progressViewStyle(.linear)
                } else {
                    ProgressView(value: progress.fraction ?? 0)
                        .progressViewStyle(.linear)
                }
                Button("Cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
            }
            if progress.stage == .downloadingVideo || progress.stage == .downloadingAudio {
                Text(details)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var stageTitle: LocalizedStringKey {
        switch progress.stage {
        case .preparing: "Preparing…"
        case .downloadingVideo: "Downloading video"
        case .downloadingAudio: "Downloading audio"
        case .processing: "Processing"
        }
    }

    private var details: String {
        var parts: [String] = []
        if let fraction = progress.fraction {
            parts.append(fraction.formatted(.percent.precision(.fractionLength(0))))
        }
        if let speed = progress.speed {
            parts.append(String(localized: "\(Int64(speed).formatted(.byteCount(style: .file)))/s"))
        }
        if let remaining = progress.remainingTime {
            let time = Duration.seconds(remaining).formatted(.time(pattern: remaining >= 3600 ? .hourMinuteSecond : .minuteSecond))
            parts.append(String(localized: "\(time) remaining"))
        }
        if let downloaded = progress.downloadedBytes {
            let done = downloaded.formatted(.byteCount(style: .file))
            if let total = progress.totalBytes {
                parts.append(String(localized: "\(done) of \(total.formatted(.byteCount(style: .file)))"))
            } else {
                parts.append(done)
            }
        }
        return parts.joined(separator: " · ")
    }
}

/// Success message with "Show in Finder" and "New Download".
struct DownloadFinishedView: View {
    let file: URL
    let showInFinder: () -> Void
    let startNew: () -> Void

    var body: some View {
        StatusCard(kind: .success, systemImage: "checkmark.circle.fill") {
            Text("Download complete")
                .font(.headline)
            Text(file.lastPathComponent)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            HStack {
                Button("Show in Finder", action: showInFinder)
                Button("New Download", action: startNew)
            }
        }
    }
}
