import AppKit
import Foundation
import KDownloaderCore
import Observation

/// The flow of the main window: enter a link, analyze it, pick a format, download.
@MainActor
@Observable
final class SessionModel {
    enum State: Equatable {
        case idle
        case analyzing
        case ready(VideoInfo)
        case failed(AppError)
        case downloading(VideoInfo, DownloadProgress)
        case finished(VideoInfo, URL)
        case downloadFailed(VideoInfo, AppError)
    }

    private(set) var state: State = .idle {
        didSet { app.operationInProgress = isBusy }
    }
    /// Shown below the URL field when the text is not a link.
    private(set) var validationError: ErrorCategory?

    var urlText = "" {
        didSet {
            guard urlText != oldValue else { return }
            validationError = nil
            switch state {
            case .ready, .failed, .finished, .downloadFailed:
                state = .idle
                catalog = nil
            case .idle, .analyzing, .downloading: break
            }
            if LinkInput.isPastedLink(old: oldValue, new: urlText) {
                analyze()
            }
        }
    }

    // MARK: Format selection

    /// Menu entries of the analyzed video.
    private(set) var catalog: FormatCatalog?
    var videoChoice: VideoChoice = .bestCompatible
    var audioChoice: AudioChoice = .none
    /// The "Show all formats" setting: both menus list every format, not only compatible ones.
    var showAllFormats: Bool { app.showAllFormats }

    /// Adapts the current choices after the setting changed.
    func applyShowAllFormats(_ showAll: Bool) {
        guard let catalog else { return }
        if showAll {
            // Keep what was chosen, now as a concrete format.
            if let format = catalog.videoFormat(for: videoChoice) {
                videoChoice = .format(format.id)
            }
        } else {
            videoChoice = catalog.defaultVideoChoice
            if case .track(let id) = audioChoice, catalog.compatibleAudioTracks.contains(where: { $0.id == id }) {
                return
            }
            audioChoice = catalog.defaultAudioChoice(showAll: false)
        }
    }

    /// What will be downloaded with the current choice.
    var currentPlan: DownloadPlan? {
        catalog?.plan(video: videoChoice, audio: audioChoice)
    }

    // MARK: Destination

    private(set) var destination: URL
    /// The previously chosen folder no longer exists, so Downloads is used.
    private(set) var savedDestinationMissing: Bool

    // MARK: Cookies

    /// Browser whose cookies the analyzed video needed; the download uses it from the start.
    private(set) var cookieBrowser: CookieBrowser?
    /// Set while the browser choice dialog is shown.
    private(set) var isAskingForBrowser = false
    private var browserRequest: CheckedContinuation<CookieBrowserChoice, Never>?

    let app: AppModel
    private var analysisTask: Task<Void, Never>?
    private var downloadTask: Task<Void, Never>?

    init(app: AppModel) {
        self.app = app
        let folder = app.settings.destinationFolder()
        destination = folder.url
        savedDestinationMissing = folder.savedFolderMissing
        #if DEBUG
        installDebugHooks()
        #endif
    }

    // MARK: Analysis

    var canAnalyze: Bool {
        app.toolsReady && LinkInput.hasText(urlText) && !isBusy
    }

    /// Analysis or download in progress: the URL field and Analyze are disabled.
    var isBusy: Bool {
        switch state {
        case .analyzing, .downloading: true
        default: false
        }
    }

    func analyze() {
        guard canAnalyze else { return }
        guard let url = LinkInput.url(from: urlText) else {
            validationError = .invalidLink
            return
        }
        validationError = nil
        state = .analyzing
        cookieBrowser = nil
        let client = app.ytDlp
        let log = app.log
        let retry = cookieRetry
        analysisTask = Task {
            await log?.write("analyzing \(url.absoluteString)")
            do {
                let (video, browser) = try await retry.run { browser in
                    try await client.analyze(url, cookiesFromBrowser: browser?.id)
                }
                // A result that arrives after Cancel must not replace the idle state.
                guard !Task.isCancelled else { return }
                cookieBrowser = browser
                selectFormats(of: video)
                state = .ready(video)
            } catch is CancellationError {
                await log?.write("analysis cancelled")
            } catch let error as AppError {
                guard !Task.isCancelled else { return }
                await log?.write("analysis failed: \(error.category.rawValue)")
                state = .failed(error)
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed(AppError(.unknown, details: String(describing: error)))
            }
        }
    }

    func cancelAnalysis() {
        answerBrowserRequest(.declined, remember: false)
        analysisTask?.cancel()
        analysisTask = nil
        state = .idle
    }

