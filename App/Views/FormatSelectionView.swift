import KDownloaderCore
import SwiftUI

/// The Video and Audio menus with "Show all formats". Without an analyzed
/// video the menus are shown empty and disabled.
struct FormatSelectionView: View {
    @Bindable var session: SessionModel

    private var catalog: FormatCatalog? { session.catalog }
    private var enabled: Bool { session.formatControlsEnabled }

    /// Rows of the main window's grid: Video, Audio and the notes under them.
    var body: some View {
        GridRow {
            Text("Video:").gridColumnAlignment(.trailing)
            HStack(spacing: 6) {
                Picker("Video", selection: $session.videoChoice) {
                    videoItems
                }
                .labelsHidden()
                .fixedSize()
                .disabled(!enabled)
                CompatibilityIcon(issue: enabled ? issues.video : nil)
            }
        }
        GridRow {
            Text("Audio:")
            HStack(spacing: 6) {
                Picker("Audio", selection: $session.audioChoice) {
                    audioItems
                }
                .labelsHidden()
                .fixedSize()
                .disabled(!enabled || catalog?.audioMenuEnabled(for: session.videoChoice) == false || audioTracks.isEmpty)
                CompatibilityIcon(issue: enabled ? issues.audio : nil)
            }
        }
        if let catalog, enabled, !session.showAllFormats, catalog.videoPresets.isEmpty {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                VStack(alignment: .leading, spacing: 4) {
                    notes
                }
            }
        }
    }

    private var issues: (video: Compatibility?, audio: Compatibility?) {
        catalog?.compatibilityIssues(video: session.videoChoice, audio: session.audioChoice) ?? (nil, nil)
    }

    // MARK: Menus

    @ViewBuilder
    private var videoItems: some View {
        if let catalog {
            if session.showAllFormats {
                ForEach(catalog.videoGroups) { group in
                    Section(GroupHeader.video(group)) {
                        ForEach(group.formats) { format in
                            Label(EntryLabel.video(format), systemImage: "display").tag(VideoChoice.format(format.id))
                        }
                    }
                }
            } else if let best = catalog.videoPresets.first {
                Label("Best compatible (\(String(best.height))p)", systemImage: "display").tag(VideoChoice.bestCompatible)
                ForEach(catalog.videoPresets) { preset in
                    Label(preset.video.summary, systemImage: "display").tag(VideoChoice.height(preset.height))
                }
            }
            if catalog.supportsAudioOnly {
                Divider()
                Text("No video (audio only)").tag(VideoChoice.none)
            }
        } else {
            Text("Best compatible").tag(session.videoChoice)
        }
    }

    /// Base language codes shared by several tracks, e.g. zh-Hans and zh-Hant.
    private var ambiguousLanguages: Set<String> {
        let identifiers = Set(audioTracks.compactMap(\.language))
        let codes = identifiers.map(TrackRow.baseCode)
        return Set(codes.filter { code in codes.filter { $0 == code }.count > 1 })
    }

    private var audioTracks: [AudioTrack] {
        guard let catalog else { return [] }
        return session.showAllFormats ? catalog.allAudioTracks : catalog.compatibleAudioTracks
    }

    @ViewBuilder
    private var audioItems: some View {
        if catalog == nil {
            Text("Original language").tag(session.audioChoice)
        } else if catalog?.audioMenuEnabled(for: session.videoChoice) == false {
            Text("Included in the video").tag(session.audioChoice)
        } else {
            if session.showAllFormats, let catalog {
                Text("No audio").tag(AudioChoice.none)
                ForEach(catalog.audioGroups) { group in
                    Section(GroupHeader.audio(group)) {
                        ForEach(group.tracks) { track in
                            Label(EntryLabel.audio(track, ambiguous: ambiguousLanguages), systemImage: "speaker.wave.2")
                                .tag(AudioChoice.track(track.id))
                        }
                    }
                }
            } else {
                if audioTracks.isEmpty {
                    Text("No audio tracks").tag(session.audioChoice)
                }
                ForEach(audioTracks) { track in
                    Label(TrackRow.label(track, detailed: false, ambiguous: ambiguousLanguages), systemImage: "speaker.wave.2")
                        .tag(AudioChoice.track(track.id))
                }
            }
        }
    }

    // MARK: Notes

    @ViewBuilder
    private var notes: some View {
        Label("No compatible formats — turn on “Show all formats” in Settings", systemImage: "info.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
    }
}

/// An orange warning to the right of a menu whose choice lowers compatibility (red
/// would read as an error); the
/// requirement is shown as its tooltip. Nothing for the best compatibility.
private struct CompatibilityIcon: View {
    let issue: Compatibility?

