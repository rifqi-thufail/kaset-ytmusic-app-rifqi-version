import Foundation
import Testing
@testable import Kaset

/// Tests for TopSongsViewModel using mock client.
@Suite("TopSongsViewModel", .serialized, .tags(.viewModel), .timeLimit(.minutes(1)))
@MainActor
struct TopSongsViewModelTests {
    var mockClient: MockYTMusicClient

    init() {
        self.mockClient = MockYTMusicClient()
    }

    @Test("Initial state includes destination songs")
    func initialState() {
        let songs = TestFixtures.makeSongs(count: 5)
        let destination = TopSongsDestination(
            artistId: "UC-test-123",
            artistName: "Test Artist",
            songs: songs,
            songsBrowseId: nil,
            songsParams: nil
        )

        let viewModel = TopSongsViewModel(destination: destination, client: self.mockClient)

        #expect(viewModel.loadingState == .idle)
        #expect(viewModel.songs.count == 5)
    }

    @Test("Load without browse ID marks as loaded immediately")
    func loadWithoutBrowseId() async {
        let songs = TestFixtures.makeSongs(count: 5)
        let destination = TopSongsDestination(
            artistId: "UC-test-123",
            artistName: "Test Artist",
            songs: songs,
            songsBrowseId: nil,
            songsParams: nil
        )

        let viewModel = TopSongsViewModel(destination: destination, client: self.mockClient)
        await viewModel.load()

        #expect(viewModel.loadingState == .loaded)
        #expect(viewModel.songs.count == 5)
        #expect(self.mockClient.getArtistSongsCalled == false)
    }

    @Test("Load with browse ID fetches all songs")
    func loadWithBrowseId() async {
        let initialSongs = TestFixtures.makeSongs(count: 5)
        let allSongs = TestFixtures.makeSongs(count: 20)
        let destination = TopSongsDestination(
            artistId: "UC-test-123",
            artistName: "Test Artist",
            songs: initialSongs,
            songsBrowseId: "browse-123",
            songsParams: "params-abc"
        )
        self.mockClient.artistSongs["browse-123"] = allSongs

        let viewModel = TopSongsViewModel(destination: destination, client: self.mockClient)
        await viewModel.load()

        #expect(viewModel.loadingState == .loaded)
        #expect(viewModel.songs.count == 20)
        #expect(self.mockClient.getArtistSongsCalled == true)
        #expect(self.mockClient.getArtistSongsBrowseIds.contains("browse-123"))
    }

    @Test("Load does not duplicate when already loading")
    func loadDoesNotDuplicateWhenAlreadyLoading() async {
        let destination = TopSongsDestination(
            artistId: "UC-test-123",
            artistName: "Test Artist",
            songs: TestFixtures.makeSongs(count: 5),
            songsBrowseId: "browse-123",
            songsParams: nil
        )
        self.mockClient.artistSongs["browse-123"] = TestFixtures.makeSongs(count: 10)

        let viewModel = TopSongsViewModel(destination: destination, client: self.mockClient)
        await viewModel.load()
        await viewModel.load()

        // Second call after completion should work
        #expect(viewModel.loadingState == .loaded)
    }

    @Test("Load keeps existing songs on error")
    func loadKeepsSongsOnError() async {
        let initialSongs = TestFixtures.makeSongs(count: 5)
        let destination = TopSongsDestination(
            artistId: "UC-test-123",
            artistName: "Test Artist",
            songs: initialSongs,
            songsBrowseId: "browse-123",
            songsParams: nil
        )
        self.mockClient.shouldThrowError = YTMusicError.networkError(underlying: URLError(.notConnectedToInternet))

        let viewModel = TopSongsViewModel(destination: destination, client: self.mockClient)
        await viewModel.load()

        // Should keep original songs and mark as loaded
        #expect(viewModel.loadingState == .loaded)
        #expect(viewModel.songs.count == 5)
    }

    @Test("Load keeps existing songs on empty response")
    func loadKeepsSongsOnEmptyResponse() async {
        let initialSongs = TestFixtures.makeSongs(count: 5)
        let destination = TopSongsDestination(
            artistId: "UC-test-123",
            artistName: "Test Artist",
            songs: initialSongs,
            songsBrowseId: "browse-123",
            songsParams: nil
        )
        self.mockClient.artistSongs["browse-123"] = []

        let viewModel = TopSongsViewModel(destination: destination, client: self.mockClient)
        await viewModel.load()

        // Should keep original songs when API returns empty
        #expect(viewModel.songs.count == 5)
    }

    @Test("Client is exposed")
    func clientExposed() {
        let destination = TopSongsDestination(
            artistId: "UC-test-123",
            artistName: "Test Artist",
            songs: [],
            songsBrowseId: nil,
            songsParams: nil
        )

        let viewModel = TopSongsViewModel(destination: destination, client: self.mockClient)
        #expect(viewModel.client is MockYTMusicClient)
    }
}
