import Foundation

// MARK: - LRCLibService

/// Service for fetching synced/timed lyrics from LRClib (https://lrclib.net).
/// LRClib is an open-source lyrics database with synced (LRC format) lyrics.
enum LRCLibService {
    private static let baseURL = "https://lrclib.net/api"
    private static let logger = DiagnosticsLogger.api

    // MARK: - Response Models

    struct LRCLibResponse: Codable {
        let id: Int?
        let trackName: String?
        let artistName: String?
        let albumName: String?
        let duration: Double?
        let plainLyrics: String?
        let syncedLyrics: String?
    }

    // MARK: - Public API

    /// Fetches synced lyrics for a song by artist and track name.
    /// - Parameters:
    ///   - artist: The artist name
    ///   - track: The track/song name
    ///   - duration: Optional track duration in seconds for better matching
    /// - Returns: Lyrics with timed lines if available, plain lyrics otherwise
    static func fetchLyrics(artist: String, track: String, duration: TimeInterval? = nil) async -> Lyrics? {
        // Build URL with query parameters
        var components = URLComponents(string: "\(baseURL)/get")
        var queryItems = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: track),
        ]
        if let duration {
            queryItems.append(URLQueryItem(name: "duration", value: String(Int(duration))))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            self.logger.debug("LRCLib: Failed to build URL for \(artist) - \(track)")
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("Kaset/1.0", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return nil
            }

            // 404 means no lyrics found
            if httpResponse.statusCode == 404 {
                self.logger.debug("LRCLib: No lyrics found for \(artist) - \(track)")
                return nil
            }

            guard httpResponse.statusCode == 200 else {
                self.logger.debug("LRCLib: HTTP \(httpResponse.statusCode) for \(artist) - \(track)")
                return nil
            }

            let lrcResponse = try JSONDecoder().decode(LRCLibResponse.self, from: data)
            return Self.parseLRCResponse(lrcResponse)

        } catch {
            self.logger.debug("LRCLib: Failed to fetch lyrics: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - LRC Parsing

    /// Parses an LRCLib response into a Lyrics object with timed lines.
    private static func parseLRCResponse(_ response: LRCLibResponse) -> Lyrics? {
        // Prefer synced lyrics if available
        if let syncedLyrics = response.syncedLyrics, !syncedLyrics.isEmpty {
            let timedLines = Self.parseLRC(syncedLyrics)
            let plainText = response.plainLyrics ?? timedLines.map(\.text).joined(separator: "\n")
            return Lyrics(
                text: plainText,
                source: "LRClib",
                timedLines: timedLines
            )
        }

        // Fall back to plain lyrics
        if let plainLyrics = response.plainLyrics, !plainLyrics.isEmpty {
            return Lyrics(text: plainLyrics, source: "LRClib")
        }

        return nil
    }

    /// Parses LRC format synced lyrics into timed lines.
    /// LRC format: [mm:ss.xx] Lyric text
    private static func parseLRC(_ lrcText: String) -> [TimedLyricLine] {
        let lines = lrcText.components(separatedBy: "\n")
        var timedLines: [TimedLyricLine] = []

        // Regex to match LRC timestamp: [mm:ss.xx] or [mm:ss]
        let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]\s*(.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        for (index, line) in lines.enumerated() {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, options: [], range: range) else {
                continue
            }

            // Extract minutes
            guard let minutesRange = Range(match.range(at: 1), in: line),
                  let minutes = Double(line[minutesRange])
            else {
                continue
            }

            // Extract seconds
            guard let secondsRange = Range(match.range(at: 2), in: line),
                  let seconds = Double(line[secondsRange])
            else {
                continue
            }

            // Extract milliseconds (optional)
            var milliseconds: Double = 0
            if match.range(at: 3).location != NSNotFound,
               let msRange = Range(match.range(at: 3), in: line),
               let ms = Double(line[msRange])
            {
                // Handle both .xx and .xxx formats
                let msString = String(line[msRange])
                milliseconds = ms / pow(10, Double(msString.count))
            }

            // Extract lyrics text
            var text = ""
            if let textRange = Range(match.range(at: 4), in: line) {
                text = String(line[textRange]).trimmingCharacters(in: .whitespaces)
            }

            let startTime = minutes * 60 + seconds + milliseconds

            timedLines.append(TimedLyricLine(
                index: index,
                text: text,
                startTime: startTime
            ))
        }

        return timedLines.sorted { $0.startTime < $1.startTime }
    }
}
