import Foundation
import Testing
@testable import Kaset

/// Tests for ArtistDetailViewModel using mock client.
@Suite("ArtistDetailViewModel", .serialized, .tags(.viewModel), .timeLimit(.minutes(1)))
@MainActor
struct ArtistDetailViewModelTests {
    var mockClient: MockYTMusicClient
    var testArtist: Artist

    init() {
        self.mockClient = MockYTMusicClient()
        self.testArtist = TestFixtures.makeArtist(id: "UC-test-123", name: "Test Artist")
    }

    @Test("Initial state is idle with no detail")
    func initialState() {
        let viewModel = ArtistDetailViewModel(artist: self.testArtist, client: self.mockClient)
        #expect(viewModel.loadingState == .idle)
        #expect(viewModel.artistDetail == nil)
        #expect(viewModel.showAllSongs == false)
        #expect(viewModel.isSubscribing == false)
    }

    @Test("Load success sets artist detail")
    func loadSuccess() async {
        let expectedDetail = TestFixtures.makeArtistDetail(
            artist: self.testArtist,
            songCount: 10,
            albumCount: 3
        )
        self.mockClient.artistDetails[self.testArtist.id] = expectedDetail

        let viewModel = ArtistDetailViewModel(artist: self.testArtist, client: self.mockClient)
        await viewModel.load()

        #expect(self.mockClient.getArtistCalled == true)
        #expect(viewModel.loadingState == .loaded)
        #expect(viewModel.artistDetail != nil)
        #expect(viewModel.artistDetail?.songs.count == 10)
        #expect(viewModel.artistDetail?.albums.count == 3)
    }

    @Test("Load error sets error state")
    func loadError() async {
        self.mockClient.shouldThrowError = YTMusicError.networkError(underlying: URLError(.notConnectedToInternet))

        let viewModel = ArtistDetailViewModel(artist: self.testArtist, client: self.mockClient)
        await viewModel.load()

        #expect(self.mockClient.getArtistCalled == true)
        if case let .error(error) = viewModel.loadingState {
            #expect(!error.message.isEmpty)
            #expect(error.isRetryable)
        } else {
            Issue.record("Expected error state")
        }
        #expect(viewModel.artistDetail == nil)
    }

    @Test("Load does not duplicate when already loading")
    func loadDoesNotDuplicateWhenAlreadyLoading() async {
        let expectedDetail = TestFixtures.makeArtistDetail(artist: self.testArtist)
        self.mockClient.artistDetails[self.testArtist.id] = expectedDetail

        let viewModel = ArtistDetailViewModel(artist: self.testArtist, client: self.mockClient)
        await viewModel.load()
        await viewModel.load()

        #expect(self.mockClient.getArtistIds.count == 2)
    }

    @Test("Refresh clears detail and reloads")
    func refreshClearsAndReloads() async {
        let detail1 = TestFixtures.makeArtistDetail(artist: self.testArtist, songCount: 5)
        self.mockClient.artistDetails[self.testArtist.id] = detail1

        let viewModel = ArtistDetailViewModel(artist: self.testArtist, client: self.mockClient)
        await viewModel.load()
        viewModel.showAllSongs = true
        #expect(viewModel.artistDetail?.songs.count == 5)

        let detail2 = TestFixtures.makeArtistDetail(artist: self.testArtist, songCount: 10)
        self.mockClient.artistDetails[self.testArtist.id] = detail2
        await viewModel.refresh()

        #expect(viewModel.artistDetail?.songs.count == 10)
        #expect(viewModel.showAllSongs == false)
        #expect(self.mockClient.getArtistIds.count == 2)
    }

    @Test("Client is exposed")
    func clientExposed() {
        let viewModel = ArtistDetailViewModel(artist: self.testArtist, client: self.mockClient)
        #expect(viewModel.client is MockYTMusicClient)
    }

    // MARK: - Displayed Songs Tests

    @Test("Displayed songs returns preview count by default")
    func displayedSongsPreview() async {
        let detail = TestFixtures.makeArtistDetail(artist: self.testArtist, songCount: 10)
        self.mockClient.artistDetails[self.testArtist.id] = detail

        let viewModel = ArtistDetailViewModel(artist: self.testArtist, client: self.mockClient)
        await viewModel.load()

        #expect(viewModel.displayedSongs.count == ArtistDetailViewModel.previewSongCount)
    }

    @Test("Displayed songs returns all when showAllSongs is true")
    func displayedSongsAll() async {
        let detail = TestFixtures.makeArtistDetail(artist: self.testArtist, songCount: 10)
        self.mockClient.artistDetails[self.testArtist.id] = detail

        let viewModel = ArtistDetailViewModel(artist: self.testArtist, client: self.mockClient)
        await viewModel.load()
        viewModel.showAllSongs = true

        #expect(viewModel.displayedSongs.count == 10)
    }

