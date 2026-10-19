import Foundation

struct Currency: Codable, Hashable, Identifiable, Sendable {
    let code: String
    let name: String
    var id: String { code }
    var localizedName: String { Locale.current.localizedString(forCurrencyCode: code) ?? name }
    var title: String { "\(code) – \(localizedName)" }

    enum CodingKeys: String, CodingKey { case code = "iso_code", name }

    static let common: [Currency] = [
        .init(code: "EUR", name: "Euro"), .init(code: "USD", name: "US Dollar"),
        .init(code: "JPY", name: "Japanese Yen"), .init(code: "GBP", name: "Pound Sterling"),
        .init(code: "CHF", name: "Swiss Franc"), .init(code: "CAD", name: "Canadian Dollar"),
        .init(code: "AUD", name: "Australian Dollar"), .init(code: "CNY", name: "Chinese Yuan"),
        .init(code: "KRW", name: "South Korean Won"), .init(code: "SEK", name: "Swedish Krona"),
        .init(code: "NOK", name: "Norwegian Krone"), .init(code: "INR", name: "Indian Rupee")
    ]
}

struct CurrencyPair: Hashable, Codable, Sendable {
    var base: String
    var quote: String
    var key: String { "\(base)-\(quote)" }
    var url: URL { URL(string: "currency://pair?base=\(base)&quote=\(quote)")! }

    init(base: String, quote: String) {
        self.base = base.uppercased()
        self.quote = quote.uppercased()
    }

    init?(url: URL) {
        guard url.scheme == "currency", url.host == "pair",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let base = items.first(where: { $0.name == "base" })?.value,
              let quote = items.first(where: { $0.name == "quote" })?.value,
              Self.isValidCode(base), Self.isValidCode(quote) else { return nil }
        self.init(base: base, quote: quote)
    }

    static func isValidCode(_ code: String) -> Bool {
        code.utf8.count == 3 && code.utf8.allSatisfy { (65...90).contains($0) || (97...122).contains($0) }
    }
}

struct Rate: Codable, Equatable, Identifiable, Sendable {
    let date: Date
    let base: String
    let quote: String
    let rate: Double
    var id: Date { date }
}

enum RatePeriod: String, CaseIterable, Identifiable, Sendable {
    case month = "1 M", quarter = "3 M", year = "1 J", fiveYears = "5 J", tenYears = "10 J"
    var id: Self { self }
    // Keep raw values stable for the on-disk history cache.
    var title: String {
        switch self {
        case .month: String(localized: "1 M")
        case .quarter: String(localized: "3 M")
        case .year: String(localized: "1 J")
        case .fiveYears: String(localized: "5 J")
        case .tenYears: String(localized: "10 J")
        }
    }
    var months: Int {
        switch self { case .month: 1; case .quarter: 3; case .year: 12; case .fiveYears: 60; case .tenYears: 120 }
    }
    var description: String {
        switch self {
        case .month: String(localized: "Im letzten Monat")
        case .quarter: String(localized: "In den letzten 3 Monaten")
        case .year: String(localized: "Im letzten Jahr")
        case .fiveYears: String(localized: "In den letzten 5 Jahren")
        case .tenYears: String(localized: "In den letzten 10 Jahren")
        }
    }
    var grouping: String? {
        switch self { case .fiveYears: "week"; case .tenYears: "month"; default: nil }
    }
    func start(relativeTo date: Date) -> Date {
        APIDate.calendar.date(byAdding: .month, value: -months, to: date) ?? date
    }
}

enum APIDate {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    // API dates are calendar days, not instants in the user's time zone.
    static var displayStyle: Date.FormatStyle {
        Date.FormatStyle(date: .abbreviated, time: .omitted, calendar: calendar, timeZone: calendar.timeZone)
    }
    static var compactStyle: Date.FormatStyle {
        Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).day().month()
    }
    static func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }
    static func string(_ date: Date) -> String { formatter().string(from: date) }
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(formatter())
        return decoder
    }
}

/// Ordered comparison currencies shared by the app and widget deep links.
struct CurrencySelection: Hashable, Codable, Sendable {
    let base: String
    let quotes: [String]

