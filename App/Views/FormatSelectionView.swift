import KDownloaderCore
import SwiftUI

/// The Video and Audio menus with "Show all formats". Without an analyzed
/// video the menus are shown empty and disabled.
struct FormatSelectionView: View {
    @Bindable var session: SessionModel

    private var catalog: FormatCatalog? { session.catalog }
    private var enabled: Bool { session.formatControlsEnabled }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Video").gridColumnAlignment(.trailing)
                    Picker("Video", selection: $session.videoChoice) {
                        videoItems
                    }
                    .labelsHidden()
                    .disabled(!enabled)
                }
                GridRow {
                    Text("Audio")
                    Picker("Audio", selection: $session.audioChoice) {
                        audioItems
                    }
                    .labelsHidden()
                    .disabled(!enabled || catalog?.audioMenuEnabled(for: session.videoChoice) == false || audioTracks.isEmpty)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            notes
        }
    }

    // MARK: Menus

    @ViewBuilder
    private var videoItems: some View {
        if let catalog {
            if session.showAllFormats {
                ForEach(catalog.allVideoFormats) { format in
                    Text(verbatim: FormatRow.label(format)).tag(VideoChoice.format(format.id))
                }
            } else if let best = catalog.videoPresets.first {
                Text("Best compatible (\(String(best.height))p)").tag(VideoChoice.bestCompatible)
                ForEach(catalog.videoPresets) { preset in
                    Text(verbatim: preset.video.summary).tag(VideoChoice.height(preset.height))
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
            if session.showAllFormats {
                Text("No audio").tag(AudioChoice.none)
                Divider()
            } else if audioTracks.isEmpty {
                Text("No audio tracks").tag(session.audioChoice)
            }
            ForEach(audioTracks) { track in
                Text(verbatim: TrackRow.label(track, detailed: session.showAllFormats, ambiguous: ambiguousLanguages))
                    .tag(AudioChoice.track(track.id))
            }
        }
    }

    // MARK: Notes

    @ViewBuilder
    private var notes: some View {
        if let catalog, enabled {
            if !session.showAllFormats, catalog.videoPresets.isEmpty {
                Label("No compatible formats — turn on “Show all formats” in Settings", systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(selectedBadges, id: \.self) { badge in
                Label(badge.text, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var selectedBadges: [FormatBadge] {
        guard let catalog else { return [] }
        var badges: Set<FormatBadge> = []
        let video = catalog.videoFormat(for: session.videoChoice)
        if let video {
            badges.formUnion(FormatCatalog.badges(for: video))
        }
        if video?.hasAudio != true, session.videoChoice != .none,
           case .track(let id) = session.audioChoice,
           let track = catalog.allAudioTracks.first(where: { $0.id == id }) {
            badges.formUnion(FormatCatalog.badges(for: track.format))
        }
        return badges.sorted { $0 == .mayNotOpenInQuickTime && $1 != .mayNotOpenInQuickTime }
    }
}

private enum FormatRow {
    static func label(_ format: MediaFormat) -> String {
        FormatCatalog.badges(for: format).isEmpty ? format.summary : "\(format.summary)  ⚠︎"
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
