import SwiftUI

// MARK: - SyncedLyricsView

/// Time-synced lyrics display for the full-screen player.
/// Shows lyrics with the current line highlighted and auto-scrolls
/// to keep the current line centered.
@available(macOS 26.0, *)
struct SyncedLyricsView: View {
    let lyrics: Lyrics?
    let isLoading: Bool
    let progress: TimeInterval

    @State private var currentLineIndex: Int = 0
    @State private var scrollProxy: ScrollViewProxy?

    /// Parsed lyric lines with optional timing (for future enhancement).
    private var lyricLines: [LyricLine] {
        guard let lyrics, lyrics.isAvailable else { return [] }
        return lyrics.lines.enumerated().map { index, text in
            LyricLine(index: index, text: text)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            self.headerView

            Divider()
                .background(.white.opacity(0.2))

            // Lyrics content
            self.contentView
        }
        .background(.black.opacity(0.4))
        .background(.ultraThinMaterial)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))

            Text("Lyrics")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if self.isLoading {
            self.loadingView
        } else if let lyrics, lyrics.isAvailable {
            self.lyricsScrollView
        } else {
            self.noLyricsView
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.regular)
                .tint(.white)

            Text("Loading lyrics...")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noLyricsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.quote")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))

            Text("No lyrics available")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.6))

            Text("Lyrics aren't available for this song")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var lyricsScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    // Top padding for centering
                    Spacer()
                        .frame(height: 100)

                    ForEach(self.lyricLines) { line in
                        self.lyricLineView(line)
                            .id(line.index)
                    }

                    // Bottom padding for centering
                    Spacer()
                        .frame(height: 200)

                    // Source attribution
                    if let source = lyrics?.source {
                        Text(source)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.top, 20)
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                self.scrollProxy = proxy
            }
            .onChange(of: self.currentLineIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    private func lyricLineView(_ line: LyricLine) -> some View {
        let isCurrentLine = line.index == self.currentLineIndex
        let isPastLine = line.index < self.currentLineIndex
        let isFutureLine = line.index > self.currentLineIndex

        return Text(line.text.isEmpty ? "♪" : line.text)
            .font(.system(size: isCurrentLine ? 24 : 18, weight: isCurrentLine ? .bold : .medium))
            .foregroundStyle(self.lineColor(isCurrentLine: isCurrentLine, isPast: isPastLine))
            .opacity(isCurrentLine ? 1.0 : (isPastLine ? 0.4 : 0.6))
            .scaleEffect(isCurrentLine ? 1.0 : 0.95, anchor: .leading)
            .animation(.easeInOut(duration: 0.2), value: isCurrentLine)
            .contentTransition(.opacity)
            .onTapGesture {
                // Allow tapping on a line to seek (future enhancement with timed lyrics)
                self.currentLineIndex = line.index
            }
    }

    private func lineColor(isCurrentLine: Bool, isPast: Bool) -> Color {
        if isCurrentLine {
            return .white
        } else if isPast {
            return .white.opacity(0.5)
        } else {
            return .white.opacity(0.7)
        }
    }
}

// MARK: - LyricLine Model

/// Represents a single line of lyrics.
struct LyricLine: Identifiable {
    let index: Int
    let text: String

    /// Optional timing information for synced lyrics (future enhancement).
    var startTime: TimeInterval?
    var endTime: TimeInterval?

    var id: Int { self.index }
}

// MARK: - Preview

@available(macOS 26.0, *)
#Preview {
    SyncedLyricsView(
        lyrics: Lyrics(
            text: """
            I'm living in that 21st century
            Doing something mean to it
            Do it better than anybody you ever seen do it
            Screams from the haters got a nice ring to it
            I guess every superhero need his theme music

            No one man should have all that power
            The clock's ticking, I just count the hours
            Stop tripping, I'm tripping off the power
            """,
            source: "Source: LyricFind"
        ),
        isLoading: false,
        progress: 30
    )
    .frame(width: 400, height: 600)
    .background(.black)
}