    func retry() {
        switch state {
        case .downloadFailed:
            download()
        default:
            state = .idle
            analyze()
        }
    }

    private func selectFormats(of video: VideoInfo) {
        let catalog = FormatCatalog(formats: video.formats)
        self.catalog = catalog
        videoChoice = catalog.defaultVideoChoice
        audioChoice = catalog.defaultAudioChoice(showAll: false)
        if showAllFormats {
            applyShowAllFormats(true)
        }
    }

    // MARK: Destination

    func setDestination(_ url: URL) {
        destination = url
        savedDestinationMissing = false
        app.settings.setDestinationFolder(url)
    }

    // MARK: Download

    var video: VideoInfo? {
        switch state {
        case .ready(let video), .downloading(let video, _), .finished(let video, _), .downloadFailed(let video, _): video
        case .idle, .analyzing, .failed: nil
        }
    }

    /// Format controls and Download work only for an analyzed video that is
    /// not being downloaded.
    var formatControlsEnabled: Bool {
        switch state {
        case .ready, .finished, .downloadFailed: catalog != nil
        default: false
        }
    }

    var canDownload: Bool {
        formatControlsEnabled && currentPlan != nil
    }

    func download() {
        guard let video, let plan = currentPlan, let url = LinkInput.url(from: urlText) else { return }
        guard formatControlsEnabled else { return }

        let name = OutputNamer.sanitizedName(video.title, fallback: video.id)
        let baseName = OutputNamer.uniqueBaseName(name, fileExtension: plan.container.rawValue, in: destination)
        let directory = destination
        let client = app.ytDlp
        let log = app.log
        let retry = cookieRetry
        let initialBrowser = cookieBrowser
        state = .downloading(video, .preparing)

        downloadTask = Task {
            await log?.write("downloading \(url.absoluteString) as \(plan.formatSelector) into \(directory.path)/\(baseName).\(plan.container.rawValue)")
            do {
                let (file, _) = try await retry.run(initialBrowser: initialBrowser) { browser in
                    var file: URL?
                    for try await event in client.download(url, plan: plan, to: directory, baseName: baseName, cookiesFromBrowser: browser?.id) {
                        switch event {
                        case .progress(let progress):
                            await self.updateProgress(progress, of: video)
                        case .finished(let result):
                            file = result
                        }
                    }
                    try Task.checkCancellation()
                    guard let file else { throw AppError(.unknown, details: "yt-dlp did not report the downloaded file") }
                    return file
                }
                guard !Task.isCancelled else { return }
                await log?.write("download finished: \(file.path)")
                state = .finished(video, file)
                app.notifyDownloadFinished(title: video.title, file: file)
            } catch is CancellationError {
                return
            } catch let error as AppError {
                guard !Task.isCancelled else { return }
                await log?.write("download failed: \(error.category.rawValue)")
                state = .downloadFailed(video, error)
            } catch {
                guard !Task.isCancelled else { return }
                state = .downloadFailed(video, AppError(.unknown, details: String(describing: error)))
            }
        }
    }

    /// Stops the download and returns to format selection for the same video.
    /// Partial files stay in the destination folder.
    func cancelDownload() {
        guard case .downloading(let video, _) = state else { return }
        answerBrowserRequest(.declined, remember: false)
        downloadTask?.cancel()
        downloadTask = nil
        state = .ready(video)
        Task { [log = app.log] in await log?.write("download cancelled") }
    }

    func showInFinder() {
        guard case .finished(_, let file) = state else { return }
        NSWorkspace.shared.activateFileViewerSelecting([file])
    }

    private func updateProgress(_ progress: DownloadProgress, of video: VideoInfo) {
        guard case .downloading = state else { return }
        state = .downloading(video, progress)
    }

    // MARK: Cookies

    private var cookieRetry: CookieRetry {
        let settings = app.settings
        return CookieRetry(
            currentChoice: { settings.cookieBrowser },
            askForBrowser: { await self.askForBrowser() },
            log: app.log
        )
    }

    private func askForBrowser() async -> CookieBrowserChoice {
        await withCheckedContinuation { continuation in
            browserRequest = continuation
            isAskingForBrowser = true
        }
    }

    /// Answers the browser dialog. The choice is saved in settings unless the
    /// operation was cancelled.
    func answerBrowserRequest(_ choice: CookieBrowserChoice, remember: Bool = true) {
        guard let request = browserRequest else { return }
        browserRequest = nil
        isAskingForBrowser = false
        if remember {
            app.settings.setCookieBrowser(choice)
        }
        request.resume(returning: choice)
    }

    func startNewDownload() {
        urlText = ""
        state = .idle
        catalog = nil
    }
}
