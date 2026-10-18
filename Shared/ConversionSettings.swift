import Foundation

/// One atomic snapshot, published by the app and read by every widget instance.
struct ConversionSettings: Codable, Hashable, Sendable {
    let selection: CurrencySelection
    let amount: Double

    var widgetSelection: CurrencySelection {
        CurrencySelection(base: selection.base, quotes: Array(selection.quotes.prefix(3)))
    }
}

struct SharedConversionStore: Sendable {
    static var shared: SharedConversionStore {
        SharedConversionStore(url: RateCache.shared.directory.deletingLastPathComponent()
            .appendingPathComponent("ConversionSettings.json"))
    }
    let url: URL

    func load() -> ConversionSettings? {
        guard let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(ConversionSettings.self, from: data),
              settings.amount.isFinite else { return nil }
        return ConversionSettings(selection: CurrencySelection(base: settings.selection.base, quotes: settings.selection.quotes), amount: settings.amount)
    }

    @discardableResult
    func save(_ settings: ConversionSettings) -> Bool {
        do {
            let data = try JSONEncoder().encode(settings)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
