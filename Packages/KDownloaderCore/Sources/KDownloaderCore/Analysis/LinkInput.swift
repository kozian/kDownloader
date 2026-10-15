import Foundation

/// Validation of the text typed into the URL field.
public enum LinkInput {
    /// Returns the link if `text` is an http(s) URL after trimming whitespace.
    public static func url(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains(where: \.isWhitespace),
              let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host, !host.isEmpty,
              let url = components.url
        else {
            return nil
        }
        return url
    }

    /// Whether the field contains anything to analyze; the Analyze button is
    /// disabled otherwise.
    public static func hasText(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Whether a change of the field looks like a paste of a link: more than
    /// one character inserted at once (possibly replacing a selection), and
    /// the result is a valid link. Typing inserts one character per change
    /// and never qualifies.
    public static func isPastedLink(old: String, new: String) -> Bool {
        insertedLength(old: old, new: new) > 1 && url(from: new) != nil
    }

    /// Length of the text that replaced a range of `old` to produce `new`.
    static func insertedLength(old: String, new: String) -> Int {
        let old = Array(old), new = Array(new)
        var prefix = 0
        while prefix < old.count, prefix < new.count, old[prefix] == new[prefix] {
            prefix += 1
        }
        var suffix = 0
        while suffix < old.count - prefix, suffix < new.count - prefix,
              old[old.count - 1 - suffix] == new[new.count - 1 - suffix] {
            suffix += 1
        }
        return new.count - prefix - suffix
    }
}
