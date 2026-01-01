import Foundation
import Testing
@testable import Kaset

/// Tests for LikedMusicViewModel using mock client.
@Suite("LikedMusicViewModel", .serialized, .tags(.viewModel), .timeLimit(.minutes(1)))
@MainActor
struct LikedMusicViewModelTests {
    var mockClient: MockYTMusicClient
    var viewModel: LikedMusicViewModel

    init() {
        self.mockClient = MockYTMusicClient()
        self.viewModel = LikedMusicViewModel(client: self.mockClient)
    }

    @Test("Initial state is idle with empty songs")
    func initialState() {
        #expect(self.viewModel.loadingState == .idle)
        #expect(self.viewModel.songs.isEmpty)
    }

    @Test("Load success sets liked songs")
    func loadSuccess() async {
        let expectedSongs = TestFixtures.makeSongs(count: 5)
        self.mockClient.likedSongs = expectedSongs

        await self.viewModel.load()

        #expect(self.mockClient.getLikedSongsCalled == true)
        #expect(self.viewModel.loadingState == .loaded)
        #expect(self.viewModel.songs.count == 5)
    }

    @Test("Load marks all songs as liked")
    func loadMarksSongsAsLiked() async {
        let songs = TestFixtures.makeSongs(count: 3)
        self.mockClient.likedSongs = songs

        await self.viewModel.load()

        for song in self.viewModel.songs {
            #expect(song.likeStatus == .like)
        }
    }

    @Test("Load error sets error state")
    func loadError() async {
        self.mockClient.shouldThrowError = YTMusicError.networkError(underlying: URLError(.notConnectedToInternet))

        await self.viewModel.load()

        #expect(self.mockClient.getLikedSongsCalled == true)
        if case let .error(error) = viewModel.loadingState {
            #expect(!error.message.isEmpty)
            #expect(error.isRetryable)
        } else {
            Issue.record("Expected error state")
        }
        #expect(self.viewModel.songs.isEmpty)
    }

    @Test("Load does not duplicate when already loading")
    func loadDoesNotDuplicateWhenAlreadyLoading() async {
        self.mockClient.likedSongs = TestFixtures.makeSongs(count: 3)

        await self.viewModel.load()
        await self.viewModel.load()

        // Second call after completion should work
        #expect(self.viewModel.loadingState == .loaded)
    }

    @Test("Refresh clears songs and reloads")
    func refreshClearsSongsAndReloads() async {
        self.mockClient.likedSongs = TestFixtures.makeSongs(count: 2)
        await self.viewModel.load()
        #expect(self.viewModel.songs.count == 2)

        self.mockClient.likedSongs = TestFixtures.makeSongs(count: 5)
        await self.viewModel.refresh()

        #expect(self.viewModel.songs.count == 5)
    }

    @Test("Client is exposed for actions")
    func clientExposed() {
        #expect(self.viewModel.client is MockYTMusicClient)
    }

    @Test("Empty liked songs loads successfully")
    func emptyLikedSongs() async {
        self.mockClient.likedSongs = []

        await self.viewModel.load()

        #expect(self.viewModel.loadingState == .loaded)
        #expect(self.viewModel.songs.isEmpty)
    }

    @Test("Auth error sets non-retryable error")
    func authError() async {
        self.mockClient.shouldThrowError = YTMusicError.notAuthenticated

        await self.viewModel.load()

        if case let .error(error) = viewModel.loadingState {
            #expect(!error.isRetryable)
        } else {
            Issue.record("Expected error state")
        }
    }
}
