import Foundation
import Observation
import WidgetKit

@MainActor @Observable
final class ExchangeStore {
    var currencies: [Currency]
    var quotes: [QuoteSnapshot] = []
    var euroReference: Rate?
    var history: [Rate] = []
    var historyError: String?
    var loadingRate = false
    var loadingHistory = false
    private let client: FrankfurterClient
    private let cache: RateCache
    private var rateRequest = UUID()
    private var historyRequest = UUID()

    init(client: FrankfurterClient = FrankfurterClient(), cache: RateCache = .shared) {
        self.client = client
        self.cache = cache
        currencies = cache.currencies() ?? Currency.common
    }

    func loadCurrencies() async {
        #if DEBUG
        if ScreenshotSupport.isEnabled {
            currencies = Currency.common
            return
        }
        #endif
        do {
            let values = try await client.currencies()
            try Task.checkCancellation()
            currencies = values.sorted { $0.code < $1.code }
            cache.save(currencies: currencies)
        } catch { /* Cached/common currencies remain usable without a connection. */ }
    }

    func loadRates(selection: CurrencySelection) async {
        #if DEBUG
        if ScreenshotSupport.isEnabled {
            euroReference = ScreenshotSupport.rate(for: CurrencyPair(base: selection.base, quote: "EUR"))
            quotes = selection.quotes.map {
                QuoteSnapshot(quote: $0, rate: ScreenshotSupport.rate(for: CurrencyPair(base: selection.base, quote: $0)), isOffline: false)
            }
            loadingRate = false
            return
        }
        #endif
        let request = UUID()
        rateRequest = request
        let euroPair = CurrencyPair(base: selection.base, quote: "EUR")
        if selection.base == "EUR" {
            euroReference = Rate(date: .now, base: "EUR", quote: "EUR", rate: 1)
        } else if let cached = cache.latest(for: euroPair) {
            euroReference = cached
        } else if let inverse = cache.latest(for: CurrencyPair(base: "EUR", quote: selection.base)) {
            euroReference = Rate(date: inverse.date, base: selection.base, quote: "EUR", rate: 1 / inverse.rate)
        } else {
            euroReference = nil
        }
        quotes = selection.quotes.map {
            QuoteSnapshot(quote: $0, rate: cache.latest(for: CurrencyPair(base: selection.base, quote: $0)), isOffline: false)
        }
        loadingRate = true
        defer { if rateRequest == request { loadingRate = false } }
        // Reuse an existing EUR comparison; otherwise fetch the reference alongside the quotes.
        let requested = CurrencySelection(base: selection.base,
                                          quotes: selection.quotes + (selection.base == "EUR" ? [] : ["EUR"]))
        let result = await client.latest(for: requested, cache: cache)
        guard !Task.isCancelled, rateRequest == request else { return }
        quotes = result.filter { selection.quotes.contains($0.quote) }
        if let reference = result.first(where: { $0.quote == "EUR" })?.rate { euroReference = reference }
        if quotes.contains(where: { !$0.isOffline }) {
            WidgetCenter.shared.reloadTimelines(ofKind: "ExchangeWidget")
        }
    }

    func loadHistory(pair: CurrencyPair, period: RatePeriod) async {
        #if DEBUG
        if ScreenshotSupport.isEnabled {
            history = ScreenshotSupport.history(for: pair, period: period)
            historyError = nil
            loadingHistory = false
            return
        }
        #endif
        let request = UUID()
        historyRequest = request
        history = cache.history(for: pair, period: period) ?? []
        historyError = nil
        loadingHistory = true
        defer { if historyRequest == request { loadingHistory = false } }
        do {
            let rates = try await client.history(for: pair, period: period)
            try Task.checkCancellation()
            guard historyRequest == request else { return }
            history = rates
            cache.save(rates, for: pair, period: period)
        } catch {
            guard !Task.isCancelled, historyRequest == request else { return }
            historyError = history.isEmpty
                ? String(localized: "Der Verlauf konnte nicht geladen werden. \(error.localizedDescription)")
                : String(localized: "Gespeicherter Verlauf · Aktualisierung fehlgeschlagen.")
        }
    }
}
