import Foundation

/// What to do after an operation failed.
public enum CookieDecision: Equatable, Sendable {
    case retry(with: CookieBrowser)
    case askForBrowser
    case fail
}

/// Decides whether a failed operation is retried with browser cookies.
public enum CookieRetryPolicy {
    public static func decide(error: AppError, cookiesUsed: Bool, choice: CookieBrowserChoice) -> CookieDecision {
        // At most one retry, and only for errors cookies can fix.
        guard !cookiesUsed, error.category.mayNeedCookies else { return .fail }
        switch choice {
        case .browser(let browser): return .retry(with: browser)
        case .notChosen: return .askForBrowser
        case .declined: return .fail
        }
    }
}

/// Runs an operation without cookies first and retries it once with cookies
/// when the policy allows.
public struct CookieRetry: Sendable {
    /// Returns the current choice from settings.
    public var currentChoice: @Sendable () async -> CookieBrowserChoice
    /// Asks the user to pick a browser (or decline); the answer is remembered by the caller.
    public var askForBrowser: @Sendable () async -> CookieBrowserChoice
    public var log: LogStore?

    public init(
        currentChoice: @escaping @Sendable () async -> CookieBrowserChoice,
        askForBrowser: @escaping @Sendable () async -> CookieBrowserChoice,
        log: LogStore? = nil
    ) {
        self.currentChoice = currentChoice
        self.askForBrowser = askForBrowser
        self.log = log
    }

    /// - Parameters:
    ///   - initialBrowser: cookies to use from the start, e.g. because the
    ///     analysis of the same video needed them. A failure then is final.
    ///   - operation: receives the browser to read cookies from, or `nil`.
    /// - Returns: the result and the browser it needed, if any.
    public func run<T: Sendable>(
        initialBrowser: CookieBrowser? = nil,
        _ operation: @Sendable (CookieBrowser?) async throws -> T
    ) async throws -> (value: T, browser: CookieBrowser?) {
        do {
            return (try await operation(initialBrowser), initialBrowser)
        } catch let error as AppError {
            var decision = CookieRetryPolicy.decide(error: error, cookiesUsed: initialBrowser != nil, choice: await currentChoice())
            if decision == .askForBrowser {
                decision = CookieRetryPolicy.decide(error: error, cookiesUsed: false, choice: await askForBrowser())
            }
            guard case .retry(let browser) = decision else { throw error }
            try Task.checkCancellation()
            await log?.write("\(error.category.rawValue): retrying with cookies from \(browser.id)")
            return (try await operation(browser), browser)
        }
    }
}
