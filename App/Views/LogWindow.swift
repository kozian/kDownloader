import AppKit
import KDownloaderCore
import SwiftUI
import UniformTypeIdentifiers

/// "Window → Log": the current log, updated live, with Show in Finder and Export.
struct LogWindow: View {
    @Environment(AppModel.self) private var app
    @State private var text = ""

    var body: some View {
        VStack(spacing: 0) {
            LogTextView(text: text)
            Divider()
            HStack {
                if let url = app.log?.fileURL {
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                Button("Show in Finder", action: showInFinder)
                Button("Export…", action: export)
            }
            .padding(10)
        }
        .frame(minWidth: 640, minHeight: 360)
        .task {
            guard let log = app.log else {
                text = String(localized: "The log is not available.")
                return
            }
            // Subscribe before reading so no line is lost in between.
            let updates = await log.subscribe()
            text = await log.contents()
            for await line in updates {
                text += line + "\n"
            }
        }
    }

    private func showInFinder() {
        guard let url = app.log?.fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func export() {
        guard let log = app.log else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = log.fileURL.deletingPathExtension().lastPathComponent + ".txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            let contents = await log.contents()
            do {
                try contents.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}

/// Read-only, selectable, monospaced text that keeps scrolled to the end
/// while new lines arrive.
private struct LogTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        textView.textContainerInset = NSSize(width: 6, height: 6)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        guard textView.string != text else { return }
        let isFirstLoad = textView.string.isEmpty
        let wasAtEnd = isFirstLoad || (scrollView.verticalScroller.map { $0.floatValue >= 0.99 } ?? true)
        if text.hasPrefix(textView.string), let storage = textView.textStorage {
            let appended = String(text.dropFirst(textView.string.count))
            storage.append(NSAttributedString(string: appended, attributes: [
                .font: textView.font as Any,
                .foregroundColor: NSColor.textColor,
            ]))
        } else {
            textView.string = text
        }
        if wasAtEnd {
            // After the text has been laid out.
            DispatchQueue.main.async {
                textView.scrollRangeToVisible(NSRange(location: (textView.string as NSString).length, length: 0))
            }
        }
    }
}