    init(base: String, quotes: [String]) {
        self.base = CurrencyPair.isValidCode(base) ? base.uppercased() : "EUR"
        var seen = Set<String>()
        self.quotes = quotes.map { $0.uppercased() }.filter {
            CurrencyPair.isValidCode($0) && seen.insert($0).inserted
        }
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = "currency"
        components.host = "comparison"
        components.queryItems = [.init(name: "base", value: base), .init(name: "quotes", value: quotes.joined(separator: ","))]
        return components.url!
    }

    func url(amount: Double) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if amount.isFinite { components.queryItems?.append(.init(name: "amount", value: String(amount))) }
        return components.url!
    }

    static func amount(from url: URL) -> Double? {
        guard CurrencySelection(url: url) != nil,
              let text = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "amount" })?.value,
              let value = Double(text), value.isFinite else { return nil }
        return value
    }

    init?(url: URL) {
        if let pair = CurrencyPair(url: url) {
            self.init(base: pair.base, quotes: [pair.quote])
            return
        }
        guard url.scheme == "currency", url.host == "comparison",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let base = items.first(where: { $0.name == "base" })?.value,
              CurrencyPair.isValidCode(base),
              let value = items.first(where: { $0.name == "quotes" })?.value else { return nil }
        let quotes = value.components(separatedBy: ",")
        guard !quotes.isEmpty, quotes.allSatisfy(CurrencyPair.isValidCode) else { return nil }
        self.init(base: base, quotes: quotes)
    }

    static func storeQuotes(_ values: [String]) -> String {
        let values = CurrencySelection(base: "EUR", quotes: values).quotes
        return String(data: try! JSONEncoder().encode(values), encoding: .utf8)!
    }

    static func restoreQuotes(_ stored: String, legacyQuote: String) -> [String] {
        if let data = stored.data(using: .utf8), let values = try? JSONDecoder().decode([String].self, from: data) {
            return CurrencySelection(base: "EUR", quotes: values).quotes
        }
        let values = stored.isEmpty ? [legacyQuote] : stored.components(separatedBy: ",")
        let selection = CurrencySelection(base: "EUR", quotes: values)
        return selection.quotes.isEmpty ? ["USD"] : selection.quotes
    }
}

struct QuoteSnapshot: Identifiable, Sendable {
    let quote: String
    let rate: Rate?
    let isOffline: Bool
    var id: String { quote }
}

enum ConversionAmount {
    /// Keep a familiar 1–2–5 sequence, roughly scaled to the value of one euro.
    static func presets(for currency: String, unitsPerEuro: Double?) -> [Double] {
        let fallback: Double = currency == "JPY" ? 100 : currency == "KRW" ? 1000 : 1
        let start: Double
        if let unitsPerEuro, unitsPerEuro.isFinite, unitsPerEuro > 0 {
            start = pow(10, min(8, max(-3, log10(unitsPerEuro).rounded())))
        } else {
            start = fallback
        }
        return [1, 2, 5, 10, 20, 50, 100, 200].map { $0 * start }
    }

    /// The widget's decimal keyboard may use a comma or a point depending on system language.
    static func parse(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(normalized), amount.isFinite else { return nil }
        return amount
    }
}

enum CurrencyDisplay {
    static func flag(for code: String) -> String {
        let code = code.uppercased()
        if code == "EUR" { return "🇪🇺" }
        // National ISO 4217 currencies use the issuing region as their first two letters.
        // Regional currencies such as XAF/XOF/XCD have no single country flag.
        let region = String(code.prefix(2))
        guard CurrencyPair.isValidCode(code),
              Locale.Region.isoRegions.contains(where: { $0.identifier == region }) else { return "🌐" }
        let scalars = region.unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }
        return String(String.UnicodeScalarView(scalars))
    }

    static func symbol(for code: String, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol ?? code
    }

    static func amount(_ value: Double, code: String, locale: Locale = .current) -> String {
        value.formatted(.currency(code: code).locale(locale).precision(.significantDigits(1...12)))
    }
}
