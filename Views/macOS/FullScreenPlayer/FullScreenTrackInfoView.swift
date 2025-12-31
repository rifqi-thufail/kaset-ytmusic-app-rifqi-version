import SwiftUI

// MARK: - FullScreenTrackInfoView

/// Track information display for the full-screen player.
/// Shows song title, artist, album, and explicit badge.
@available(macOS 26.0, *)
struct FullScreenTrackInfoView: View {
    let track: Song?

    var body: some View {
        VStack(spacing: 8) {
            // Song title with explicit badge
            HStack(spacing: 8) {
                Text(self.track?.title ?? "Not Playing")
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                // Explicit badge (if applicable)
                // Note: Song model doesn't have explicit flag, but we can add it later
            }

            // Artist name
            if let track, !track.artistsDisplay.isEmpty {
                Text(track.artistsDisplay)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }

            // Album name
            if let albumName = track?.album?.title, !albumName.isEmpty {
                Text(albumName)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: self.track?.videoId)
    }
}

// MARK: - Preview

@available(macOS 26.0, *)
#Preview {
    FullScreenTrackInfoView(
        track: Song(
            id: "test",
            title: "POWER",
            artists: [Artist(id: "1", name: "Kanye West")],
            album: Album(
                id: "1",
                title: "My Beautiful Dark Twisted Fantasy",
                artists: nil,
                thumbnailURL: nil,
                year: nil,
                trackCount: nil
            ),
            duration: 287,
            thumbnailURL: nil,
            videoId: "test"
        )
    )
    .frame(width: 400)
    .padding()
    .background(.black)
}
