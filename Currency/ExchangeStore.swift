import Foundation
import Observation
import WidgetKit

@MainActor @Observable
final class ExchangeStore {
    var currencies = RateCache.shared.currencies() ?? Currency.common
    var quotes: [QuoteSnapshot] = []
    var history: [Rate] = []
    var historyError: String?
    var loadingRate = false
    var loadingHistory = false
    private let client = FrankfurterClient()
    private let cache = RateCache.shared
    private var rateRequest = UUID()
    private var historyRequest = UUID()

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
            quotes = selection.quotes.map {
                QuoteSnapshot(quote: $0, rate: ScreenshotSupport.rate(for: CurrencyPair(base: selection.base, quote: $0)), isOffline: false)
            }
            loadingRate = false
            return
        }
        #endif
        let request = UUID()
        rateRequest = request
        quotes = selection.quotes.map {
            QuoteSnapshot(quote: $0, rate: cache.latest(for: CurrencyPair(base: selection.base, quote: $0)), isOffline: false)
        }
        loadingRate = true
        defer { if rateRequest == request { loadingRate = false } }
        let result = await client.latest(for: selection, cache: cache)
        guard !Task.isCancelled, rateRequest == request else { return }
        quotes = result
        if result.contains(where: { !$0.isOffline }) {
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
