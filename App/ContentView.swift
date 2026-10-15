import KDownloaderCore
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.openWindow) private var openWindow
    @State private var session: SessionModel?

    var body: some View {
        Group {
            if let session {
                MainView(session: session)
            }
        }
        .frame(width: 560)
        .onAppear {
            if session == nil {
                session = SessionModel(app: app)
            }
        }
        .environment(\.openLog, OpenLogAction { openWindow(id: WindowID.log) })
    }
}

/// One fixed layout: every control is always visible and is enabled by state.
private struct MainView: View {
    @Environment(AppModel.self) private var app
    @Bindable var session: SessionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if case .broken(let tool, let reason) = app.toolState {
                DamagedAppBanner(toolName: tool.displayName, reason: reason)
            }

            URLInputView(session: session)
            VideoPreview(video: session.video)
            StatusArea(session: session, cookieBrowser: cookieBrowser)

            Divider()
            FormatSelectionView(session: session)
            Divider()

            DestinationRow(session: session)
            HStack {
                PlanSummary(plan: session.formatControlsEnabled ? session.currentPlan : nil)
                Spacer()
                Button("Download", action: session.download)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!session.canDownload)
            }
        }
        .padding(20)
        // The window follows the height of the content.
        .fixedSize(horizontal: false, vertical: true)
        .sheet(isPresented: .constant(session.isAskingForBrowser)) {
            BrowserChoiceSheet { session.answerBrowserRequest($0) }
        }
        .onChange(of: app.showAllFormats) { _, showAll in
            session.applyShowAllFormats(showAll)
        }
    }

    /// The browser a cookie error refers to.
    private var cookieBrowser: CookieBrowser? {
        if case .browser(let browser) = app.settings.cookieBrowser { browser } else { nil }
    }
}

/// Analysis progress, errors, download progress and completion.
private struct StatusArea: View {
    @Bindable var session: SessionModel
    let cookieBrowser: CookieBrowser?

    var body: some View {
        switch session.state {
        case .idle, .ready:
            EmptyView()
        case .analyzing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Analyzing…").foregroundStyle(.secondary)
            }
        case .failed(let error), .downloadFailed(_, let error):
            ErrorView(error: error, retry: session.retry, cookieBrowser: cookieBrowser)
        case .downloading(_, let progress):
            DownloadProgressView(progress: progress, cancel: session.cancelDownload)
        case .finished(_, let file):
            DownloadFinishedView(file: file, showInFinder: session.showInFinder, startNew: session.startNewDownload)
        }
    }
}

private struct URLInputView: View {
    @Environment(AppModel.self) private var app
    @Bindable var session: SessionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Video link", text: $session.urlText, prompt: Text(verbatim: "https://"))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { session.analyze() }
                    .disabled(!app.toolsReady || session.isBusy)
                if session.state == .analyzing {
                    Button("Cancel", action: session.cancelAnalysis)
                        .keyboardShortcut(.cancelAction)
                } else {
                    Button("Analyze", action: session.analyze)
                        .disabled(!session.canAnalyze)
                }
            }
            if let error = session.validationError {
                Text(error.title)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }
}

struct DamagedAppBanner: View {
    let toolName: String
    let reason: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.title)
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 4) {
                Text("The app is damaged — please reinstall it")
                    .font(.headline)
                Text("Bundled tool “\(toolName)” is not working: \(reason)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// "Will be saved as .mp4 · ~255 MB" next to the Download button.
private struct PlanSummary: View {
    let plan: DownloadPlan?

    var body: some View {
        if let plan {
            HStack(spacing: 4) {
                Image(systemName: "doc")
                Text("Will be saved as .\(plan.fileExtension)")
                if let size = plan.estimatedSize {
                    Text(verbatim: "· ~\(size.formatted(.byteCount(style: .file)))")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}
