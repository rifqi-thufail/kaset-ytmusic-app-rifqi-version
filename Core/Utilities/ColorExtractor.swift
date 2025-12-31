import AppKit
import CoreGraphics
import SwiftUI

/// Extracts dominant colors from images for UI accent backgrounds.
enum ColorExtractor {
    /// Represents a weighted color sample for averaging.
    private struct WeightedColor {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let weight: CGFloat
    }

    /// Represents extracted color palette from an image.
    struct ColorPalette: Equatable, Sendable {
        /// Dark mode primary color (darker, saturated).
        let primary: Color
        /// Dark mode secondary color (even darker).
        let secondary: Color
        /// Light mode tint color (lighter, pastel).
        let lightTint: Color

        /// Extended palette with 6 colors for MeshGradient.
        let meshColors: [Color]

        /// Default adaptive palette when no image is available.
        static let `default` = ColorPalette(
            primary: Color(nsColor: NSColor(white: 0.15, alpha: 1)),
            secondary: Color(nsColor: NSColor(white: 0.08, alpha: 1)),
            lightTint: Color(nsColor: NSColor.controlAccentColor).opacity(0.3),
            meshColors: [
                Color(red: 0.1, green: 0.1, blue: 0.15),
                Color(red: 0.08, green: 0.12, blue: 0.18),
                Color(red: 0.12, green: 0.08, blue: 0.14),
                Color(red: 0.06, green: 0.1, blue: 0.16),
                Color(red: 0.1, green: 0.06, blue: 0.12),
                Color(red: 0.08, green: 0.08, blue: 0.1),
            ]
        )
    }

    /// Extracts a color palette from an NSImage.
    /// Uses k-means clustering on downsampled image for performance.
    /// - Parameter image: The source image.
    /// - Returns: A ColorPalette with primary and secondary colors.
    static func extractPalette(from image: NSImage) -> ColorPalette {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .default
        }

        // Downsample for performance (8x8 is enough for dominant color)
        let sampleSize = 8
        guard let context = createBitmapContext(width: sampleSize, height: sampleSize) else {
            return .default
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        guard let data = context.data else {
            return .default
        }

        let pointer = data.bindMemory(to: UInt8.self, capacity: sampleSize * sampleSize * 4)
        var colors: [WeightedColor] = []

        // Sample pixels
        for yCoord in 0 ..< sampleSize {
            for xCoord in 0 ..< sampleSize {
                let offset = (yCoord * sampleSize + xCoord) * 4
                let red = CGFloat(pointer[offset]) / 255.0
                let green = CGFloat(pointer[offset + 1]) / 255.0
                let blue = CGFloat(pointer[offset + 2]) / 255.0

                // Weight by saturation and avoid near-black/white pixels
                let maxC = max(red, green, blue)
                let minC = min(red, green, blue)
                let saturation = maxC > 0 ? (maxC - minC) / maxC : 0
                let brightness = maxC

                // Skip very dark or very light pixels
                if brightness > 0.1, brightness < 0.95 {
                    let weight = saturation * 0.7 + 0.3
                    colors.append(WeightedColor(red: red, green: green, blue: blue, weight: weight))
                }
            }
        }

        // Find dominant color using weighted average
        guard !colors.isEmpty else {
            return .default
        }

        let totalWeight = colors.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else {
            return .default
        }

        let avgR = colors.reduce(0) { $0 + $1.red * $1.weight } / totalWeight
        let avgG = colors.reduce(0) { $0 + $1.green * $1.weight } / totalWeight
        let avgB = colors.reduce(0) { $0 + $1.blue * $1.weight } / totalWeight

        // Create primary color (saturated and darker for dark mode background)
        let primary = self.adjustColorForDarkMode(r: avgR, g: avgG, b: avgB, darken: 0.4)

        // Create secondary color (even darker for gradient end)
        let secondary = self.adjustColorForDarkMode(r: avgR, g: avgG, b: avgB, darken: 0.7)

        // Create light tint (brighter, less saturated for light mode)
        let lightTint = self.adjustColorForLightMode(r: avgR, g: avgG, b: avgB)

        // Create 6 mesh colors with variations for MeshGradient
        let meshColors = self.generateMeshColors(r: avgR, g: avgG, b: avgB, colors: colors)

        return ColorPalette(
            primary: Color(nsColor: primary),
            secondary: Color(nsColor: secondary),
            lightTint: Color(nsColor: lightTint),
            meshColors: meshColors
        )
    }

