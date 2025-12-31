import AVKit
import SwiftUI

// MARK: - PlayerBar

/// Player bar shown at the bottom of the content area, styled like Apple Music with Liquid Glass.
@available(macOS 26.0, *)
struct PlayerBar: View {
    @Environment(PlayerService.self) private var playerService
    @Environment(WebKitManager.self) private var webKitManager

    /// Callback when user wants to navigate to an album
    var onNavigateToAlbum: ((Album) -> Void)?

    /// Callback when user wants to navigate to an artist
    var onNavigateToArtist: ((Artist) -> Void)?

    /// Namespace for glass effect morphing and unioning.
    @Namespace private var playerNamespace

    /// Local volume value for smooth slider dragging.
    @State private var volumeValue: Double = 1.0
    @State private var isAdjustingVolume = false

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Left section: Track info (album art + title/artist)
                    self.trackInfoSection

                    Spacer()

                    // Center section: Playback controls
                    self.playbackControls

                    Spacer()

                    // Right section: Actions + Volume + Menu
                    self.rightSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)

                // Progress bar at bottom
                if self.playerService.currentTrack != nil {
                    self.progressBar
                        .padding(.horizontal, 20)
                        .padding(.bottom, 6)
                }
            }
            .frame(height: 52)
            .glassEffect(.regular.interactive(), in: .capsule)
            .glassEffectID("playerBar", in: self.playerNamespace)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background {
            // Keyboard shortcuts for media controls
            Group {
                // Space: Play/Pause
                Button("") {
                    Task { await self.playerService.playPause() }
                }
                .keyboardShortcut(.space, modifiers: [])
                .opacity(0)

                // Command + Right Arrow: Next track
                Button("") {
                    Task { await self.playerService.next() }
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .opacity(0)

                // Command + Left Arrow: Previous track
                Button("") {
                    Task { await self.playerService.previous() }
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .opacity(0)

                // Command + Up Arrow: Volume up
                Button("") {
                    Task { await self.playerService.setVolume(min(1.0, self.playerService.volume + 0.1)) }
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .opacity(0)

                // Command + Down Arrow: Volume down
                Button("") {
                    Task { await self.playerService.setVolume(max(0.0, self.playerService.volume - 0.1)) }
                }
                .keyboardShortcut(.downArrow, modifiers: .command)
                .opacity(0)

                // Command + M: Toggle mute
                Button("") {
                    Task { await self.playerService.toggleMute() }
                }
                .keyboardShortcut("m", modifiers: .command)
                .opacity(0)

                // F: Open full-screen player
                Button("") {
                    if self.playerService.currentTrack != nil {
                        HapticService.navigation()
                        self.playerService.showFullScreenPlayer = true
                    }
                }
                .keyboardShortcut("f", modifiers: [])
                .opacity(0)

                // Command + Shift + F: Open full-screen player (alternative)
                Button("") {
                    if self.playerService.currentTrack != nil {
                        HapticService.navigation()
                        self.playerService.showFullScreenPlayer = true
                    }
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .opacity(0)
            }
        }
        .onChange(of: self.playerService.volume) { _, newValue in
            // Sync local volume value when not actively adjusting
            if !self.isAdjustingVolume {
                self.volumeValue = newValue
            }
        }
        .onAppear {
            // Sync local volume value from saved state on initial load
            self.volumeValue = self.playerService.volume
        }
    }

    // MARK: - Left Section (Track Info: Album art + Title/Artist)

    private var trackInfoSection: some View {
        HStack(spacing: 10) {
            // Thumbnail - tappable to go to album
            if let track = playerService.currentTrack {
                CachedAsyncImage(url: track.thumbnailURL?.highQualityThumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .overlay {
                            CassetteIcon(size: 20)
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .contentShape(Rectangle())
                .onTapGesture {
                    if let album = track.album {
                        self.onNavigateToAlbum?(album)
                    }
                }
                .accessibilityLabel("Album artwork")
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .overlay {
                        CassetteIcon(size: 20)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 36, height: 36)
            }

            // Track title and artist
            if let track = playerService.currentTrack {
                VStack(alignment: .leading, spacing: 1) {
                    // Title - tappable to go to album
                    Text(track.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let album = track.album {
                                self.onNavigateToAlbum?(album)
                            }
                        }

                    // Artist - tappable to go to artist page
                    Text(track.artistsDisplay.isEmpty ? "Unknown Artist" : track.artistsDisplay)
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let artist = track.artists.first, artist.id.hasPrefix("UC") {
                                self.onNavigateToArtist?(artist)
                            }
                        }
                }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Not Playing")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    Text("—")
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Right Section (Actions + Volume + Menu)

    private var rightSection: some View {
        HStack(spacing: 10) {
            // Like button
            Button {
                HapticService.toggle()
                self.playerService.likeCurrentTrack()
            } label: {
                Image(systemName: self.playerService.currentTrackLikeStatus == .like
                    ? "heart.fill"
                    : "heart")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(self.playerService.currentTrackLikeStatus == .like ? .red : .primary.opacity(0.85))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
            .symbolEffect(.bounce, value: self.playerService.currentTrackLikeStatus == .like)
            .accessibilityLabel("Like")
            .disabled(self.playerService.currentTrack == nil)

            // Queue button
            Button {
                HapticService.toggle()
                withAnimation(AppAnimation.standard) {
                    self.playerService.showQueue.toggle()
                }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(self.playerService.showQueue ? .red : .primary.opacity(0.85))
            }
            .buttonStyle(.pressable)
            .glassEffectID("queue", in: self.playerNamespace)
            .accessibilityIdentifier(AccessibilityID.PlayerBar.queueButton)
            .accessibilityLabel("Queue")

            // Volume
            HStack(spacing: 4) {
                Image(systemName: self.volumeIcon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.7))
                    .frame(width: 14)

                Slider(value: self.$volumeValue, in: 0 ... 1) { editing in
                    if editing {
                        self.isAdjustingVolume = true
                    } else {
                        self.isAdjustingVolume = false
                        Task {
                            await self.playerService.setVolume(self.volumeValue)
                        }
                    }
                }
                .frame(width: 70)
                .controlSize(.mini)
                .onChange(of: self.volumeValue) { oldValue, newValue in
                    if self.isAdjustingVolume {
                        if (oldValue > 0 && newValue == 0) || (oldValue < 1 && newValue == 1) {
                            HapticService.sliderBoundary()
                        }
                        Task {
                            await self.playerService.setVolume(newValue)
                        }
                    }
                }
            }

            // Fullscreen button
            Button {
                HapticService.navigation()
                self.playerService.showFullScreenPlayer = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.85))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Full screen player")
            .disabled(self.playerService.currentTrack == nil)

            // Ellipsis menu
            if self.playerService.currentTrack != nil {
                self.trackMenu
            }
        }
    }

    // MARK: - Track Menu (ellipsis button)

    private var trackMenu: some View {
        Menu {
            // Go to Album
            if let album = playerService.currentTrack?.album {
                Button {
                    self.onNavigateToAlbum?(album)
                } label: {
                    Label("Go to Album", systemImage: "square.stack")
                }
            }

            // Go to Artist
            if let artist = playerService.currentTrack?.artists.first {
                Button {
                    if artist.id.hasPrefix("UC") {
                        self.onNavigateToArtist?(artist)
                    }
                } label: {
                    Label("Go to Artist", systemImage: "person")
                }
                .disabled(!artist.id.hasPrefix("UC"))
            }

            Divider()

            // Show Queue
            Button {
                HapticService.toggle()
                withAnimation(AppAnimation.standard) {
                    self.playerService.showQueue.toggle()
                }
            } label: {
                Label(self.playerService.showQueue ? "Hide Queue" : "Show Queue", systemImage: "list.bullet")
            }

            Divider()

            // Share
            if let track = playerService.currentTrack {
                ShareLink(item: URL(string: "https://music.youtube.com/watch?v=\(track.videoId)")!) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 20)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(height: 2)

                // Progress fill
                Capsule()
                    .fill(.white.opacity(0.6))
                    .frame(width: max(0, geometry.size.width * self.progressPercent), height: 2)
            }
        }
        .frame(height: 2)
    }

    private var progressPercent: CGFloat {
        guard self.playerService.duration > 0 else { return 0 }
        return CGFloat(max(0, min(1, self.playerService.progress / self.playerService.duration)))
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 16) {
            // Shuffle
            Button {
                HapticService.toggle()
                self.playerService.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(self.playerService.shuffleEnabled ? .red : .primary.opacity(0.85))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Shuffle")
            .accessibilityValue(self.playerService.shuffleEnabled ? "On" : "Off")

            // Previous
            Button {
                HapticService.playback()
                Task {
                    await self.playerService.previous()
                }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Previous track")

            // Play/Pause
            Button {
                HapticService.playback()
                Task {
                    await self.playerService.playPause()
                }
            } label: {
                Image(systemName: self.playerService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.primary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
            .glassEffectID("playPause", in: self.playerNamespace)
            .accessibilityLabel(self.playerService.isPlaying ? "Pause" : "Play")

            // Next
            Button {
                HapticService.playback()
                Task {
                    await self.playerService.next()
                }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Next track")

            // Repeat
            Button {
                HapticService.toggle()
                self.playerService.cycleRepeatMode()
            } label: {
                Image(systemName: self.repeatIcon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(self.playerService.repeatMode != .off ? .red : .primary.opacity(0.85))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Repeat")
            .accessibilityValue(self.repeatAccessibilityValue)
        }
    }

    private var repeatIcon: String {
        switch self.playerService.repeatMode {
        case .off, .all:
            "repeat"
        case .one:
            "repeat.1"
        }
    }

    private var repeatAccessibilityValue: String {
        switch self.playerService.repeatMode {
        case .off:
            "Off"
        case .all:
            "All"
        case .one:
            "One"
        }
    }

    private var volumeIcon: String {
        let currentVolume = self.isAdjustingVolume ? self.volumeValue : self.playerService.volume
        if currentVolume == 0 {
            return "speaker.slash.fill"
        } else if currentVolume < 0.5 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.2.fill"
        }
    }
}

// MARK: - AirPlayButton

/// A SwiftUI wrapper for AVRoutePickerView to show AirPlay destinations.
@available(macOS 26.0, *)
struct AirPlayButton: NSViewRepresentable {
    func makeNSView(context _: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.isRoutePickerButtonBordered = false
        return routePickerView
    }

    func updateNSView(_: AVRoutePickerView, context _: Context) {
        // No updates needed
    }
}

@available(macOS 26.0, *)
#Preview {
    PlayerBar()
        .environment(PlayerService())
        .environment(WebKitManager.shared)
        .frame(width: 600)
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
}
