import Foundation
import Testing
@testable import KDownloaderCore

struct UpdateStateTests {
    let defaults: UserDefaults
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let active = YtDlpVersion("2026.08.19")!
    let newer = YtDlpVersion("2026.10.01")!

    init() {
        let suite = "UpdateStateTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    private var state: UpdateState { UpdateState(defaults: defaults) }

    @Test func firstCheckIsDue() {
        #expect(state.isCheckDue(now: now))
    }

    @Test func checksAtMostOnceADay() {
        state.recordCheck(latest: active, at: now)
        #expect(!state.isCheckDue(now: now.addingTimeInterval(3 * 3600)))
        #expect(state.isCheckDue(now: now.addingTimeInterval(24 * 3600)))
        // A clock moved backwards does not block checks forever.
        #expect(state.isCheckDue(now: now.addingTimeInterval(-60)))
    }

    @Test func failedCheckAlsoWaitsADay() {
        state.recordFailedCheck(at: now)
        #expect(!state.isCheckDue(now: now.addingTimeInterval(3600)))
        #expect(state.latestVersion == nil)
    }

    @Test func noticeForNewerVersionUntilDismissed() {
        state.recordCheck(latest: newer, at: now)
        #expect(state.availableUpdate(active: active) == newer)
        #expect(state.showsNotice(active: active))
        state.dismiss(newer)
        #expect(!state.showsNotice(active: active))
        #expect(state.availableUpdate(active: active) == newer)
        // An even newer release brings the notice back.
        state.recordCheck(latest: YtDlpVersion("2026.10.15")!, at: now)
        #expect(state.showsNotice(active: active))
    }

    @Test func noNoticeWhenUpToDate() {
        state.recordCheck(latest: active, at: now)
        #expect(state.availableUpdate(active: active) == nil)
        #expect(!state.showsNotice(active: newer))
    }
}
