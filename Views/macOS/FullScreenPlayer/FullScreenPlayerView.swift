import SwiftUI

// MARK: - FullScreenPlayerView

/// Full-screen immersive player view inspired by Apple Music's "Now Playing" experience.
/// Two-column layout: left side shows artwork and controls, right side shows synced lyrics.
/// Controls are always visible. Lyrics auto-scroll following playback progress.
@available(macOS 26.0, *)
struct FullScreenPlayerView: View {
    @Environment(PlayerService.self) private var playerService
    @Environment(\.dismiss) private var dismiss

    let client: any YTMusicClientProtocol

    /// Callback when user wants to navigate to an artist
    var onNavigateToArtist: ((Artist) -> Void)?

    /// Callback when user wants to navigate to an album
    var onNavigateToAlbum: ((Album) -> Void)?

    // MARK: - State

    @State private var lyrics: Lyrics?
    @State private var isLoadingLyrics = false

    /// Current active lyric line index.
    @State private var currentLineIndex: Int = 0

    /// Pre-measured heights for each lyric line to prevent reflow during animation.
    /// Keyed by line index, calculated once when lyrics load.
    @State private var lyricLineHeights: [Int: CGFloat] = [:]

    /// Width used for measuring lyric line heights.
    @State private var lyricsColumnWidth: CGFloat = 400

    /// Local seek value for smooth slider dragging.
    @State private var seekValue: Double = 0
    @State private var isSeeking = false

    /// Local volume value for smooth slider dragging.
    @State private var volumeValue: Double = 1.0
    @State private var isAdjustingVolume = false

    /// Drag gesture offset for swipe-to-dismiss.
    @State private var dragOffset: CGSize = .zero

    /// Namespace for matched geometry transitions.
    @Namespace private var playerNamespace

    private let logger = DiagnosticsLogger.ui

    /// Threshold for compact layout (single column).
    private var isCompactWidth: Bool {
        // Use single column layout for windows narrower than 900pt
        false // Will be set based on geometry
    }

