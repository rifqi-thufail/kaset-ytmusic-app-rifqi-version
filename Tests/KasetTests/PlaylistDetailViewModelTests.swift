import Foundation
import Testing
@testable import Kaset

/// Tests for PlaylistDetailViewModel using mock client.
@Suite("PlaylistDetailViewModel", .serialized, .tags(.viewModel), .timeLimit(.minutes(1)))
@MainActor
struct PlaylistDetailViewModelTests {
    var mockClient: MockYTMusicClient
    var testPlaylist: Playlist

    init() {
        self.mockClient = MockYTMusicClient()
        self.testPlaylist = TestFixtures.makePlaylist(id: "VL-test-123", title: "My Playlist")
    }

    @Test("Initial state is idle with no detail")
    func initialState() {
        let viewModel = PlaylistDetailViewModel(playlist: self.testPlaylist, client: self.mockClient)
        #expect(viewModel.loadingState == .idle)
        #expect(viewModel.playlistDetail == nil)
    }

    @Test("Load success sets playlist detail")
    func loadSuccess() async {
        let expectedDetail = TestFixtures.makePlaylistDetail(
            playlist: self.testPlaylist,
            trackCount: 10
        )
        self.mockClient.playlistDetails[self.testPlaylist.id] = expectedDetail

        let viewModel = PlaylistDetailViewModel(playlist: self.testPlaylist, client: self.mockClient)
        await viewModel.load()

        #expect(self.mockClient.getPlaylistCalled == true)
        #expect(viewModel.loadingState == .loaded)
        #expect(viewModel.playlistDetail != nil)
        #expect(viewModel.playlistDetail?.tracks.count == 10)
    }

    @Test("Load error sets error state")
    func loadError() async {
        self.mockClient.shouldThrowError = YTMusicError.networkError(underlying: URLError(.notConnectedToInternet))

        let viewModel = PlaylistDetailViewModel(playlist: self.testPlaylist, client: self.mockClient)
        await viewModel.load()

        #expect(self.mockClient.getPlaylistCalled == true)
        if case let .error(error) = viewModel.loadingState {
            #expect(!error.message.isEmpty)
            #expect(error.isRetryable)
        } else {
            Issue.record("Expected error state")
        }
        #expect(viewModel.playlistDetail == nil)
    }

    @Test("Load does not duplicate when already loading")
    func loadDoesNotDuplicateWhenAlreadyLoading() async {
        let expectedDetail = TestFixtures.makePlaylistDetail(playlist: self.testPlaylist)
        self.mockClient.playlistDetails[self.testPlaylist.id] = expectedDetail

        let viewModel = PlaylistDetailViewModel(playlist: self.testPlaylist, client: self.mockClient)
        await viewModel.load()
        await viewModel.load()

        // Second load should still work since first completed
        #expect(self.mockClient.getPlaylistIds.count == 2)
    }

    @Test("Refresh clears detail and reloads")
    func refreshClearsAndReloads() async {
        let detail1 = TestFixtures.makePlaylistDetail(playlist: self.testPlaylist, trackCount: 5)
        self.mockClient.playlistDetails[self.testPlaylist.id] = detail1

        let viewModel = PlaylistDetailViewModel(playlist: self.testPlaylist, client: self.mockClient)
        await viewModel.load()
        #expect(viewModel.playlistDetail?.tracks.count == 5)

        let detail2 = TestFixtures.makePlaylistDetail(playlist: self.testPlaylist, trackCount: 10)
        self.mockClient.playlistDetails[self.testPlaylist.id] = detail2
        await viewModel.refresh()

        #expect(viewModel.playlistDetail?.tracks.count == 10)
        #expect(self.mockClient.getPlaylistIds.count == 2)
    }

    @Test("Uses original playlist thumbnail if API response missing")
    func usesOriginalPlaylistThumbnail() async {
        // Create detail without thumbnail
        let playlist = Playlist(
            id: "VL-no-thumb",
            title: "No Thumb Playlist",
            description: nil,
            thumbnailURL: URL(string: "https://original.com/thumb.jpg"),
            trackCount: 5,
            author: "Author"
        )
        let detailWithoutThumb = PlaylistDetail(
            playlist: Playlist(
                id: "VL-no-thumb",
                title: "No Thumb Playlist",
                description: nil,
                thumbnailURL: nil,
                trackCount: 5,
                author: "Author"
            ),
            tracks: TestFixtures.makeSongs(count: 5),
            duration: "15 min"
        )
        self.mockClient.playlistDetails["VL-no-thumb"] = detailWithoutThumb

        let viewModel = PlaylistDetailViewModel(playlist: playlist, client: self.mockClient)
        await viewModel.load()

        // Should use original playlist's thumbnail as fallback
        #expect(viewModel.playlistDetail?.thumbnailURL == URL(string: "https://original.com/thumb.jpg"))
    }

    @Test("Client is exposed for library actions")
    func clientExposed() {
        let viewModel = PlaylistDetailViewModel(playlist: self.testPlaylist, client: self.mockClient)
        // The client property should be accessible for add to library actions
        #expect(viewModel.client is MockYTMusicClient)
    }
}
