import SwiftUI

/// Sidebar navigation for the main window, styled like Apple Music.
@available(macOS 26.0, *)
struct Sidebar: View {
    @Binding var selection: NavigationItem?
    @Environment(AuthService.self) private var authService

    /// Namespace for glass effect morphing.
    @Namespace private var sidebarNamespace

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: self.$selection) {
                    // Main navigation
                    Section {
                        NavigationLink(value: NavigationItem.search) {
                            Label("Search", systemImage: "magnifyingglass")
                        }
                        .accessibilityIdentifier(AccessibilityID.Sidebar.searchItem)

                        NavigationLink(value: NavigationItem.home) {
                            Label("Home", systemImage: "house")
                        }
                        .accessibilityIdentifier(AccessibilityID.Sidebar.homeItem)
                    }

                    // Discover section
                    Section("Discover") {
                        NavigationLink(value: NavigationItem.explore) {
                            Label("Explore", systemImage: "globe")
                        }
                        .accessibilityIdentifier(AccessibilityID.Sidebar.exploreItem)

                        NavigationLink(value: NavigationItem.charts) {
                            Label("Charts", systemImage: "chart.line.uptrend.xyaxis")
                        }
                        .accessibilityIdentifier(AccessibilityID.Sidebar.chartsItem)

                        NavigationLink(value: NavigationItem.moodsAndGenres) {
                            Label("Moods & Genres", systemImage: "theatermask.and.paintbrush")
                        }
                        .accessibilityIdentifier(AccessibilityID.Sidebar.moodsAndGenresItem)

                        NavigationLink(value: NavigationItem.newReleases) {
                            Label("New Releases", systemImage: "sparkles")
                        }
                        .accessibilityIdentifier(AccessibilityID.Sidebar.newReleasesItem)
                    }

                    // Library section
                    Section("Library") {
                        NavigationLink(value: NavigationItem.likedMusic) {
                            Label("Liked Music", systemImage: "heart.fill")
                        }
                        .accessibilityIdentifier(AccessibilityID.Sidebar.likedMusicItem)

                        NavigationLink(value: NavigationItem.library) {
                            Label("Playlists", systemImage: "music.note.list")
                        }
                        .accessibilityIdentifier(AccessibilityID.Sidebar.libraryItem)
                    }
                }
                .listStyle(.sidebar)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
                .accessibilityIdentifier(AccessibilityID.Sidebar.container)
                .onChange(of: self.selection) { _, newValue in
                    if newValue != nil {
                        HapticService.navigation()
                    }
                }

                Spacer()

                // Account section at bottom
                if self.authService.state.isLoggedIn {
                    self.accountSection
                }
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 16)

            Menu {
                Button {
                    // Switch account: clear session and show login
                    Task {
                        await self.authService.switchAccount()
                    }
                } label: {
                    Label("Switch Account", systemImage: "arrow.triangle.2.circlepath")
                }

                Divider()

                Button(role: .destructive) {
                    Task {
                        await self.authService.signOut()
                    }
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("YouTube Music")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)

                        Text("Signed In")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
        .padding(.bottom, 8)
    }
}

@available(macOS 26.0, *)
#Preview {
    Sidebar(selection: .constant(.home))
        .environment(AuthService())
        .frame(width: 220)
}