    @Test("Displayed songs returns empty when no detail")
    func displayedSongsEmpty() {
        let viewModel = ArtistDetailViewModel(artist: self.testArtist, client: self.mockClient)
        #expect(viewModel.displayedSongs.isEmpty)
    }

    @Test("Has more songs returns true when more than preview count")
    func hasMoreSongsTrue() async {
        let detail = TestFixtures.makeArtistDetail(artist: self.testArtist, songCount: 10)
        self.mockClient.artistDetails[self.testArtist.id] = detail

        let viewModel = ArtistDetailViewModel(artist: self.testArtist, client: self.mockClient)
        await viewModel.load()

        #expect(viewModel.hasMoreSongs == true)
    }

    @Test("Has more songs returns false when less than preview count")
    func hasMoreSongsFalse() async {
        let detail = TestFixtures.makeArtistDetail(artist: self.testArtist, songCount: 3)
        self.mockClient.artistDetails[self.testArtist.id] = detail

        let viewModel = ArtistDetailViewModel(artist: self.testArtist, client: self.mockClient)
        await viewModel.load()

        #expect(viewModel.hasMoreSongs == false)
    }

    // MARK: - Subscription Tests

    @Test("Toggle subscription subscribes")
    func toggleSubscriptionSubscribes() async {
        var detail = TestFixtures.makeArtistDetail(artist: self.testArtist)
        detail.channelId = "UC-channel-123"
        detail.isSubscribed = false
        self.mockClient.artistDetails[self.testArtist.id] = detail

        let viewModel = ArtistDetailViewModel(artist: self.testArtist, client: self.mockClient)
        await viewModel.load()
        await viewModel.toggleSubscription()

        #expect(self.mockClient.subscribeToArtistCalled == true)
        #expect(self.mockClient.subscribeToArtistIds.contains("UC-channel-123"))
        #expect(viewModel.artistDetail?.isSubscribed == true)
    }

    @Test("Toggle subscription unsubscribes")
    func toggleSubscriptionUnsubscribes() async {
        var detail = TestFixtures.makeArtistDetail(artist: self.testArtist)
        detail.channelId = "UC-channel-123"
        detail.isSubscribed = true
        self.mockClient.artistDetails[self.testArtist.id] = detail

        let viewModel = ArtistDetailViewModel(artist: self.testArtist, client: self.mockClient)
        await viewModel.load()
        await viewModel.toggleSubscription()

        #expect(self.mockClient.unsubscribeFromArtistCalled == true)
        #expect(self.mockClient.unsubscribeFromArtistIds.contains("UC-channel-123"))
        #expect(viewModel.artistDetail?.isSubscribed == false)
    }

    @Test("Toggle subscription does nothing without channel ID")
    func toggleSubscriptionNoChannelId() async {
        let detail = TestFixtures.makeArtistDetail(artist: self.testArtist)
        self.mockClient.artistDetails[self.testArtist.id] = detail

        let viewModel = ArtistDetailViewModel(artist: self.testArtist, client: self.mockClient)
        await viewModel.load()
        await viewModel.toggleSubscription()

        #expect(self.mockClient.subscribeToArtistCalled == false)
        #expect(self.mockClient.unsubscribeFromArtistCalled == false)
    }

    // MARK: - Get All Songs Tests

    @Test("Get all songs returns cached songs")
    async func getAllSongsReturnsCached() async {
        let detail = TestFixtures.makeArtistDetail(artist: self.testArtist, songCount: 10)
        self.mockClient.artistDetails[self.testArtist.id] = detail

        let viewModel = ArtistDetailViewModel(artist: self.testArtist, client: self.mockClient)
        await viewModel.load()

        let songs = await viewModel.getAllSongs()

        #expect(songs.count == 10)
    }

    @Test("Get all songs fetches from API when browse ID available")
    func getAllSongsFetchesFromAPI() async {
        var detail = TestFixtures.makeArtistDetail(artist: self.testArtist, songCount: 5)
        detail.songsBrowseId = "browse-songs-123"
        self.mockClient.artistDetails[self.testArtist.id] = detail
        self.mockClient.artistSongs["browse-songs-123"] = TestFixtures.makeSongs(count: 20)

        let viewModel = ArtistDetailViewModel(artist: self.testArtist, client: self.mockClient)
        await viewModel.load()

        let songs = await viewModel.getAllSongs()

        #expect(self.mockClient.getArtistSongsCalled == true)
        #expect(songs.count == 20)
    }
}
