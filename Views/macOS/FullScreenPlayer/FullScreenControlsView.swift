import AVKit
import SwiftUI

// MARK: - FullScreenControlsView

/// Playback controls for the full-screen player.
/// Includes progress bar, transport controls, volume, and action buttons.
@available(macOS 26.0, *)
struct FullScreenControlsView: View {
    @Environment(PlayerService.self) private var playerService

    @Binding var seekValue: Double
    @Binding var isSeeking: Bool
    @Binding var volumeValue: Double
    @Binding var isAdjustingVolume: Bool
    @Binding var showLyrics: Bool

    var namespace: Namespace.ID

    var body: some View {
        VStack(spacing: 20) {
            // Progress bar
            self.progressSection

            // Transport controls
            self.transportControls

            // Bottom row: Volume, actions, AirPlay
            self.bottomRow
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 8) {
            // Progress slider
            Slider(value: self.$seekValue, in: 0 ... 1) { editing in
                if editing {
                    self.isSeeking = true
                } else {
                    self.performSeek()
                }
            }
            .tint(.white)
            .controlSize(.regular)

            // Time labels
            HStack {
                Text(self.formatTime(self.isSeeking ? self.seekValue * self.playerService.duration : self.playerService.progress))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Text("-\(self.formatTime(self.playerService.duration - (self.isSeeking ? self.seekValue * self.playerService.duration : self.playerService.progress)))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack(spacing: 40) {
            // Shuffle
            Button {
                HapticService.toggle()
                self.playerService.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(self.playerService.shuffleEnabled ? .red : .white.opacity(0.8))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)

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

            // Play/Pause
            Button {
                HapticService.playback()
                Task { await self.playerService.playPause() }
            } label: {
                Image(systemName: self.playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
            .matchedGeometryEffect(id: "playPause", in: self.namespace)

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

            // Repeat
            Button {
                HapticService.toggle()
                self.playerService.cycleRepeatMode()
            } label: {
                Image(systemName: self.repeatIcon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(self.playerService.repeatMode != .off ? .red : .white.opacity(0.8))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
        }
    }

    // MARK: - Bottom Row

    private var bottomRow: some View {
        HStack(spacing: 16) {
            // Volume control
            self.volumeControl

            Spacer()

            // Action buttons
            self.actionButtons

            Spacer()

            // AirPlay
            AirPlayButton()
                .frame(width: 24, height: 24)
        }
    }

    // MARK: - Volume Control

    private var volumeControl: some View {
        HStack(spacing: 8) {
            Image(systemName: self.volumeIcon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 20)

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
            .frame(width: 100)
            .tint(.white)
            .controlSize(.small)
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
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 20) {
            // Dislike
            Button {
                HapticService.toggle()
                self.playerService.dislikeCurrentTrack()
            } label: {
                Image(systemName: self.playerService.currentTrackLikeStatus == .dislike
                    ? "hand.thumbsdown.fill"
                    : "hand.thumbsdown")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(self.playerService.currentTrackLikeStatus == .dislike ? .red : .white.opacity(0.8))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
            .symbolEffect(.bounce, value: self.playerService.currentTrackLikeStatus == .dislike)
            .disabled(self.playerService.currentTrack == nil)

            // Like
            Button {
                HapticService.toggle()
                self.playerService.likeCurrentTrack()
            } label: {
                Image(systemName: self.playerService.currentTrackLikeStatus == .like
                    ? "hand.thumbsup.fill"
                    : "hand.thumbsup")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(self.playerService.currentTrackLikeStatus == .like ? .red : .white.opacity(0.8))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
            .symbolEffect(.bounce, value: self.playerService.currentTrackLikeStatus == .like)
            .disabled(self.playerService.currentTrack == nil)

            // Lyrics toggle
            Button {
                HapticService.toggle()
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.showLyrics.toggle()
                }
            } label: {
                Image(systemName: "quote.bubble")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(self.showLyrics ? .red : .white.opacity(0.8))
            }
            .buttonStyle(.pressable)
            .matchedGeometryEffect(id: "lyrics", in: self.namespace)
            .disabled(self.playerService.currentTrack == nil)

            // Share (placeholder - can be expanded later)
            ShareLink(item: self.shareURL) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.pressable)
            .disabled(self.playerService.currentTrack == nil)
        }
    }

    // MARK: - Helpers

    private var repeatIcon: String {
        switch self.playerService.repeatMode {
        case .off, .all:
            "repeat"
        case .one:
            "repeat.1"
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
}

// MARK: - Preview

@available(macOS 26.0, *)
struct FullScreenControlsViewPreview: View {
    @Namespace private var namespace
    @State private var seekValue: Double = 0.3
    @State private var isSeeking = false
    @State private var volumeValue: Double = 0.7
    @State private var isAdjustingVolume = false
    @State private var showLyrics = false

    var body: some View {
        FullScreenControlsView(
            seekValue: self.$seekValue,
            isSeeking: self.$isSeeking,
            volumeValue: self.$volumeValue,
            isAdjustingVolume: self.$isAdjustingVolume,
            showLyrics: self.$showLyrics,
            namespace: self.namespace
        )
        .environment(PlayerService())
        .frame(width: 500)
        .padding()
        .background(.black)
    }
}

#Preview {
    if #available(macOS 26.0, *) {
        FullScreenControlsViewPreview()
    }
}
