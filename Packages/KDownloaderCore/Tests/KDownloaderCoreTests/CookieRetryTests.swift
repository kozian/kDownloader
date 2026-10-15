import Foundation
import Testing
@testable import KDownloaderCore

struct CookieRetryPolicyTests {
    let safari = CookieBrowser.named("safari")!

    @Test(arguments: [ErrorCategory.signInRequired, .privateVideo, .membersOnly, .rateLimited])
    func retriesAccessErrorsWithChosenBrowser(category: ErrorCategory) {
        #expect(CookieRetryPolicy.decide(error: AppError(category), cookiesUsed: false, choice: .browser(safari)) == .retry(with: safari))
    }

    @Test(arguments: ErrorCategory.allCases.filter { !$0.mayNeedCookies })
    func doesNotRetryOtherErrors(category: ErrorCategory) {
        #expect(CookieRetryPolicy.decide(error: AppError(category), cookiesUsed: false, choice: .browser(safari)) == .fail)
    }

    @Test func retriesAtMostOnce() {
        #expect(CookieRetryPolicy.decide(error: AppError(.signInRequired), cookiesUsed: true, choice: .browser(safari)) == .fail)
    }

    @Test func asksWhenNoBrowserChosen() {
        #expect(CookieRetryPolicy.decide(error: AppError(.signInRequired), cookiesUsed: false, choice: .notChosen) == .askForBrowser)
    }

    @Test func respectsDecline() {
        #expect(CookieRetryPolicy.decide(error: AppError(.signInRequired), cookiesUsed: false, choice: .declined) == .fail)
    }
}

struct CookieBrowserTests {
    @Test func listsOnlyInstalledBrowsers() {
        let installed: Set<String> = ["com.apple.Safari", "org.mozilla.firefox", "com.example.Unknown"]
        let browsers = CookieBrowser.installed { installed.contains($0) }
        #expect(browsers.map(\.id) == ["safari", "firefox"])
    }

    @Test func choiceIsRemembered() {
        let suite = "CookieBrowserTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        #expect(settings.cookieBrowser == .notChosen)
        settings.setCookieBrowser(.browser(CookieBrowser.named("chrome")!))
        #expect(AppSettings(defaults: defaults).cookieBrowser == .browser(CookieBrowser.named("chrome")!))
        settings.setCookieBrowser(.declined)
        #expect(AppSettings(defaults: defaults).cookieBrowser == .declined)
    }
}

/// Uses a fake yt-dlp that refuses without `--cookies-from-browser`.
struct CookieRetryIntegrationTests {
    let url = URL(string: "https://www.youtube.com/watch?v=jNQXAC9IVRw")!
    let safari = CookieBrowser.named("safari")!

    private func fakeNeedingCookies() throws -> FakeYtDlp {
        let fixture = try FakeYtDlp.fixturePath("analysis/youtube-me-at-the-zoo.json")
        return try FakeYtDlp(body: """
            case "$*" in
              *--cookies-from-browser*) cat '\(fixture)' ;;
              *) echo 'ERROR: [youtube] x: Sign in to confirm your age' >&2; exit 1 ;;
            esac

            """)
    }

    private func retry(choice: CookieBrowserChoice, asked: CookieBrowserChoice = .declined, askCount: Counter? = nil) -> CookieRetry {
        CookieRetry(
            currentChoice: { choice },
            askForBrowser: { await askCount?.increment(); return asked }
        )
    }

    @Test func retriesWithCookiesAndSucceeds() async throws {
        let fake = try fakeNeedingCookies()
        let client = fake.client
        let result = try await retry(choice: .browser(safari)).run { browser in
            try await client.analyze(url, cookiesFromBrowser: browser?.id)
        }
        #expect(result.value.title == "Me at the zoo")
        #expect(result.browser == safari)
        #expect(try fake.recordedArguments().contains("safari"))
    }

    @Test func asksForBrowserWhenNotChosen() async throws {
        let fake = try fakeNeedingCookies()
        let client = fake.client
        let counter = Counter()
        let result = try await retry(choice: .notChosen, asked: .browser(safari), askCount: counter).run { browser in
            try await client.analyze(url, cookiesFromBrowser: browser?.id)
        }
        #expect(result.browser == safari)
        #expect(await counter.value == 1)
    }

    @Test func declineShowsOriginalError() async throws {
        let fake = try fakeNeedingCookies()
        let client = fake.client
        await #expect(throws: AppError(.signInRequired, details: "ERROR: [youtube] x: Sign in to confirm your age")) {
            _ = try await retry(choice: .notChosen, asked: .declined).run { browser in
                try await client.analyze(url, cookiesFromBrowser: browser?.id)
            }
        }
    }

    @Test func noRetryWhenCookiesWereUsedFromTheStart() async throws {
        let fake = try FakeYtDlp(body: "echo 'ERROR: [youtube] x: Private video' >&2\nexit 1\n")
        let client = fake.client
        let calls = Counter()
        await #expect(throws: AppError.self) {
            _ = try await retry(choice: .browser(safari)).run(initialBrowser: safari) { browser in
                await calls.increment()
                return try await client.analyze(url, cookiesFromBrowser: browser?.id)
            }
        }
        #expect(await calls.value == 1)
    }
}

actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}
