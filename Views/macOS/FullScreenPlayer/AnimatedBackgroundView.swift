import SwiftUI

// MARK: - AnimatedBackgroundView

/// Liquid glass animated background for the full-screen player.
/// Uses MeshGradient with extracted album colors for a flowing, organic feel.
/// Overlaid with ultraThinMaterial for depth and refraction.
@available(macOS 26.0, *)
struct AnimatedBackgroundView: View {
    let imageURL: URL?

    @State private var palette: ColorExtractor.ColorPalette = .default
    @State private var isLoaded = false

    /// Animation phase for mesh point oscillation.
    @State private var animationPhase: Double = 0

    /// Timer for continuous subtle animation.
    private let animationTimer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base layer: Blurred album art for color foundation
                if let url = imageURL {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width * 1.3, height: geometry.size.height * 1.3)
                            .blur(radius: 100)
                            .scaleEffect(1.2)
                    } placeholder: {
                        Color.black
                    }
                }

                // Layer 2: Animated MeshGradient with extracted colors
                self.liquidMeshGradient
                    .opacity(self.isLoaded ? 0.85 : 0)
                    .animation(.easeInOut(duration: 1.2), value: self.isLoaded)

                // Layer 3: Dark gradient for text readability
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.2),
                        Color.black.opacity(0.35),
                        Color.black.opacity(0.5),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Layer 4: Ultra thin material for liquid glass depth
                Rectangle()
                    .fill(.ultraThinMaterial.opacity(0.3))

                // Layer 5: Subtle vignette
                RadialGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.25),
                    ],
                    center: .center,
                    startRadius: geometry.size.width * 0.35,
                    endRadius: geometry.size.width * 0.85
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .task(id: self.imageURL) {
            await self.loadPalette()
        }
        .onReceive(self.animationTimer) { _ in
            self.animationPhase += 0.008
        }
    }

    // MARK: - Liquid Mesh Gradient

    private var liquidMeshGradient: some View {
        // Create oscillating points for organic movement
        let phase = self.animationPhase

        // 3x3 grid points with subtle oscillation
        let points: [SIMD2<Float>] = [
            // Row 0
            SIMD2(0.0, 0.0),
            SIMD2(0.5 + Float(sin(phase * 0.7)) * 0.05, 0.0),
            SIMD2(1.0, 0.0),
            // Row 1
            SIMD2(0.0 + Float(cos(phase * 0.5)) * 0.03, 0.5 + Float(sin(phase * 0.6)) * 0.04),
            SIMD2(0.5 + Float(sin(phase * 0.8)) * 0.06, 0.5 + Float(cos(phase * 0.9)) * 0.05),
            SIMD2(1.0 + Float(sin(phase * 0.4)) * 0.03, 0.5 + Float(cos(phase * 0.7)) * 0.04),
            // Row 2
            SIMD2(0.0, 1.0),
            SIMD2(0.5 + Float(cos(phase * 0.6)) * 0.05, 1.0),
            SIMD2(1.0, 1.0),
        ]

        // Rotate colors based on animation phase for smooth color cycling
        let colors = self.palette.meshColors
        let rotationOffset = Int(phase * 0.3) % max(colors.count, 1)

        // Create rotated color array for smooth cycling effect
        let meshColors: [Color] = [
            colors[(0 + rotationOffset) % colors.count],
            colors[(1 + rotationOffset) % colors.count],
            colors[(2 + rotationOffset) % colors.count],
            colors[(3 + rotationOffset) % colors.count],
            colors[(0 + rotationOffset) % colors.count],
            colors[(4 + rotationOffset) % colors.count],
            colors[(5 + rotationOffset) % colors.count],
            colors[(2 + rotationOffset) % colors.count],
            colors[(1 + rotationOffset) % colors.count],
        ]

        return MeshGradient(
            width: 3,
            height: 3,
            points: points,
            colors: meshColors,
            smoothsColors: true
        )
        .blur(radius: 30)
        .animation(.easeInOut(duration: 2.0), value: rotationOffset)
    }

    // MARK: - Palette Loading

    private func loadPalette() async {
        guard let url = imageURL else {
            self.palette = .default
            self.isLoaded = true
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let extracted = await ColorExtractor.extractPalette(from: data)
            withAnimation(.easeInOut(duration: 1.2)) {
                self.palette = extracted
                self.isLoaded = true
            }
        } catch is CancellationError {
            return
        } catch {
            DiagnosticsLogger.ui.debug("Failed to extract background colors: \(error.localizedDescription)")
            self.palette = .default
            self.isLoaded = true
        }
    }
}

// MARK: - Preview

@available(macOS 26.0, *)
#Preview {
    AnimatedBackgroundView(
        imageURL: URL(string: "https://lh3.googleusercontent.com/test")
    )
    .frame(width: 1000, height: 700)
}
