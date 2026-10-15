import Foundation

/// Turns a video title into a safe file name that does not overwrite anything.
public enum OutputNamer {
    static let maxNameBytes = 200

    /// Replaces characters that are invalid or awkward in macOS file names,
    /// trims whitespace and limits the length. Falls back to `fallback` when
    /// nothing is left.
    public static func sanitizedName(_ title: String, fallback: String) -> String {
        var name = String(title.unicodeScalars.map { scalar -> Character in
            if scalar == "/" || scalar == ":" || CharacterSet.controlCharacters.contains(scalar) {
                return "-"
            }
            return Character(scalar)
        })
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // A leading dot would make the file hidden.
        while name.hasPrefix(".") {
            name.removeFirst()
        }
        name = truncated(name, maxBytes: maxNameBytes).trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            return fallback == title ? "video" : sanitizedName(fallback, fallback: "video")
        }
        return name
    }

    /// `<name>.<ext>` in `directory`, or `<name> (2).<ext>`, `<name> (3).<ext>`…
    /// if that is taken. Returns the base name without the extension.
    public static func uniqueBaseName(
        _ name: String,
        fileExtension: String,
        in directory: URL,
        fileManager: FileManager = .default
    ) -> String {
        var candidate = name
        var counter = 2
        while fileManager.fileExists(atPath: directory.appending(path: "\(candidate).\(fileExtension)").path) {
            candidate = "\(name) (\(counter))"
            counter += 1
        }
        return candidate
    }

    /// Cuts the string to at most `maxBytes` UTF-8 bytes without splitting a character.
    static func truncated(_ string: String, maxBytes: Int) -> String {
        guard string.utf8.count > maxBytes else { return string }
        var result = ""
        var bytes = 0
        for character in string {
            let size = character.utf8.count
            if bytes + size > maxBytes { break }
            result.append(character)
            bytes += size
        }
        return result
    }
}