    /// Generates 6 varied colors for MeshGradient based on extracted palette.
    private static func generateMeshColors(
        r: CGFloat,
        g: CGFloat,
        b: CGFloat,
        colors: [WeightedColor]
    ) -> [Color] {
        // Sort colors by weight to get top contributors
        let sortedColors = colors.sorted { $0.weight > $1.weight }

        // Take top 3 unique-ish colors
        var selectedColors: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [(r, g, b)]

        for wColor in sortedColors.prefix(10) {
            let isDifferent = selectedColors.allSatisfy { existing in
                let diff = abs(existing.r - wColor.red) + abs(existing.g - wColor.green) + abs(existing.b - wColor.blue)
                return diff > 0.15
            }
            if isDifferent {
                selectedColors.append((wColor.red, wColor.green, wColor.blue))
            }
            if selectedColors.count >= 3 { break }
        }

        // Pad with variations if needed
        while selectedColors.count < 3 {
            let base = selectedColors[0]
            let variation = (
                r: min(1, max(0, base.r + CGFloat.random(in: -0.1 ... 0.1))),
                g: min(1, max(0, base.g + CGFloat.random(in: -0.1 ... 0.1))),
                b: min(1, max(0, base.b + CGFloat.random(in: -0.1 ... 0.1)))
            )
            selectedColors.append(variation)
        }

        // Generate 6 colors with darkening for background use
        var meshColors: [Color] = []
        for idx in 0 ..< 6 {
            let baseIdx = idx % 3
            let base = selectedColors[baseIdx]

            // Vary the darkening amount
            let darkenFactor = 0.5 + CGFloat(idx % 2) * 0.2
            let satBoost = 1.1 + CGFloat(idx % 3) * 0.1

            let nsColor = NSColor(red: base.r, green: base.g, blue: base.b, alpha: 1.0)
            var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
            nsColor.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)

            // Shift hue slightly for variety
            let hueShift = CGFloat(idx) * 0.02
            let adjustedHue = (hue + hueShift).truncatingRemainder(dividingBy: 1.0)
            let adjustedSat = min(sat * satBoost, 1.0)
            let adjustedBri = bri * (1 - darkenFactor)

            let finalColor = NSColor(
                hue: adjustedHue,
                saturation: adjustedSat,
                brightness: max(adjustedBri, 0.08),
                alpha: 1.0
            )
            meshColors.append(Color(nsColor: finalColor))
        }

        return meshColors
    }

    /// Extracts palette from image data off the main actor.
    /// - Parameter data: Raw image data.
    /// - Returns: Extracted color palette.
    @MainActor
    static func extractPalette(from data: Data) async -> ColorPalette {
        await Task.detached(priority: .userInitiated) {
            guard let image = NSImage(data: data) else {
                return ColorPalette.default
            }
            return self.extractPalette(from: image)
        }.value
    }

    // MARK: - Private Helpers

    private static func createBitmapContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    private static func adjustColorForDarkMode(
        r: CGFloat,
        g: CGFloat,
        b: CGFloat,
        darken: CGFloat
    ) -> NSColor {
        // Convert to HSB for easier manipulation
        let nsColor = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Increase saturation slightly and darken significantly
        let adjustedSaturation = min(saturation * 1.2, 1.0)
        let adjustedBrightness = brightness * (1 - darken)

        return NSColor(
            hue: hue,
            saturation: adjustedSaturation,
            brightness: max(adjustedBrightness, 0.05),
            alpha: 1.0
        )
    }

    private static func adjustColorForLightMode(
        r: CGFloat,
        g: CGFloat,
        b: CGFloat
    ) -> NSColor {
        // Convert to HSB for easier manipulation
        let nsColor = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Create a lighter, less saturated pastel version
        // Reduce saturation significantly and increase brightness
        let adjustedSaturation = saturation * 0.4
        let adjustedBrightness = min(brightness * 1.3 + 0.4, 1.0)

        return NSColor(
            hue: hue,
            saturation: adjustedSaturation,
            brightness: adjustedBrightness,
            alpha: 1.0
        )
    }
}