    var body: some View {
        if let issue, let text = Self.text(issue) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .help(text)
                .accessibilityLabel(text)
        }
    }

    static func text(_ issue: Compatibility) -> String? {
        switch issue {
        case .best: nil
        case .thirdPartyPlayer(let codecs):
            String(localized: "Needs a third-party player: QuickTime does not open MKV (\(codecs.joined(separator: ", ")))")
        case .m3OrLater:
            String(localized: "Needs a Mac with M3 or later: hardware AV1 decoding")
        }
    }
}

/// Section headers of the full lists: the format, then its compatibility.
enum GroupHeader {
    static func video(_ group: VideoFormatGroup) -> String {
        "\(group.codec) · \(group.container.rawValue.uppercased()) — \(note(group.requirement))"
    }

    static func audio(_ group: AudioFormatGroup) -> String {
        let title = [group.codec, group.containerName].compactMap { $0 }.joined(separator: " · ")
        return "\(title) — \(note(group.requirement))"
    }

    private static func note(_ requirement: PlaybackRequirement?) -> String {
        switch requirement {
        case nil: String(localized: "best compatibility with Mac")
        case .thirdPartyPlayer: String(localized: "⚠︎ needs a third-party player")
        case .m3OrLater: String(localized: "⚠︎ needs a Mac with M3 or later")
        }
    }
}

/// Entries of the full lists; the codec is already in the section header.
enum EntryLabel {
    static func video(_ format: MediaFormat) -> String {
        var parts: [String] = []
        if let height = format.height {
            let fps = format.fps.map { $0 > 30 ? String(Int($0.rounded())) : "" } ?? ""
            parts.append("\(height)p\(fps)")
        } else {
            parts.append(format.note ?? format.id)
        }
        if format.hasAudio {
            parts.append(String(localized: "with audio"))
        }
        if let size = format.fileSize {
            parts.append(size.formatted(.byteCount(style: .file)))
        }
        return parts.joined(separator: " · ")
    }

    static func audio(_ track: AudioTrack, ambiguous: Set<String>) -> String {
        var parts = [TrackRow.name(track, ambiguous: ambiguous)]
        if let bitrate = track.format.bitrate {
            parts.append("\(Int(bitrate.rounded())) kbps")
        }
        if let size = track.format.fileSize {
            parts.append(size.formatted(.byteCount(style: .file)))
        }
        return parts.joined(separator: " · ")
    }
}

enum TrackRow {
    /// "English" for `en-US`: the language only, capitalized (Russian names are lowercase).
    /// Uses the full name ("Chinese (Simplified)") when the base language is ambiguous.
    static func languageName(_ identifier: String, ambiguous: Set<String> = []) -> String? {
        let code = baseCode(identifier)
        let name = ambiguous.contains(code)
            ? Locale.current.localizedString(forIdentifier: identifier)
            : Locale.current.localizedString(forLanguageCode: code)
        guard let name else { return nil }
        return name.prefix(1).uppercased(with: .current) + name.dropFirst()
    }

    static func baseCode(_ identifier: String) -> String {
        Locale.Language(identifier: identifier).languageCode?.identifier ?? identifier
    }

    /// "Original (English)", "Russian", or "Original" without a language, plus codec details in the full list
    /// or when the track has to be converted.
    /// "Original (English)", "Russian" or "Original".
    static func name(_ track: AudioTrack, ambiguous: Set<String>) -> String {
        let language = track.language.flatMap { languageName($0, ambiguous: ambiguous) }
        if track.isOriginal {
            return language.map { String(localized: "Original (\($0))") } ?? String(localized: "Original")
        }
        return language ?? MediaFormat.codecName(track.format.audioCodec)
    }

    static func label(_ track: AudioTrack, detailed: Bool, ambiguous: Set<String> = []) -> String {
        var name = track.language.flatMap { languageName($0, ambiguous: ambiguous) }
        if track.isOriginal {
            name = name.map { String(localized: "Original (\($0))") } ?? String(localized: "Original")
        }
        var parts: [String] = []
        if let name {
            parts.append(name)
        }
        if detailed || name == nil {
            parts.append(track.format.summary)
        } else if track.needsConversion {
            parts.append(String(localized: "\(MediaFormat.codecName(track.format.audioCodec)) → AAC"))
        }
        let label = parts.joined(separator: " · ")
        return detailed && !FormatCatalog.badges(for: track.format).isEmpty ? "\(label)  ⚠︎" : label
    }
}
