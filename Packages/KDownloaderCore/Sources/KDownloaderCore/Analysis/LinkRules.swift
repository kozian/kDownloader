import Foundation

/// Decides whether an analyzed link can be downloaded.
public enum LinkRules {
    /// Returns the video, or the reason it cannot be processed.
    public static func video(from response: AnalysisResponse) -> Result<VideoInfo, AppError> {
        switch response.kind {
        case .playlist(let id, let title):
            return .failure(AppError(.playlistsAndChannels, details: [title, id].compactMap { $0 }.joined(separator: " — ")))
        case .video(let video):
            if let status = video.liveStatus, status == "is_live" || status == "is_upcoming" {
                return .failure(AppError(.liveStream, details: "live_status: \(status)"))
            }
            return .success(video)
        }
    }
}
