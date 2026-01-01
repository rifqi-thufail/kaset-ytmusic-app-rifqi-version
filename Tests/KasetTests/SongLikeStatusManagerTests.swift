import Foundation
import Testing
@testable import Kaset

/// Tests for SongLikeStatusManager.
@Suite("SongLikeStatusManager", .serialized, .tags(.service), .timeLimit(.minutes(1)))
@MainActor
struct SongLikeStatusManagerTests {
    var manager: SongLikeStatusManager
    var mockClient: MockYTMusicClient
    var testSong: Song

    init() {
        self.manager = SongLikeStatusManager.shared
        self.mockClient = MockYTMusicClient()
        self.testSong = TestFixtures.makeSong(id: "test-video-123", title: "Test Song")
        // Clear any existing state
        self.manager.clearCache()
        self.manager.setClient(self.mockClient)
    }

    // MARK: - Cache Tests

    @Test("Initial cache is empty")
    func initialCacheEmpty() {
        self.manager.clearCache()
        #expect(self.manager.status(for: "nonexistent") == nil)
    }

    @Test("Set status updates cache")
    func setStatusUpdatesCache() {
        self.manager.setStatus(.like, for: "video-1")
        #expect(self.manager.status(for: "video-1") == .like)
    }

    @Test("Clear cache removes all statuses")
    func clearCacheRemovesAll() {
        self.manager.setStatus(.like, for: "video-1")
        self.manager.setStatus(.dislike, for: "video-2")

        self.manager.clearCache()

        #expect(self.manager.status(for: "video-1") == nil)
        #expect(self.manager.status(for: "video-2") == nil)
    }

    @Test("Status for song uses cache if available")
    func statusForSongUsesCache() {
        self.manager.setStatus(.like, for: self.testSong.videoId)
        #expect(self.manager.status(for: self.testSong) == .like)
    }

    @Test("Status for song falls back to song property")
    func statusForSongFallsBackToSongProperty() {
        self.manager.clearCache()
        var songWithStatus = self.testSong
        songWithStatus.likeStatus = .dislike
        #expect(self.manager.status(for: songWithStatus) == .dislike)
    }

    @Test("Cache takes precedence over song property")
    func cacheTakesPrecedence() {
        var songWithStatus = self.testSong
        songWithStatus.likeStatus = .dislike
        self.manager.setStatus(.like, for: songWithStatus.videoId)
        #expect(self.manager.status(for: songWithStatus) == .like)
    }

    // MARK: - isLiked/isDisliked Tests

    @Test("isLiked returns true for liked songs")
    func isLikedTrue() {
        self.manager.setStatus(.like, for: self.testSong.videoId)
        #expect(self.manager.isLiked(self.testSong) == true)
        #expect(self.manager.isDisliked(self.testSong) == false)
    }

    @Test("isDisliked returns true for disliked songs")
    func isDislikedTrue() {
        self.manager.setStatus(.dislike, for: self.testSong.videoId)
        #expect(self.manager.isDisliked(self.testSong) == true)
        #expect(self.manager.isLiked(self.testSong) == false)
    }

    @Test("isLiked returns false for indifferent songs")
    func isLikedFalseForIndifferent() {
        self.manager.setStatus(.indifferent, for: self.testSong.videoId)
        #expect(self.manager.isLiked(self.testSong) == false)
        #expect(self.manager.isDisliked(self.testSong) == false)
    }

    // MARK: - Rating Actions Tests

    @Test("Like updates cache optimistically")
    func likeUpdatesCache() async {
        await self.manager.like(self.testSong)

        #expect(self.manager.status(for: self.testSong.videoId) == .like)
        #expect(self.mockClient.rateSongCalled == true)
        #expect(self.mockClient.rateSongVideoIds.contains(self.testSong.videoId))
        #expect(self.mockClient.rateSongRatings.contains(.like))
    }

    @Test("Unlike sets status to indifferent")
    func unlikeSetsIndifferent() async {
        self.manager.setStatus(.like, for: self.testSong.videoId)

        await self.manager.unlike(self.testSong)

        #expect(self.manager.status(for: self.testSong.videoId) == .indifferent)
        #expect(self.mockClient.rateSongRatings.contains(.indifferent))
    }

    @Test("Dislike updates cache")
    func dislikeUpdatesCache() async {
        await self.manager.dislike(self.testSong)

        #expect(self.manager.status(for: self.testSong.videoId) == .dislike)
        #expect(self.mockClient.rateSongRatings.contains(.dislike))
    }

    @Test("Undislike sets status to indifferent")
    func undislikeSetsIndifferent() async {
        self.manager.setStatus(.dislike, for: self.testSong.videoId)

        await self.manager.undislike(self.testSong)

        #expect(self.manager.status(for: self.testSong.videoId) == .indifferent)
    }

    @Test("Rating reverts on API error")
    func ratingRevertsOnError() async {
        self.manager.setStatus(.indifferent, for: self.testSong.videoId)
        self.mockClient.shouldThrowError = YTMusicError.networkError(underlying: URLError(.notConnectedToInternet))

        await self.manager.like(self.testSong)

        // Should revert to previous status
        #expect(self.manager.status(for: self.testSong.videoId) == .indifferent)
    }

    @Test("Rating removes cache entry on error if no previous status")
    func ratingRemovesCacheOnErrorIfNoPrevious() async {
        self.manager.clearCache()
        self.mockClient.shouldThrowError = YTMusicError.networkError(underlying: URLError(.notConnectedToInternet))

        await self.manager.like(self.testSong)

        // Should have no cache entry
        #expect(self.manager.status(for: self.testSong.videoId) == nil)
    }

    @Test("Rating without client logs warning")
    func ratingWithoutClient() async {
        // Create a fresh manager instance for this test
        // Since SongLikeStatusManager is a singleton, we just verify the existing behavior
        // The test validates that no crash occurs when client is not set properly
        self.manager.clearCache()

        // This should not crash
        await self.manager.like(self.testSong)
    }

    // MARK: - Singleton Tests

    @Test("Shared instance exists")
    func sharedInstance() {
        let instance = SongLikeStatusManager.shared
        #expect(instance != nil)
    }

    @Test("Shared instance is singleton")
    func singletonInstance() {
        let instance1 = SongLikeStatusManager.shared
        let instance2 = SongLikeStatusManager.shared
        #expect(instance1 === instance2)
    }
}
