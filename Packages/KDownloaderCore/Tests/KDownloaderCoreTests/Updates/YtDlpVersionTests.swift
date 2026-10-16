import Testing
@testable import KDownloaderCore

struct YtDlpVersionTests {
    @Test(arguments: ["2026.08.19", "2026.10.01.1", " 2026.08.19\n"])
    func parsesReleaseTags(tag: String) {
        #expect(YtDlpVersion(tag) != nil)
    }

    @Test(arguments: ["", "2026.08", "v2026.08.19", "2026.08.19-nightly", "2026.08.19.1.2", "2026..19"])
    func rejectsOtherStrings(text: String) {
        #expect(YtDlpVersion(text) == nil)
    }

    @Test func comparesComponentWise() throws {
        let a = try #require(YtDlpVersion("2026.08.19"))
        let b = try #require(YtDlpVersion("2026.08.19.1"))
        let c = try #require(YtDlpVersion("2026.10.01"))
        let d = try #require(YtDlpVersion("2026.9.30"))
        #expect(a < b)
        #expect(b < c)
        #expect(d < c)
        #expect(a < d)
        #expect([c, a, b].sorted() == [a, b, c])
    }

    @Test func equalVersions() throws {
        #expect(YtDlpVersion("2026.08.19") == YtDlpVersion("2026.08.19.0"))
        #expect(YtDlpVersion("2026.08.19")?.description == "2026.08.19")
        #expect(YtDlpVersion("2026.10.01.1")?.description == "2026.10.01.1")
    }
}
