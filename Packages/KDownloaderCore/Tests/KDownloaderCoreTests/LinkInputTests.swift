import Foundation
import Testing
@testable import KDownloaderCore

struct LinkInputTests {
    @Test(arguments: [
        ("https://www.youtube.com/watch?v=abc", "https://www.youtube.com/watch?v=abc"),
        ("  https://youtu.be/abc\n", "https://youtu.be/abc"),
        ("HTTP://example.com/video", "HTTP://example.com/video"),
        ("https://www.youtube.com/watch?v=abc&list=PL123", "https://www.youtube.com/watch?v=abc&list=PL123"),
    ])
    func acceptsHTTPLinks(text: String, expected: String) {
        #expect(LinkInput.url(from: text)?.absoluteString == expected)
    }

    @Test(arguments: ["", "   ", "hello world", "youtube.com/watch?v=abc", "ftp://example.com/file",
                      "file:///etc/passwd", "https://", "https://exa mple.com"])
    func rejectsInvalidText(text: String) {
        #expect(LinkInput.url(from: text) == nil)
    }

    @Test func emptyFieldHasNoText() {
        #expect(!LinkInput.hasText(""))
        #expect(!LinkInput.hasText(" \n"))
        #expect(LinkInput.hasText("hello"))
    }

    @Test func pastingALinkIntoAnEmptyField() {
        #expect(LinkInput.isPastedLink(old: "", new: "https://www.youtube.com/watch?v=abc"))
        #expect(LinkInput.isPastedLink(old: "", new: "  https://youtu.be/abc\n"))
    }

    @Test func pastingOverASelectionOrIntoText() {
        // Select-all + paste replaces the text; it arrives as one change.
        #expect(LinkInput.isPastedLink(old: "x", new: "https://youtu.be/abc"))
        #expect(LinkInput.isPastedLink(old: "https://", new: "https://youtu.be/abc"))
        // Replacing a long link with a shorter one.
        #expect(LinkInput.isPastedLink(old: "https://www.youtube.com/watch?v=0e3GPea1Tyg", new: "https://example.com/"))
    }

    @Test func typingDoesNotCountAsPaste() {
        #expect(!LinkInput.isPastedLink(old: "https://youtu.be/ab", new: "https://youtu.be/abc"))
        #expect(!LinkInput.isPastedLink(old: "https://youtu.be/abc", new: "https://youtu.be/ab"))
        // Typing over a selection replaces it with one character.
        #expect(!LinkInput.isPastedLink(old: "https://youtu.be/abc", new: "https://youtu.be/x"))
    }

    @Test func pastingSomethingElse() {
        #expect(!LinkInput.isPastedLink(old: "", new: "hello world"))
        #expect(!LinkInput.isPastedLink(old: "", new: "youtube.com/watch?v=abc"))
    }
}
