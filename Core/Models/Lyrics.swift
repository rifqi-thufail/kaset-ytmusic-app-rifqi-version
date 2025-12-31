import Foundation

// MARK: - TimedLyricLine

/// Represents a single line of timed lyrics with start time.
struct TimedLyricLine: Sendable, Equatable, Identifiable {
    let id: Int
    let text: String
    let startTime: TimeInterval

    init(index: Int, text: String, startTime: TimeInterval) {
        self.id = index
        self.text = text
        self.startTime = startTime
    }
}

// MARK: - Lyrics

/// Represents lyrics for a song from YouTube Music.
struct Lyrics: Sendable, Equatable {
    /// The lyrics text, with line breaks preserved.
    let text: String

    /// Source attribution (e.g., "Source: LyricFind").
    let source: String?

    /// Timed lyrics lines with timestamps (nil if not available).
    let timedLines: [TimedLyricLine]?

    /// Whether the song has lyrics available.
    var isAvailable: Bool { !self.text.isEmpty }

    /// Whether timed/synced lyrics are available.
    var hasTimedLyrics: Bool { self.timedLines != nil && !(self.timedLines?.isEmpty ?? true) }

    /// Lyrics split into individual lines for display.
    var lines: [String] {
        self.text.components(separatedBy: "\n")
    }

    /// Creates an empty lyrics instance for songs without lyrics.
    static let unavailable = Lyrics(text: "", source: nil, timedLines: nil)

    /// Creates lyrics with just plain text (no timing).
    init(text: String, source: String?) {
        self.text = text
        self.source = source
        self.timedLines = nil
    }

    /// Creates lyrics with timed lines.
    init(text: String, source: String?, timedLines: [TimedLyricLine]?) {
        self.text = text
        self.source = source
        self.timedLines = timedLines
    }
}

// MARK: - LyricsBrowseInfo

/// Represents the lyrics browse ID extracted from the next endpoint.
struct LyricsBrowseInfo: Sendable {
    /// The browse ID to fetch lyrics (format: "MPLYt_xxx").
    let browseId: String
}
