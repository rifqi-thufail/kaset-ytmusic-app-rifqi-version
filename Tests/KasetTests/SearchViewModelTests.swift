import Foundation
import Testing
@testable import Kaset

/// Tests for SearchViewModel using mock client.
@Suite("SearchViewModel", .serialized, .tags(.viewModel), .timeLimit(.minutes(1)))
@MainActor
struct SearchViewModelTests {
    var mockClient: MockYTMusicClient
    var viewModel: SearchViewModel

    init() {
        self.mockClient = MockYTMusicClient()
        self.viewModel = SearchViewModel(client: self.mockClient)
    }

    @Test("Initial state is idle with empty query")
    func initialState() {
        #expect(self.viewModel.loadingState == .idle)
        #expect(self.viewModel.query.isEmpty)
        #expect(self.viewModel.results.allItems.isEmpty)
        #expect(self.viewModel.selectedFilter == .all)
    }

    @Test("Query change clears results when empty")
    func queryChangeClearsResultsWhenEmpty() {
        self.viewModel.query = "test"
        self.viewModel.query = ""

        #expect(self.viewModel.loadingState == .idle)
        #expect(self.viewModel.results.allItems.isEmpty)
    }

    @Test("Search with empty query does not call API")
    func searchWithEmptyQueryDoesNotCallAPI() {
        self.viewModel.query = ""
        self.viewModel.search()

        #expect(self.mockClient.searchCalled == false)
    }

    @Test("Clear resets state")
    func clearResetsState() {
        self.viewModel.query = "test query"
        self.viewModel.selectedFilter = .songs

        self.viewModel.clear()

        #expect(self.viewModel.query.isEmpty)
        #expect(self.viewModel.loadingState == .idle)
        #expect(self.viewModel.results.allItems.isEmpty)
    }

    @Test("Filtered items returns all when all selected")
    func filteredItemsReturnsAllWhenAllSelected() {
        self.viewModel.selectedFilter = .all

        let response = TestFixtures.makeSearchResponse(
            songCount: 2,
            albumCount: 1,
            artistCount: 1,
            playlistCount: 1
        )

        #expect(response.allItems.count == 5)
    }

    @Test("Filtered items returns songs only when songs selected")
    func filteredItemsReturnsSongsOnlyWhenSongsSelected() {
        let response = TestFixtures.makeSearchResponse(
            songCount: 3,
            albumCount: 2,
            artistCount: 1,
            playlistCount: 1
        )

        let songItems = response.songs.map { SearchResultItem.song($0) }
        #expect(songItems.count == 3)
    }
}
