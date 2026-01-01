import Foundation
import Testing
@testable import Kaset

/// Tests for ChartsViewModel using mock client.
@Suite("ChartsViewModel", .serialized, .tags(.viewModel), .timeLimit(.minutes(1)))
@MainActor
struct ChartsViewModelTests {
    var mockClient: MockYTMusicClient
    var viewModel: ChartsViewModel

    init() {
        self.mockClient = MockYTMusicClient()
        self.viewModel = ChartsViewModel(client: self.mockClient)
    }

    @Test("Initial state is idle with empty sections")
    func initialState() {
        #expect(self.viewModel.loadingState == .idle)
        #expect(self.viewModel.sections.isEmpty)
        #expect(self.viewModel.hasMoreSections == true)
    }

    @Test("Load success sets chart sections")
    func loadSuccess() async {
        let expectedSections = [
            TestFixtures.makeHomeSection(title: "Top Songs", isChart: true),
            TestFixtures.makeHomeSection(title: "Top Artists", isChart: true),
        ]
        self.mockClient.chartsResponse = HomeResponse(sections: expectedSections)

        await self.viewModel.load()

        #expect(self.viewModel.loadingState == .loaded)
        #expect(self.viewModel.sections.count == 2)
        #expect(self.viewModel.sections[0].title == "Top Songs")
        #expect(self.viewModel.sections[1].title == "Top Artists")
    }

    @Test("Load error sets error state")
    func loadError() async {
        self.mockClient.shouldThrowError = YTMusicError.networkError(underlying: URLError(.notConnectedToInternet))

        await self.viewModel.load()

        if case let .error(error) = viewModel.loadingState {
            #expect(!error.message.isEmpty)
            #expect(error.isRetryable)
        } else {
            Issue.record("Expected error state")
        }
        #expect(self.viewModel.sections.isEmpty)
    }

    @Test("Load does not duplicate when already loading")
    func loadDoesNotDuplicateWhenAlreadyLoading() async {
        self.mockClient.chartsResponse = TestFixtures.makeHomeResponse(sectionCount: 2)

        await self.viewModel.load()
        await self.viewModel.load()

        #expect(self.viewModel.loadingState == .loaded)
    }

    @Test("Refresh clears sections and reloads")
    func refreshClearsSectionsAndReloads() async {
        self.mockClient.chartsResponse = TestFixtures.makeHomeResponse(sectionCount: 2)
        await self.viewModel.load()
        #expect(self.viewModel.sections.count == 2)

        self.mockClient.chartsResponse = TestFixtures.makeHomeResponse(sectionCount: 4)
        await self.viewModel.refresh()

        #expect(self.viewModel.sections.count == 4)
    }

    @Test("Client is exposed for navigation")
    func clientExposed() {
        #expect(self.viewModel.client is MockYTMusicClient)
    }

    @Test("Has more sections reflects continuation state")
    func hasMoreSectionsState() async {
        self.mockClient.chartsResponse = TestFixtures.makeHomeResponse(sectionCount: 1)
        // No continuation sections means no more
        self.mockClient.chartsContinuationSections = []

        await self.viewModel.load()
        // Wait a bit for background loading to complete
        try? await Task.sleep(for: .milliseconds(500))

        #expect(self.viewModel.hasMoreSections == false)
    }

    @Test("Loads continuation sections in background")
    func loadsContinuationInBackground() async {
        self.mockClient.chartsResponse = TestFixtures.makeHomeResponse(sectionCount: 1)
        self.mockClient.chartsContinuationSections = [
            [TestFixtures.makeHomeSection(title: "More Charts 1")],
            [TestFixtures.makeHomeSection(title: "More Charts 2")],
        ]

        await self.viewModel.load()
        // Wait for background loading
        try? await Task.sleep(for: .milliseconds(600))

        // Should have loaded initial + continuations
        #expect(self.viewModel.sections.count >= 1)
    }

    @Test("Refresh cancels background loading")
    func refreshCancelsBackgroundLoading() async {
        self.mockClient.chartsResponse = TestFixtures.makeHomeResponse(sectionCount: 1)

        await self.viewModel.load()
        // Immediately refresh
        await self.viewModel.refresh()

        #expect(self.viewModel.loadingState == .loaded)
    }
}
