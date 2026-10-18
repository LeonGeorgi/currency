import Foundation

struct FrankfurterClient: Sendable {
    var session: URLSession = .shared

    func currencies() async throws -> [Currency] {
        try await fetch(path: "currencies")
    }

    func latest(for pair: CurrencyPair) async throws -> Rate {
        if pair.base == pair.quote {
            return Rate(date: APIDate.calendar.startOfDay(for: Date()), base: pair.base, quote: pair.quote, rate: 1)
        }
        let rate: Rate = try await fetch(path: "rate/\(pair.base)/\(pair.quote)")
        try validate(rate, for: pair)
        return rate
    }

    /// One failed currency must not hide the other comparison rates.
    func latest(for selection: CurrencySelection, cache: RateCache = .shared) async -> [QuoteSnapshot] {
        await withTaskGroup(of: QuoteSnapshot.self) { group in
            for quote in selection.quotes {
                group.addTask {
                    let pair = CurrencyPair(base: selection.base, quote: quote)
                    do {
                        let rate = try await latest(for: pair)
                        try Task.checkCancellation()
                        cache.save(rate, for: pair)
                        return QuoteSnapshot(quote: quote, rate: rate, isOffline: false)
                    } catch {
                        return QuoteSnapshot(quote: quote, rate: cache.latest(for: pair), isOffline: true)
                    }
                }
            }
            var results: [String: QuoteSnapshot] = [:]
            for await result in group { results[result.quote] = result }
            return selection.quotes.compactMap { results[$0] }
        }
    }

    func history(for pair: CurrencyPair, period: RatePeriod, now: Date = Date()) async throws -> [Rate] {
        if pair.base == pair.quote {
            return [period.start(relativeTo: now), now].map {
                Rate(date: $0, base: pair.base, quote: pair.quote, rate: 1)
            }
        }
        let rates: [Rate] = try await fetch(url: Self.historyURL(for: pair, period: period, now: now))
        for rate in rates { try validate(rate, for: pair) }
        return rates.sorted { $0.date < $1.date }
    }

    static func historyURL(for pair: CurrencyPair, period: RatePeriod, now: Date) -> URL {
        var items = [URLQueryItem(name: "base", value: pair.base), URLQueryItem(name: "quotes", value: pair.quote),
                     URLQueryItem(name: "from", value: APIDate.string(period.start(relativeTo: now))),
                     URLQueryItem(name: "to", value: APIDate.string(now))]
        if let grouping = period.grouping { items.append(URLQueryItem(name: "group", value: grouping)) }
        return url(path: "rates", items: items)
    }

    private static func url(path: String, items: [URLQueryItem] = []) -> URL {
        var components = URLComponents(string: "https://api.frankfurter.dev/v2/\(path)")!
        if !items.isEmpty { components.queryItems = items }
        return components.url!
    }

    private func fetch<T: Decodable>(path: String) async throws -> T {
        try await fetch(url: Self.url(path: path))
    }

    private func fetch<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw APIError.http(response.statusCode) }
        return try APIDate.decoder().decode(T.self, from: data)
    }

    private func validate(_ rate: Rate, for pair: CurrencyPair) throws {
        guard rate.base == pair.base, rate.quote == pair.quote, rate.rate.isFinite, rate.rate > 0 else {
            throw APIError.invalidResponse
        }
    }
}

enum APIError: LocalizedError {
    case invalidResponse, http(Int)
    var errorDescription: String? {
        switch self {
        case .invalidResponse: String(localized: "Die Kursdaten konnten nicht gelesen werden.")
        case .http(404), .http(422): String(localized: "Für dieses Währungspaar sind keine Kurse verfügbar.")
        case .http: String(localized: "Frankfurter ist gerade nicht erreichbar. Bitte versuche es später erneut.")
        }
    }
}
