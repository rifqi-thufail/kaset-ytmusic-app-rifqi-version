import Foundation
import Testing
@testable import Kaset

/// Tests for SettingsManager.
@Suite("SettingsManager", .serialized, .tags(.service), .timeLimit(.minutes(1)))
@MainActor
struct SettingsManagerTests {
    // MARK: - LaunchPage Tests

    @Test("Launch page display names", arguments: [
        (SettingsManager.LaunchPage.home, "Home"),
        (SettingsManager.LaunchPage.explore, "Explore"),
        (SettingsManager.LaunchPage.charts, "Charts"),
        (SettingsManager.LaunchPage.moodsAndGenres, "Moods & Genres"),
        (SettingsManager.LaunchPage.newReleases, "New Releases"),
        (SettingsManager.LaunchPage.likedMusic, "Liked Music"),
        (SettingsManager.LaunchPage.playlists, "Playlists"),
        (SettingsManager.LaunchPage.lastUsed, "Last Used"),
    ])
    func launchPageDisplayName(page: SettingsManager.LaunchPage, expected: String) {
        #expect(page.displayName == expected)
    }

    @Test("Launch page raw values", arguments: [
        (SettingsManager.LaunchPage.home, "home"),
        (SettingsManager.LaunchPage.explore, "explore"),
        (SettingsManager.LaunchPage.charts, "charts"),
        (SettingsManager.LaunchPage.moodsAndGenres, "moodsAndGenres"),
        (SettingsManager.LaunchPage.newReleases, "newReleases"),
        (SettingsManager.LaunchPage.likedMusic, "likedMusic"),
        (SettingsManager.LaunchPage.playlists, "playlists"),
        (SettingsManager.LaunchPage.lastUsed, "lastUsed"),
    ])
    func launchPageRawValue(page: SettingsManager.LaunchPage, expected: String) {
        #expect(page.rawValue == expected)
    }

    @Test("Launch page navigation item mapping", arguments: [
        (SettingsManager.LaunchPage.home, NavigationItem.home),
        (SettingsManager.LaunchPage.explore, NavigationItem.explore),
        (SettingsManager.LaunchPage.charts, NavigationItem.charts),
        (SettingsManager.LaunchPage.moodsAndGenres, NavigationItem.moodsAndGenres),
        (SettingsManager.LaunchPage.newReleases, NavigationItem.newReleases),
        (SettingsManager.LaunchPage.likedMusic, NavigationItem.likedMusic),
        (SettingsManager.LaunchPage.playlists, NavigationItem.library),
    ])
    func launchPageNavigationItem(page: SettingsManager.LaunchPage, expected: NavigationItem) {
        #expect(page.navigationItem == expected)
    }

    @Test("Launch page identifiable")
    func launchPageIdentifiable() {
        let page = SettingsManager.LaunchPage.home
        #expect(page.id == page.rawValue)
    }

    @Test("All launch pages are iterable")
    func allLaunchPagesIterable() {
        let allPages = SettingsManager.LaunchPage.allCases
        #expect(allPages.count == 8)
    }

    @Test("Last used fallback to home in navigation item")
    func lastUsedFallback() {
        let page = SettingsManager.LaunchPage.lastUsed
        // lastUsed defaults to .home as its navigationItem
        #expect(page.navigationItem == .home)
    }

    // MARK: - SettingsManager Shared Instance

    @Test("Shared instance exists")
    func sharedInstance() {
        let manager = SettingsManager.shared
        #expect(manager != nil)
    }

    @Test("Shared instance is singleton")
    func singletonInstance() {
        let manager1 = SettingsManager.shared
        let manager2 = SettingsManager.shared
        #expect(manager1 === manager2)
    }

    // MARK: - Settings Properties

    @Test("Default launch page has reasonable default")
    func defaultLaunchPage() {
        let manager = SettingsManager.shared
        // The default should be a valid LaunchPage (home by default)
        #expect(SettingsManager.LaunchPage.allCases.contains(manager.defaultLaunchPage))
    }

    @Test("Launch page computed property respects lastUsed")
    func launchPageComputedProperty() {
        let manager = SettingsManager.shared

        // When not using lastUsed, launchPage returns defaultLaunchPage
        let originalDefault = manager.defaultLaunchPage
        if originalDefault != .lastUsed {
            #expect(manager.launchPage == originalDefault)
        }
    }

    @Test("Launch navigation item returns navigation item for launch page")
    func launchNavigationItem() {
        let manager = SettingsManager.shared
        let navItem = manager.launchNavigationItem
        // Should be a valid NavigationItem
        #expect(navItem != nil)
    }

    @Test("Last used page can be set")
    func lastUsedPageSetting() {
        let manager = SettingsManager.shared
        manager.lastUsedPage = .charts
        #expect(manager.lastUsedPage == .charts)
        // Reset
        manager.lastUsedPage = .home
    }
}
