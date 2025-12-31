import SwiftUI

// MARK: - FullScreenArtworkView

/// Large centered album artwork for the full-screen player.
/// Features shadow, depth effects, breathing animation, and smooth crossfade transitions.
@available(macOS 26.0, *)
struct FullScreenArtworkView: View {
    let imageURL: URL?
    var namespace: Namespace.ID
    var onTap: (() -> Void)?

    @State private var isHovering = false
    @State private var currentImageURL: URL?
    @State private var previousImageURL: URL?

    /// Breathing animation phase.
    @State private var breatheScale: CGFloat = 1.0

    /// Timer for breathing animation.
    private let breatheTimer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                // Previous image (for crossfade)
                if let prevURL = previousImageURL {
                    self.artworkImage(url: prevURL, size: size)
                        .opacity(self.currentImageURL != self.previousImageURL ? 0 : 1)
                }

                // Current image
                if let url = currentImageURL {
                    self.artworkImage(url: url, size: size)
                        .matchedGeometryEffect(id: "albumArt", in: self.namespace)
                }
            }
            .frame(width: size, height: size)
            .scaleEffect(self.isHovering ? 1.03 : self.breatheScale)
            .animation(.easeInOut(duration: 2.5), value: self.breatheScale)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: self.isHovering)
            .onHover { hovering in
                self.isHovering = hovering
            }
            .contentShape(Rectangle())
            .gesture(
                TapGesture()
                    .onEnded { _ in
                        self.onTap?()
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: self.imageURL) { oldValue, newValue in
            self.previousImageURL = oldValue
            withAnimation(.easeInOut(duration: 0.5)) {
                self.currentImageURL = newValue
            }
        }
        .onAppear {
            self.currentImageURL = self.imageURL
        }
        .onReceive(self.breatheTimer) { _ in
            // Subtle breathing: oscillate between 1.0 and 1.015
            withAnimation(.easeInOut(duration: 2.5)) {
                self.breatheScale = self.breatheScale > 1.007 ? 1.0 : 1.015
            }
        }
    }

    private func artworkImage(url: URL, size: CGFloat) -> some View {
        CachedAsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay {
                    CassetteIcon(size: 60)
                        .foregroundStyle(.secondary)
                }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 20)
        .overlay {
            // Subtle inner glow/highlight
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.25), .clear, .black.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

// MARK: - Preview

@available(macOS 26.0, *)
struct FullScreenArtworkViewPreview: View {
    @Namespace private var namespace

    var body: some View {
        FullScreenArtworkView(
            imageURL: URL(string: "https://lh3.googleusercontent.com/test"),
            namespace: self.namespace
        )
        .frame(width: 400, height: 400)
        .background(.black)
    }
}

#Preview {
    if #available(macOS 26.0, *) {
        FullScreenArtworkViewPreview()
    }
}
