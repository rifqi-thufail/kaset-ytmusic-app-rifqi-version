import SwiftUI

// MARK: - FixedProgressView

/// A ProgressView wrapper with explicit frame sizing to prevent AppKit Auto Layout constraint warnings.
/// The standard ProgressView on macOS can produce spurious warnings like:
/// "has a maximum length that doesn't satisfy min <= max"
/// This wrapper provides a fixed frame to avoid these layout ambiguity issues.
struct FixedProgressView: View {
    let controlSize: ControlSize
    let scale: CGFloat

    init(controlSize: ControlSize = .regular, scale: CGFloat = 1.0) {
        self.controlSize = controlSize
        self.scale = scale
    }

    private var frameSize: CGFloat {
        switch self.controlSize {
        case .mini:
            return 12 * self.scale
        case .small:
            return 16 * self.scale
        case .regular:
            return 20 * self.scale
        case .large:
            return 24 * self.scale
        case .extraLarge:
            return 32 * self.scale
        @unknown default:
            return 20 * self.scale
        }
    }

    var body: some View {
        ProgressView()
            .controlSize(self.controlSize)
            .scaleEffect(self.scale)
            .frame(width: self.frameSize, height: self.frameSize)
    }
}

// MARK: - LoadingView

/// Reusable loading indicator view with optional message.
/// Includes a pulsing animation for visual feedback.
struct LoadingView: View {
    let message: String

    /// Whether to show skeleton placeholders instead of just a spinner.
    let showSkeleton: Bool

    /// Number of skeleton sections to show.
    let skeletonSectionCount: Int

    init(
        _ message: String = "Loading...",
        showSkeleton: Bool = false,
        skeletonSectionCount: Int = 3
    ) {
        self.message = message
        self.showSkeleton = showSkeleton
        self.skeletonSectionCount = skeletonSectionCount
    }

    var body: some View {
        if self.showSkeleton {
            self.skeletonContent
        } else {
            self.spinnerContent
        }
    }

    private var spinnerContent: some View {
        VStack(spacing: 16) {
            FixedProgressView(controlSize: .regular)
            Text(self.message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var skeletonContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                ForEach(0 ..< self.skeletonSectionCount, id: \.self) { _ in
                    SkeletonSectionView()
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
}

// MARK: - HomeLoadingView

/// A specialized loading view for the home screen with responsive skeleton sections.
@available(macOS 26.0, *)
struct HomeLoadingView: View {
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - 48 // Account for horizontal padding
            let cardWidth = Self.calculateCardWidth(for: availableWidth)
            let cardCount = Self.calculateCardCount(for: availableWidth, cardWidth: cardWidth)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 32) {
                    ForEach(0 ..< 4, id: \.self) { index in
                        ResponsiveSkeletonSectionView(
                            cardCount: cardCount,
                            cardWidth: cardWidth,
                            cardHeight: cardWidth // Square cards
                        )
                        .fadeIn(delay: Double(index) * 0.1)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
    }
    
    /// Calculate appropriate card width based on available width
    private static func calculateCardWidth(for availableWidth: CGFloat) -> CGFloat {
        // Target: show 4-6 cards comfortably with spacing
        let spacing: CGFloat = 16
        let minCardWidth: CGFloat = 140
        let maxCardWidth: CGFloat = 200
        
        // Calculate how many cards can fit
        let possibleCards = Int((availableWidth + spacing) / (minCardWidth + spacing))
        let targetCards = max(3, min(7, possibleCards))
        
        // Calculate actual card width to fill the space
        let totalSpacing = CGFloat(targetCards - 1) * spacing
        let cardWidth = (availableWidth - totalSpacing) / CGFloat(targetCards)
        
        return min(maxCardWidth, max(minCardWidth, cardWidth))
    }
    
    /// Calculate how many cards should be shown based on width
    private static func calculateCardCount(for availableWidth: CGFloat, cardWidth: CGFloat) -> Int {
        let spacing: CGFloat = 16
        let visibleCards = Int((availableWidth + spacing) / (cardWidth + spacing))
        return max(3, min(8, visibleCards + 1)) // Show one extra for scroll hint
    }
}

/// A responsive skeleton placeholder for a horizontal section.
struct ResponsiveSkeletonSectionView: View {
    let cardCount: Int
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    init(cardCount: Int = 5, cardWidth: CGFloat = 160, cardHeight: CGFloat = 160) {
        self.cardCount = cardCount
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section title skeleton - responsive width
            SkeletonView.rectangle(cornerRadius: 4)
                .frame(width: min(200, cardWidth * 1.2), height: 20)

            // Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0 ..< self.cardCount, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 8) {
                            // Thumbnail skeleton
                            SkeletonView.rectangle(cornerRadius: 8)
                                .frame(width: self.cardWidth, height: self.cardHeight)

                            // Title skeleton
                            SkeletonView.rectangle(cornerRadius: 4)
                                .frame(width: self.cardWidth * 0.8, height: 14)

                            // Subtitle skeleton
                            SkeletonView.rectangle(cornerRadius: 4)
                                .frame(width: self.cardWidth * 0.5, height: 12)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    VStack {
        LoadingView("Loading your music...")
        Divider()
        LoadingView("Loading...", showSkeleton: true, skeletonSectionCount: 2)
    }
    .frame(width: 600, height: 800)
}
