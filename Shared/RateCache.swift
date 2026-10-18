import Foundation

/// Both targets use the same App Group. Atomic files keep simultaneous widget/app writes safe.
struct RateCache: Sendable {
    static var shared: RateCache {
        let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String ?? "group.de.leon.currency"
        let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return RateCache(directory: root.appendingPathComponent("Rates", isDirectory: true))
    }
    let directory: URL

    func latest(for pair: CurrencyPair) -> Rate? {
        read(Rate.self, key: pair.key).flatMap {
            $0.base == pair.base && $0.quote == pair.quote && $0.rate.isFinite && $0.rate > 0 ? $0 : nil
        }
    }
    func save(_ rate: Rate, for pair: CurrencyPair) { write(rate, key: pair.key) }
    func history(for pair: CurrencyPair, period: RatePeriod) -> [Rate]? {
        read([Rate].self, key: "\(pair.key)-\(period.months)")
    }
    func save(_ rates: [Rate], for pair: CurrencyPair, period: RatePeriod) {
        write(rates, key: "\(pair.key)-\(period.months)")
    }
    func currencies() -> [Currency]? { read([Currency].self, key: "currencies") }
    func save(currencies: [Currency]) { write(currencies, key: "currencies") }

    private func read<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(key).appendingPathExtension("json")) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    private func write<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appendingPathComponent(key).appendingPathExtension("json"), options: .atomic)
        } catch { /* A full disk must not prevent displaying a freshly downloaded rate. */ }
    }
}
