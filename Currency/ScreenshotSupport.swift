import SwiftUI

/// Enabled only by the dedicated UI-test scheme; never uses real app preferences or the API.
enum ScreenshotSupport {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--screenshots")
        #else
        false
        #endif
    }

    static var defaults: UserDefaults {
        isEnabled ? UserDefaults(suiteName: "de.leon.currency.screenshots")! : .standard
    }

    static var colorScheme: ColorScheme? {
        guard isEnabled else { return nil }
        return ProcessInfo.processInfo.arguments.contains("--screenshot-dark") ? .dark : .light
    }

    static func prepare() { _ = prepared }

    private static let prepared: Void = {
        #if DEBUG
        guard isEnabled else { return }
        if ProcessInfo.processInfo.arguments.contains("--keep-screenshot-settings") { return }
        defaults.removePersistentDomain(forName: "de.leon.currency.screenshots")
        defaults.set(usesRoundingExamples ? "ARS" : "EUR", forKey: "baseCurrency")
        defaults.set(CurrencySelection.storeQuotes(usesRoundingExamples ? ["JPY", "USD"] : ["USD", "JPY", "GBP", "CHF"]), forKey: "quoteCurrencies")
        defaults.set(usesRoundingExamples ? 20.0 : 100.0, forKey: "conversionAmount")
        #endif
    }()

    #if DEBUG
    private static let usesRoundingExamples = ProcessInfo.processInfo.arguments.contains("--screenshot-rounding-examples")
    static let date = Date(timeIntervalSince1970: 1_792_108_800) // 16 October 2026, UTC
    private static let euroRates: [String: Double] = {
        if usesRoundingExamples {
            // Synthetic ratios reproduce both reported hidden-fraction bugs.
            return ["EUR": 1, "ARS": 1000, "JPY": (2.1 / 20.1) * 1000, "USD": 0.66]
        }
        return ["EUR": 1.0, "USD": 1.16842, "JPY": 164.48, "GBP": 0.86627, "CHF": 0.93341]
    }()

    static func rate(for pair: CurrencyPair) -> Rate {
        Rate(date: date, base: pair.base, quote: pair.quote,
             rate: (euroRates[pair.quote] ?? 1) / (euroRates[pair.base] ?? 1))
    }

    static func history(for pair: CurrencyPair, period: RatePeriod) -> [Rate] {
        let end = rate(for: pair).rate
        let start = period.start(relativeTo: date)
        return (0...30).map { index in
            let progress = Double(index) / 30
            let variation = 0.972 + 0.028 * progress + 0.005 * sin(progress * .pi * 6)
            return Rate(date: start.addingTimeInterval(date.timeIntervalSince(start) * progress),
                        base: pair.base, quote: pair.quote, rate: end * variation)
        }
    }
    #endif
}
