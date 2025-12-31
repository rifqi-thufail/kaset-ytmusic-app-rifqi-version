import Foundation
import Observation
import os

/// View model for the PlaylistDetailView.
@MainActor
@Observable
final class PlaylistDetailViewModel {
    /// Current loading state.
    private(set) var loadingState: LoadingState = .idle

    /// The loaded playlist detail.
    private(set) var playlistDetail: PlaylistDetail?

    private let playlist: Playlist
    /// The API client (exposed for add to library action).
    let client: any YTMusicClientProtocol
    private let logger = DiagnosticsLogger.api

    init(playlist: Playlist, client: any YTMusicClientProtocol) {
        self.playlist = playlist
        self.client = client
    }

    /// Loads the playlist details including tracks.
    func load() async {
        guard self.loadingState != .loading else { return }

        self.loadingState = .loading
        let playlistTitle = self.playlist.title
        self.logger.info("Loading playlist: \(playlistTitle)")

        do {
            var detail = try await client.getPlaylist(id: self.playlist.id)

            // Determine the best thumbnail to use:
            // 1. API response header thumbnail
            // 2. Original playlist thumbnail (from navigation)
            // 3. First track's thumbnail as fallback
            let resolvedThumbnailURL = detail.thumbnailURL
                ?? self.playlist.thumbnailURL
                ?? detail.tracks.first?.thumbnailURL

            // Check if we need to merge with original playlist info
            let needsMerge = detail.title == "Unknown Playlist" && self.playlist.title != "Unknown Playlist"
            let thumbnailMissing = detail.thumbnailURL == nil && resolvedThumbnailURL != nil

            if needsMerge || thumbnailMissing {
                // Merge with original playlist info or add fallback thumbnail
                let mergedPlaylist = Playlist(
                    id: playlist.id,
                    title: needsMerge ? self.playlist.title : detail.title,
                    description: detail.description ?? self.playlist.description,
                    thumbnailURL: resolvedThumbnailURL,
                    trackCount: detail.tracks.count,
                    author: detail.author ?? self.playlist.author
                )
                detail = PlaylistDetail(
                    playlist: mergedPlaylist,
                    tracks: detail.tracks,
                    duration: detail.duration
                )
            }

            self.playlistDetail = detail
            self.loadingState = .loaded
            let trackCount = detail.tracks.count
            self.logger.info("Playlist loaded: \(trackCount) tracks")
        } catch is CancellationError {
            // Task was cancelled (e.g., user navigated away) — reset to idle so it can retry
            self.logger.debug("Playlist detail load cancelled")
            self.loadingState = .idle
        } catch {
            self.logger.error("Failed to load playlist: \(error.localizedDescription)")
            self.loadingState = .error(LoadingError(from: error))
        }
    }

    /// Refreshes the playlist.
    func refresh() async {
        self.playlistDetail = nil
        await self.load()
    }
}
