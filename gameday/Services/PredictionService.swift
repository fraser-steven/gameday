//
//  PredictionService.swift
//  gameday
//
//  Talks to Supabase over plain REST (no SDK, matching FootballService):
//  - triggers the `refresh-predictions` Edge Function on app launch
//  - reads cached rows from the `predictions` table
//

import Foundation

actor PredictionService {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = Self.makeDecoder()
    }

    /// A `JSONDecoder` configured for PostgREST rows. Shared with tests.
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = parseTimestamp(raw) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognised timestamp: \(raw)"
                ))
            }
            return date
        }
        return decoder
    }

    /// Fire-and-forget nudge to regenerate predictions. The function no-ops if the
    /// data is still fresh, so calling this on every launch is cheap.
    func triggerRefresh() async {
        guard SupabaseConfig.isConfigured else { return }
        var request = URLRequest(url: SupabaseConfig.functionsURL.appending(path: "refresh-predictions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        applyAuth(&request)
        _ = try? await session.data(for: request)
    }

    /// All cached predictions for fixtures that haven't kicked off long ago,
    /// keyed by fixture id (TheSportsDB `idEvent`).
    func predictions() async throws -> [String: Prediction] {
        guard SupabaseConfig.isConfigured else { return [:] }

        let since = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86_400))
        var components = URLComponents(
            url: SupabaseConfig.restURL.appending(path: "predictions"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "kickoff", value: "gte.\(since)"),
            URLQueryItem(name: "order", value: "kickoff.asc"),
        ]
        guard let url = components?.url else { throw FootballError.invalidURL }

        var request = URLRequest(url: url)
        applyAuth(&request)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FootballError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw FootballError.httpStatus(http.statusCode) }

        let rows = try decoder.decode([Prediction].self, from: data)
        return Dictionary(rows.map { ($0.fixtureID, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    // MARK: - Helpers

    private func applyAuth(_ request: inout URLRequest) {
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private static let plainISO: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Internal (not private) so tests can exercise the timestamp parsing directly.
    static func parseTimestamp(_ raw: String) -> Date? {
        // PostgREST renders timestamptz as e.g. "2026-09-08T19:00:00+00:00", often
        // with microseconds ("...00.123456+00:00"). Drop any fractional seconds
        // (ISO8601DateFormatter only tolerates milliseconds) and a space separator.
        let cleaned = raw
            .replacingOccurrences(of: " ", with: "T")
            .replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return plainISO.date(from: cleaned)
    }
}