    var body: some View {
        GeometryReader { geometry in
            let isMiniPlayer = geometry.size.width < 500 || geometry.size.height < 400
            let isCompact = geometry.size.width < 900

            ZStack(alignment: .topLeading) {
                // Animated liquid glass background
                AnimatedBackgroundView(imageURL: self.playerService.currentTrack?.thumbnailURL?.highQualityThumbnailURL)
                    .ignoresSafeArea()

                // Responsive layout based on window size
                if isMiniPlayer {
                    // Mini player for very small windows
                    self.miniPlayerLayout(geometry: geometry)
                } else if isCompact {
                    // Single column layout for smaller windows
                    ScrollView {
                        self.compactLayout(geometry: geometry)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    // Two-column layout for larger windows
                    HStack(spacing: 0) {
                        // Left column: Artwork + Track Info + Controls
                        self.leftColumn(geometry: geometry)
                            .frame(width: geometry.size.width * 0.4) // Reduced from 0.45

                        // Right column: Synced Lyrics with gradient fade
                        self.lyricsColumn(geometry: geometry)
                            .frame(width: geometry.size.width * 0.6) // Increased from 0.55
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                // Close button in top-left corner
                HStack {
                    Button {
                        HapticService.navigation()
                        self.closeFullScreenPlayer()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")

                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.top, 8)
            }
            .offset(self.dragOffset)
        }
        .background(.black)
        .gesture(self.dismissGesture)
        .onChange(of: self.playerService.progress) { _, newProgress in
            if !self.isSeeking, self.playerService.duration > 0 {
                self.seekValue = newProgress / self.playerService.duration
                self.updateCurrentLyricLine(progress: newProgress)
            }
        }
        .onChange(of: self.playerService.volume) { _, newValue in
            if !self.isAdjustingVolume {
                self.volumeValue = newValue
            }
        }
        .onChange(of: self.playerService.currentTrack?.title) { oldTitle, newTitle in
            // Detect track change by title (more reliable than videoId for YouTube autoplay)
            if oldTitle != newTitle, let track = self.playerService.currentTrack {
                self.logger.info("Track title changed, reloading lyrics for: \(track.title)")
                self.reloadLyricsForNewTrack(track)
            }
        }
        .onChange(of: self.playerService.currentTrack?.videoId) { oldVideoId, newVideoId in
            // Also detect track change by videoId (for media key next/previous)
            if oldVideoId != newVideoId, let track = self.playerService.currentTrack {
                self.logger.info("Track videoId changed, reloading lyrics for: \(track.videoId)")
                self.reloadLyricsForNewTrack(track)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: self.playerService.currentTrack?.videoId)
        .task {
            self.volumeValue = self.playerService.volume
            if let videoId = playerService.currentTrack?.videoId {
                await self.loadLyrics(for: videoId)
            }
        }
        .background { self.keyboardShortcuts }
    }

    /// Reloads lyrics for a new track, resetting state.
    private func reloadLyricsForNewTrack(_ track: Song) {
        // Reset state for new track
        self.currentLineIndex = 0
        self.seekValue = 0
        self.lyricLineHeights = [:] // Clear cached heights for new lyrics
        self.isLoadingLyrics = true
        self.lyrics = nil
        
        // Clear the PlayerService cache to force a fresh fetch
        self.playerService.clearLyricsCache()
        
        // Load lyrics using track title as identifier when videoId might be stale
        Task { await self.loadLyricsForTrack(track) }
    }

    // MARK: - Mini Player Layout (for very small windows)

    private func miniPlayerLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            Spacer()

            // Compact artwork
            FullScreenArtworkView(
                imageURL: self.playerService.currentTrack?.thumbnailURL?.highQualityThumbnailURL,
                namespace: self.playerNamespace,
                onTap: {
                    if let album = self.playerService.currentTrack?.album {
                        self.navigateToAlbum(album)
                    }
                }
            )
            .frame(
                width: min(geometry.size.width * 0.5, 160),
                height: min(geometry.size.width * 0.5, 160)
            )

            // Track info (simplified)
            VStack(spacing: 4) {
                Text(self.playerService.currentTrack?.title ?? "Not Playing")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let track = playerService.currentTrack, !track.artistsDisplay.isEmpty {
                    Text(track.artistsDisplay)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 20)

            // Minimal progress bar
            Slider(value: self.$seekValue, in: 0 ... 1) { editing in
                if editing {
                    self.isSeeking = true
                } else {
                    self.performSeek()
                }
            }
            .tint(.white)
            .controlSize(.small)
            .padding(.horizontal, 24)

            // Compact playback controls
            HStack(spacing: 24) {
                Button {
                    HapticService.playback()
                    Task { await self.playerService.previous() }
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.pressable)

                Button {
                    HapticService.playback()
                    Task { await self.playerService.playPause() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 48, height: 48)

                        Image(systemName: self.playerService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .buttonStyle(.pressable)

                Button {
                    HapticService.playback()
                    Task { await self.playerService.next() }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.pressable)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Compact Layout (Single Column for smaller windows)

    private func compactLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 64)

            // Album artwork
            FullScreenArtworkView(
                imageURL: self.playerService.currentTrack?.thumbnailURL?.highQualityThumbnailURL,
                namespace: self.playerNamespace,
                onTap: {
                    if let album = self.playerService.currentTrack?.album {
                        self.navigateToAlbum(album)
                    }
                }
            )
            .frame(
                width: min(geometry.size.width * 0.55, 320),
                height: min(geometry.size.width * 0.55, 320)
            )

            Spacer()
                .frame(height: 28)

            // Track info with actions
            self.trackInfoWithActions
                .frame(maxWidth: min(geometry.size.width * 0.8, 400))
                .padding(.horizontal, 24)

            Spacer()
                .frame(height: 24)

            // Progress bar
            self.progressSection
                .frame(maxWidth: min(geometry.size.width * 0.85, 400))
                .padding(.horizontal, 24)

            Spacer()
                .frame(height: 32)

            // Playback controls
            self.playbackControls
                .frame(maxWidth: min(geometry.size.width * 0.85, 400))

            Spacer()
                .frame(height: 24)

            // Volume control
            self.volumeControl
                .frame(maxWidth: min(geometry.size.width * 0.85, 400))
                .padding(.horizontal, 24)

            Spacer()
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Left Column (Artwork + Controls)

    private func leftColumn(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // Album artwork with breathing animation
            FullScreenArtworkView(
                imageURL: self.playerService.currentTrack?.thumbnailURL?.highQualityThumbnailURL,
                namespace: self.playerNamespace,
                onTap: {
                    if let album = self.playerService.currentTrack?.album {
                        self.navigateToAlbum(album)
                    }
                }
            )
            .frame(
                width: min(geometry.size.width * 0.28, 320),
                height: min(geometry.size.width * 0.28, 320)
            )

            Spacer()
                .frame(height: 32)

            // Track info with action buttons on the right
            self.trackInfoWithActions
                .frame(maxWidth: min(geometry.size.width * 0.35, 380))

            Spacer()
                .frame(height: 24)

            // Progress bar
            self.progressSection
                .frame(maxWidth: min(geometry.size.width * 0.35, 380))

            Spacer()
                .frame(height: 32)

            // Playback controls
            self.playbackControls
                .frame(maxWidth: min(geometry.size.width * 0.38, 420))

            Spacer()
                .frame(height: 24)

            // Volume control (full width)
            self.volumeControl
                .frame(maxWidth: min(geometry.size.width * 0.35, 380))

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Lyrics Column with Apple Music-style fade

    private func lyricsColumn(geometry: GeometryProxy) -> some View {
        ZStack {
            if self.isLoadingLyrics {
                self.loadingLyricsView
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else if let lyrics, lyrics.isAvailable {
                self.syncedLyricsView(lyrics: lyrics, height: geometry.size.height)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else {
                self.noLyricsView
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: self.isLoadingLyrics)
        .animation(.easeInOut(duration: 0.3), value: self.lyrics?.isAvailable)
    }

    // MARK: - Synced Lyrics View with Gradient Mask

    private func syncedLyricsView(lyrics: Lyrics, height: CGFloat) -> some View {
        // Use timed lines if available, otherwise fall back to plain lines
        let timedLines = lyrics.timedLines ?? []
        let hasTimedLyrics = !timedLines.isEmpty

        let displayLines: [(index: Int, text: String, startTime: TimeInterval?)] = if hasTimedLyrics {
            timedLines.map { (index: $0.id, text: $0.text, startTime: $0.startTime as TimeInterval?) }
        } else {
            lyrics.lines.enumerated().map { (index: $0.offset, text: $0.element, startTime: nil as TimeInterval?) }
        }

        return GeometryReader { geo in
            // Calculate available width with padding
            // Horizontal padding: 32 (leading) + 32 (trailing) = 64
            let columnWidth = geo.size.width - 64

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Top spacer - pushes first line to center area
                        Spacer()
                            .frame(height: height * 0.4)

                        ForEach(displayLines, id: \.index) { lineData in
                            LyricLineView(
                                text: lineData.text,
                                isActive: lineData.index == self.currentLineIndex,
                                distance: abs(lineData.index - self.currentLineIndex),
                                measuredHeight: self.lyricLineHeights[lineData.index]
                                    ?? LyricLineView.measureHeight(for: lineData.text, width: columnWidth, fontSize: LyricLineView.fontSize(for: columnWidth)),
                                containerWidth: columnWidth,
                                onTap: hasTimedLyrics && lineData.startTime != nil ? {
                                    HapticService.navigation()
                                    self.currentLineIndex = lineData.index
                                    Task {
                                        await self.playerService.seek(to: lineData.startTime!)
                                    }
                                } : nil
                            )
                            .id(lineData.index)
                        }

                        // Source attribution
                        if let source = lyrics.source {
                            HStack {
                                if lyrics.hasTimedLyrics {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 10))
                                }
                                Text(source)
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.top, 48)
                        }

                        // Bottom spacer
                        Spacer()
                            .frame(height: height * 0.45)
                    }
                    .padding(.horizontal, 32) // Consistent padding on both sides
                }
                .scrollContentBackground(.hidden)
                .mask(self.lyricsFadeMask(height: height))
                .onChange(of: self.currentLineIndex) { oldIndex, newIndex in
                    // Calculate scroll direction for natural motion
                    let direction = newIndex > oldIndex ? 1.0 : -1.0
                    let distance = abs(newIndex - oldIndex)

                    // Bouncier spring for scrolling
                    // response: 0.55s = slightly faster tempo
                    // dampingFraction: 0.6 = more bounce/overshoot (lower = more bounce)
                    // blendDuration: 0.5s = smooth blending
                    let scrollSpring: Animation = .spring(
                        response: 0.55,
                        dampingFraction: 0.6,
                        blendDuration: 0.5
                    )

                    withAnimation(scrollSpring) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            .onAppear {
                // Pre-measure all lyrics when view appears
                self.measureLyricHeights(displayLines: displayLines, width: columnWidth)
            }
            .onChange(of: geo.size.width) { _, newWidth in
                // Re-measure if width changes significantly
                let adjustedWidth = newWidth - 64
                if abs(adjustedWidth - self.lyricsColumnWidth) > 50 {
                    self.lyricsColumnWidth = adjustedWidth
                    self.measureLyricHeights(displayLines: displayLines, width: adjustedWidth)
                }
            }
        }
    }

    /// Pre-measure all lyric line heights to prevent reflow during animation.
    private func measureLyricHeights(
        displayLines: [(index: Int, text: String, startTime: TimeInterval?)],
        width: CGFloat
    ) {
        let fontSize = LyricLineView.fontSize(for: width)
        var heights: [Int: CGFloat] = [:]
        for line in displayLines {
            heights[line.index] = LyricLineView.measureHeight(for: line.text, width: width, fontSize: fontSize)
        }
        self.lyricLineHeights = heights
        self.lyricsColumnWidth = width
    }

    /// Gradient mask for lyrics: materializes in center, fades at edges.
    private func lyricsFadeMask(height: CGFloat) -> some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 0.08),
                .init(color: .white, location: 0.25),
                .init(color: .white, location: 0.75),
                .init(color: .clear, location: 0.92),
                .init(color: .clear, location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Update current lyric line based on playback progress.
    private func updateCurrentLyricLine(progress: TimeInterval) {
        guard let lyrics, lyrics.isAvailable else { return }

        // Use timed lyrics if available
        if let timedLines = lyrics.timedLines, !timedLines.isEmpty {
            // Find the current line based on timestamp
            var newIndex = 0
            for (index, line) in timedLines.enumerated() {
                if line.startTime <= progress {
                    newIndex = index
                } else {
                    break
                }
            }

            if newIndex != self.currentLineIndex {
                self.currentLineIndex = newIndex
            }
            return
        }

        // Fall back to estimation for untimed lyrics
        let lines = lyrics.lines
        guard !lines.isEmpty else { return }

        let duration = self.playerService.duration
        guard duration > 0 else { return }

        let progressPercentage = progress / duration
        let estimatedLine = Int(progressPercentage * Double(lines.count))
        let clampedLine = max(0, min(lines.count - 1, estimatedLine))

        if clampedLine != self.currentLineIndex {
            self.currentLineIndex = clampedLine
        }
    }

    private var loadingLyricsView: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(.white)
            Text("Loading lyrics...")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
        }
    }

    private var noLyricsView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "text.quote")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.2))
            Text("No lyrics available")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
            Text("Lyrics aren't available for this song")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white.opacity(0.3))
            Spacer()
        }
    }

    // MARK: - Track Info with Action Buttons

    private var trackInfoWithActions: some View {
        HStack(alignment: .center, spacing: 16) {
            // Track info (left-aligned)
            VStack(alignment: .leading, spacing: 4) {
                Text(self.playerService.currentTrack?.title ?? "Not Playing")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                // Artist name - tappable if valid artist ID
                if let track = playerService.currentTrack, !track.artistsDisplay.isEmpty {
                    if let artist = track.artists.first, artist.id.hasPrefix("UC") {
                        Button {
                            self.navigateToArtist(artist)
                        } label: {
                            Text(track.artistsDisplay)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                                .underline(pattern: .solid, color: .white.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(track.artistsDisplay)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Action buttons (right side)
            HStack(spacing: 16) {
                // Like button
                Button {
                    HapticService.toggle()
                    self.playerService.likeCurrentTrack()
                } label: {
                    Image(systemName: self.playerService.currentTrackLikeStatus == .like
                        ? "star.fill" : "star")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(self.playerService.currentTrackLikeStatus == .like ? .yellow : .white.opacity(0.7))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.pressable)
                .symbolEffect(.bounce, value: self.playerService.currentTrackLikeStatus == .like)
                .disabled(self.playerService.currentTrack == nil)

                // More menu
                Menu {
                    // Show Album
                    if let album = playerService.currentTrack?.album {
                        Button {
                            self.navigateToAlbum(album)
                        } label: {
                            Label("Go to Album", systemImage: "square.stack")
                        }
                    }

                    // Show Artist
                    if let artist = playerService.currentTrack?.artists.first {
                        Button {
                            if artist.id.hasPrefix("UC") {
                                self.navigateToArtist(artist)
                            }
                        } label: {
                            Label("Go to Artist", systemImage: "person")
                        }
                        .disabled(!artist.id.hasPrefix("UC"))
                    }

                    Divider()

                    ShareLink(item: self.shareURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 32)
            }
        }
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: self.playerService.currentTrack?.videoId)
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 10) {
            Slider(value: self.$seekValue, in: 0 ... 1) { editing in
                if editing {
                    self.isSeeking = true
                } else {
                    self.performSeek()
                }
            }
            .tint(.white)
            .controlSize(.regular)

            HStack {
                Text(self.formatTime(self.isSeeking ? self.seekValue * self.playerService.duration : self.playerService.progress))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()

                Text("-\(self.formatTime(self.playerService.duration - (self.isSeeking ? self.seekValue * self.playerService.duration : self.playerService.progress)))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 32) {
            // Shuffle
            Button {
                HapticService.toggle()
                self.playerService.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(self.playerService.shuffleEnabled ? .white : .white.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Shuffle")

            // Previous
            Button {
                HapticService.playback()
                Task { await self.playerService.previous() }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Previous")

            // Play/Pause - prominent white circle
            Button {
                HapticService.playback()
                Task { await self.playerService.playPause() }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 64, height: 64)

                    Image(systemName: self.playerService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.black)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.pressable)
            .matchedGeometryEffect(id: "playPause", in: self.playerNamespace)
            .accessibilityLabel(self.playerService.isPlaying ? "Pause" : "Play")

            // Next
            Button {
                HapticService.playback()
                Task { await self.playerService.next() }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Next")

            // Repeat
            Button {
                HapticService.toggle()
                self.playerService.cycleRepeatMode()
            } label: {
                Image(systemName: self.repeatIcon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(self.playerService.repeatMode != .off ? .white : .white.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Repeat")
        }
    }

    // MARK: - Volume Control

    private var volumeControl: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.wave.1.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            Slider(value: self.$volumeValue, in: 0 ... 1) { editing in
                if editing {
                    self.isAdjustingVolume = true
                } else {
                    self.isAdjustingVolume = false
                    Task { await self.playerService.setVolume(self.volumeValue) }
                }
            }
            .tint(.white)
            .controlSize(.small)
            .onChange(of: self.volumeValue) { oldValue, newValue in
                if self.isAdjustingVolume {
                    if (oldValue > 0 && newValue == 0) || (oldValue < 1 && newValue == 1) {
                        HapticService.sliderBoundary()
                    }
                    Task { await self.playerService.setVolume(newValue) }
                }
            }

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Keyboard Shortcuts

    private var keyboardShortcuts: some View {
        Group {
            // Escape: Close
            Button("") { self.closeFullScreenPlayer() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)

            // Space: Play/Pause
            Button("") {
                HapticService.playback()
                Task { await self.playerService.playPause() }
            }
            .keyboardShortcut(.space, modifiers: [])
            .opacity(0)

            // Command + Right: Next
            Button("") {
                HapticService.playback()
                Task { await self.playerService.next() }
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .opacity(0)

            // Command + Left: Previous
            Button("") {
                HapticService.playback()
                Task { await self.playerService.previous() }
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .opacity(0)

            // Command + Up: Volume up
            Button("") {
                Task { await self.playerService.setVolume(min(1.0, self.playerService.volume + 0.1)) }
            }
            .keyboardShortcut(.upArrow, modifiers: .command)
            .opacity(0)

            // Command + Down: Volume down
            Button("") {
                Task { await self.playerService.setVolume(max(0.0, self.playerService.volume - 0.1)) }
            }
            .keyboardShortcut(.downArrow, modifiers: .command)
            .opacity(0)
        }
    }

    // MARK: - Gestures

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onChanged { value in
                if value.translation.height > 0 {
                    self.dragOffset = CGSize(width: 0, height: value.translation.height * 0.4)
                }
            }
            .onEnded { value in
                if value.translation.height > 150 {
                    self.closeFullScreenPlayer()
                } else if value.translation.width < -100 {
                    HapticService.playback()
                    Task { await self.playerService.next() }
                } else if value.translation.width > 100 {
                    HapticService.playback()
                    Task { await self.playerService.previous() }
                }

                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    self.dragOffset = .zero
                }
            }
    }

    // MARK: - Helpers

    private func closeFullScreenPlayer() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            self.playerService.showFullScreenPlayer = false
        }
    }

    private func navigateToArtist(_ artist: Artist) {
        self.closeFullScreenPlayer()
        // Small delay to let the animation complete
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            self.onNavigateToArtist?(artist)
        }
    }

    private func navigateToAlbum(_ album: Album) {
        self.closeFullScreenPlayer()
        // Small delay to let the animation complete
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            self.onNavigateToAlbum?(album)
        }
    }

    private var repeatIcon: String {
        switch self.playerService.repeatMode {
        case .off, .all: "repeat"
        case .one: "repeat.1"
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

    private var shareURL: URL {
        if let videoId = playerService.currentTrack?.videoId {
            return URL(string: "https://music.youtube.com/watch?v=\(videoId)")!
        }
        return URL(string: "https://music.youtube.com")!
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func performSeek() {
        guard self.isSeeking else { return }
        let seekTime = self.seekValue * self.playerService.duration
        Task {
            await self.playerService.seek(to: seekTime)
            self.isSeeking = false
        }
    }

    private func loadLyrics(for videoId: String) async {
        // Check cache first
        if let cached = self.playerService.getCachedLyrics(for: videoId) {
            // Verify we're still on the same track before applying
            if self.playerService.currentTrack?.videoId == videoId {
                self.lyrics = cached
                self.isLoadingLyrics = false
                self.logger.info("Using cached lyrics for video: \(videoId)")
            }
            return
        }

        self.isLoadingLyrics = true
        self.currentLineIndex = 0

        // Get track info for LRCLib lookup
        let track = self.playerService.currentTrack
        let artistName = track?.artistsDisplay ?? ""
        let trackName = track?.title ?? ""
        let duration = self.playerService.duration > 0 ? self.playerService.duration : nil

        // Try LRCLib first for timed/synced lyrics
        if !artistName.isEmpty, !trackName.isEmpty {
            if let lrcLyrics = await LRCLibService.fetchLyrics(
                artist: artistName,
                track: trackName,
                duration: duration
            ) {
                // Verify we're still on the same track before applying
                if self.playerService.currentTrack?.videoId == videoId {
                    self.lyrics = lrcLyrics
                    self.playerService.cacheLyrics(lrcLyrics, for: videoId)
                    self.logger.info("Loaded timed lyrics from LRCLib for: \(trackName)")
                    self.isLoadingLyrics = false
                }
                return
            }
        }

        // Fall back to YouTube Music lyrics (plain text)
        do {
            let fetchedLyrics = try await client.getLyrics(videoId: videoId)
            // Verify we're still on the same track before applying
            if self.playerService.currentTrack?.videoId == videoId {
                self.lyrics = fetchedLyrics
                self.playerService.cacheLyrics(fetchedLyrics, for: videoId)
                self.logger.info("Loaded lyrics from YouTube Music for video: \(videoId)")
            }
        } catch {
            // Only log error if we're still on the same track
            if self.playerService.currentTrack?.videoId == videoId {
                self.logger.debug("Failed to load lyrics: \(error.localizedDescription)")
                self.lyrics = nil
            }
        }

        if self.playerService.currentTrack?.videoId == videoId {
            self.isLoadingLyrics = false
        }
    }

    /// Loads lyrics for a track, using title for verification instead of videoId.
    /// This is more reliable when tracks change via media keys where videoId may be stale.
    private func loadLyricsForTrack(_ track: Song) async {
        let trackTitle = track.title
        let artistName = track.artistsDisplay
        let videoId = track.videoId
        
        self.isLoadingLyrics = true
        self.currentLineIndex = 0
        
        let duration = self.playerService.duration > 0 ? self.playerService.duration : nil

        // Try LRCLib first for timed/synced lyrics
        if !artistName.isEmpty, !trackTitle.isEmpty, trackTitle != "Loading..." {
            if let lrcLyrics = await LRCLibService.fetchLyrics(
                artist: artistName,
                track: trackTitle,
                duration: duration
            ) {
                // Verify we're still on the same track by title (more reliable than videoId)
                if self.playerService.currentTrack?.title == trackTitle {
                    self.lyrics = lrcLyrics
                    self.playerService.cacheLyrics(lrcLyrics, for: videoId)
                    self.logger.info("Loaded timed lyrics from LRCLib for: \(trackTitle)")
                    self.isLoadingLyrics = false
                }
                return
            }
        }

        // Fall back to YouTube Music lyrics (plain text)
        // Only try if we have a valid videoId (not "unknown")
        if videoId != "unknown" {
            do {
                let fetchedLyrics = try await client.getLyrics(videoId: videoId)
                // Verify we're still on the same track by title
                if self.playerService.currentTrack?.title == trackTitle {
                    self.lyrics = fetchedLyrics
                    self.playerService.cacheLyrics(fetchedLyrics, for: videoId)
                    self.logger.info("Loaded lyrics from YouTube Music for: \(trackTitle)")
                }
            } catch {
                // Only log error if we're still on the same track
                if self.playerService.currentTrack?.title == trackTitle {
                    self.logger.debug("Failed to load lyrics: \(error.localizedDescription)")
                    self.lyrics = nil
                }
            }
        } else {
            // No valid videoId, just mark as no lyrics if LRCLib didn't find any
            if self.playerService.currentTrack?.title == trackTitle {
                self.lyrics = nil
            }
        }

        if self.playerService.currentTrack?.title == trackTitle {
            self.isLoadingLyrics = false
        }
    }
}

// MARK: - LyricLineView

/// Individual lyric line with smooth animation that prevents text reflow.
/// Uses pre-measured height to lock layout and animates only visual properties.
@available(macOS 26.0, *)
private struct LyricLineView: View {
    let text: String
    let isActive: Bool
    let distance: Int
    let measuredHeight: CGFloat
    let containerWidth: CGFloat
    var onTap: (() -> Void)?

    /// Scale for active vs inactive lines
    private static let activeScale: CGFloat = 1.04
    private static let inactiveScale: CGFloat = 1.0

    @State private var isHovering = false

    /// Responsive font size based on container width
    static func fontSize(for width: CGFloat) -> CGFloat {
        switch width {
        case ..<250:
            return 20 // Extra small
        case 250 ..< 350:
            return 24 // Small
        case 350 ..< 450:
            return 28 // Medium-small
        case 450 ..< 550:
            return 32 // Medium
        case 550 ..< 700:
            return 36 // Large
        default:
            return 38 // Extra large (capped to prevent overflow)
        }
    }

    private var currentFontSize: CGFloat {
        Self.fontSize(for: self.containerWidth)
    }

    var body: some View {
        let displayText = text.isEmpty ? "♪" : text
        let isTappable = onTap != nil

        // Calculate opacity based on distance from active line
        let opacity: Double = if isActive {
            1.0
        } else if distance == 1 {
            0.5
        } else if distance == 2 {
            0.3
        } else {
            0.15
        }

        // Scale: active line is larger, inactive lines are normal
        let scale: CGFloat = isActive ? Self.activeScale : Self.inactiveScale

        // Fixed-height container prevents layout shifts during animation.
        // The text is measured once at load time and this height is locked.
        Text(displayText)
            .font(.system(size: self.currentFontSize, weight: .semibold, design: .default))
            .foregroundStyle(.white)
            .opacity(self.isHovering && isTappable ? min(1.0, opacity + 0.2) : opacity)
            .scaleEffect(scale, anchor: .leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: self.measuredHeight, alignment: .topLeading)
            .clipped() // Prevent any overflow during animation
            .background(Color.white.opacity(0.0001)) // Ensures tap area covers full frame
            .contentShape(Rectangle())
            .onHover { hovering in
                self.isHovering = hovering
            }
            .onTapGesture {
                if let onTap {
                    onTap()
                }
            }
            // Matched bouncier spring animation
            .animation(.spring(response: 0.55, dampingFraction: 0.6, blendDuration: 0.5), value: self.isActive)
            .animation(.spring(response: 0.55, dampingFraction: 0.6, blendDuration: 0.5), value: self.distance)
            .animation(.easeOut(duration: 0.2), value: self.isHovering)
            // Animate font size changes smoothly
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: self.currentFontSize)
    }

    /// Pre-measure text height for a given width to prevent reflow during animation.
    /// Call this once when lyrics load to determine each line's locked height.
    static func measureHeight(for text: String, width: CGFloat, fontSize: CGFloat) -> CGFloat {
        let displayText = text.isEmpty ? "♪" : text
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let attributedString = NSAttributedString(
            string: displayText,
            attributes: [.font: font]
        )
        let constraintSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingRect = attributedString.boundingRect(
            with: constraintSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        // Add padding for line spacing and scale effect
        return ceil(boundingRect.height) + 8
    }
}

// MARK: - Preview

@available(macOS 26.0, *)
#Preview {
    FullScreenPlayerView(client: MockUITestYTMusicClient())
        .environment(PlayerService())
        .frame(width: 1200, height: 800)
}
