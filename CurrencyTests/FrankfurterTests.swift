import XCTest
import UIKit
@testable import Currency

final class FrankfurterTests: XCTestCase {
    func testAppearanceSettingsKeepLegacySnapshotsAndUnknownColorsReadable() throws {
        let legacy = Data(#"{"selection":{"base":"EUR","quotes":["JPY"]},"amount":50}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(ConversionSettings.self, from: legacy).accent, .original)
        let future = Data(#"{"selection":{"base":"EUR","quotes":["JPY"]},"amount":50,"accent":"future-color"}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(ConversionSettings.self, from: future).accent, .original)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let shared = SharedConversionStore(url: directory.appendingPathComponent("settings.json"))
        let settings = ConversionSettings(selection: CurrencySelection(base: "JPY", quotes: ["EUR", "USD"]), amount: 500, accent: .blue)
        XCTAssertTrue(shared.save(settings))
        XCTAssertEqual(shared.load(), settings)
        XCTAssertEqual(shared.load()?.accent, .blue)
    }

    func testAllAccentChoicesHaveIconsInTheBuiltAppForBothDevices() throws {
        XCTAssertNil(AppAccent.original.iconName)
        let names = AppAccent.allCases.compactMap(\.iconName)
        XCTAssertEqual(Set(names).count, names.count)
        for accent in AppAccent.allCases {
            XCTAssertNotNil(UIImage(named: accent.previewName))
        }
        let data = try Data(contentsOf: Bundle.main.bundleURL.appendingPathComponent("Info.plist"))
        let info = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        for key in ["CFBundleIcons", "CFBundleIcons~ipad"] {
            let icons = try XCTUnwrap(info[key] as? [String: Any])
            let alternates = try XCTUnwrap(icons["CFBundleAlternateIcons"] as? [String: Any])
            XCTAssertEqual(Set(alternates.keys), Set(names))
        }
    }

    func testAmountPresetsUseOneTwoFiveAtCurrencyAppropriateScales() {
        XCTAssertEqual(ConversionAmount.presets(for: "EUR", unitsPerEuro: 1), [1, 2, 5, 10, 20, 50, 100, 200])
        XCTAssertEqual(ConversionAmount.presets(for: "JPY", unitsPerEuro: 164.48), [100, 200, 500, 1000, 2000, 5000, 10000, 20000])
        XCTAssertEqual(ConversionAmount.presets(for: "GBP", unitsPerEuro: 0.86).first, 1)
        XCTAssertEqual(ConversionAmount.presets(for: "CZK", unitsPerEuro: 24.323).first, 10)
        XCTAssertEqual(ConversionAmount.presets(for: "KRW", unitsPerEuro: 1499).first, 1000)
        for rate in [nil, .nan, .infinity, 0, -1] as [Double?] {
            XCTAssertEqual(ConversionAmount.presets(for: "JPY", unitsPerEuro: rate).first, 100)
            XCTAssertEqual(ConversionAmount.presets(for: "EUR", unitsPerEuro: rate).first, 1)
        }
    }

    @MainActor
    func testPresetReferenceDoesNotAddEURToVisibleComparisons() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ExchangeStore(client: mockClient(), cache: RateCache(directory: directory))
        await store.loadRates(selection: CurrencySelection(base: "JPY", quotes: ["ERR"]))
        XCTAssertEqual(store.quotes.map(\.quote), ["ERR"])
        XCTAssertEqual(store.euroReference?.base, "JPY")
        XCTAssertEqual(store.euroReference?.quote, "EUR")
        let reference = try XCTUnwrap(store.euroReference)
        XCTAssertEqual(ConversionAmount.presets(for: "JPY", unitsPerEuro: 1 / reference.rate).first, 100)
        await store.loadRates(selection: CurrencySelection(base: "EUR", quotes: ["JPY"]))
        XCTAssertEqual(store.quotes.map(\.quote), ["JPY"])
        XCTAssertEqual(store.euroReference?.base, "EUR")
        XCTAssertEqual(store.euroReference?.rate, 1)
    }

    @MainActor
    func testPresetReferenceCanUseAnInverseCachedRateOffline() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = RateCache(directory: directory)
        let pair = CurrencyPair(base: "EUR", quote: "KRW")
        cache.save(Rate(date: .now, base: pair.base, quote: pair.quote, rate: 1499), for: pair)
        let store = ExchangeStore(client: mockClient(), cache: cache)
        await store.loadRates(selection: CurrencySelection(base: "KRW", quotes: []))
        XCTAssertTrue(store.quotes.isEmpty)
        XCTAssertEqual(store.euroReference?.base, "KRW")
        XCTAssertEqual(store.euroReference?.rate, 1 / 1499)
    }

    func testRateDecodingUsesUTCDate() throws {
        let json = Data(#"{"date":"2026-10-16","base":"EUR","quote":"JPY","rate":173.42}"#.utf8)
        let rate = try APIDate.decoder().decode(Rate.self, from: json)
        XCTAssertEqual(rate.rate, 173.42)
        XCTAssertEqual(APIDate.string(rate.date), "2026-10-16")
        XCTAssertEqual(APIDate.calendar.component(.hour, from: rate.date), 0)
    }

    func testHistoryRequestIncludesPairRangeAndGrouping() throws {
        let now = try XCTUnwrap(APIDate.formatter().date(from: "2026-10-18"))
        let pair = CurrencyPair(base: "eur", quote: "jpy")
        let url = FrankfurterClient.historyURL(for: pair, period: .fiveYears, now: now)
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(query, ["base": "EUR", "quotes": "JPY", "from": "2021-10-18", "to": "2026-10-18", "group": "week"])
        XCTAssertEqual(url.host, "api.frankfurter.dev")
    }

    func testWidgetDeepLinkRoundTripAndValidation() throws {
        let pair = CurrencyPair(base: "EUR", quote: "USD")
        XCTAssertEqual(CurrencyPair(url: pair.url), pair)
        XCTAssertNil(CurrencyPair(url: URL(string: "currency://pair?base=../&quote=USD")!))
        XCTAssertNil(CurrencyPair(url: URL(string: "https://pair?base=EUR&quote=USD")!))
        XCTAssertNil(CurrencyPair(url: URL(string: "currency://pair?base=EUR")!))
    }

    func testCacheSeparatesPairsAndPeriods() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = RateCache(directory: directory)
        let pair = CurrencyPair(base: "EUR", quote: "JPY")
        let rate = Rate(date: .now, base: "EUR", quote: "JPY", rate: 173.42)
        cache.save(rate, for: pair)
        cache.save([rate], for: pair, period: .month)
        XCTAssertEqual(cache.latest(for: pair), rate)
        XCTAssertNil(cache.latest(for: CurrencyPair(base: "JPY", quote: "EUR")))
        XCTAssertEqual(cache.history(for: pair, period: .month), [rate])
        XCTAssertNil(cache.history(for: pair, period: .year))
    }

    func testLatestAndSortedHistoryThroughHTTPClient() async throws {
        let client = mockClient()
        let pair = CurrencyPair(base: "EUR", quote: "JPY")
        let latest = try await client.latest(for: pair)
        XCTAssertEqual(latest.rate, 173.42)
        let history = try await client.history(for: pair, period: .month)
        XCTAssertEqual(history.map(\.rate), [171.0, 173.42])
    }

    func testClientRejectsHTTPErrorAndMismatchedPair() async throws {
        for base in ["ERR", "BAD"] {
            do {
                _ = try await mockClient().latest(for: CurrencyPair(base: base, quote: "JPY"))
                XCTFail("An invalid response must throw")
            } catch is APIError { } catch { XCTFail("Unexpected error: \(error)") }
        }
    }

    func testSameCurrencyIsIdentity() async throws {
        let pair = CurrencyPair(base: "EUR", quote: "EUR")
        let rate = try await mockClient().latest(for: pair)
        let history = try await mockClient().history(for: pair, period: .year)
        XCTAssertEqual(rate.rate, 1)
        XCTAssertEqual(history.map(\.rate), [1, 1])
    }

    func testComparisonSelectionPreservesOrderAndRemovesDuplicates() {
        let selection = CurrencySelection(base: "eur", quotes: ["usd", "JPY", "USD", "invalid", "EUR"])
        XCTAssertEqual(selection.base, "EUR")
        XCTAssertEqual(selection.quotes, ["USD", "JPY", "EUR"])
        XCTAssertEqual(CurrencySelection(url: selection.url), selection)
        XCTAssertEqual(CurrencySelection(url: CurrencyPair(base: "GBP", quote: "CHF").url)?.quotes, ["CHF"])
        XCTAssertNil(CurrencySelection(url: URL(string: "currency://comparison?base=EUR&quotes=USD,../")!))
        XCTAssertNil(CurrencySelection(url: URL(string: "currency://comparison?base=EUR&quotes=")!))
        XCTAssertEqual(CurrencySelection.restoreQuotes("", legacyQuote: "JPY"), ["JPY"])
        XCTAssertEqual(CurrencySelection.restoreQuotes("USD,JPY,USD", legacyQuote: "CHF"), ["USD", "JPY"])
    }

    func testComparisonLoadsPartialResultsAndCachedFallbackInSelectionOrder() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = RateCache(directory: directory)
        let cached = Rate(date: Date(timeIntervalSince1970: 1_700_000_000), base: "EUR", quote: "ERR", rate: 4.321)
        cache.save(cached, for: CurrencyPair(base: "EUR", quote: "ERR"))
        let selection = CurrencySelection(base: "EUR", quotes: ["JPY", "ERR", "BAD", "EUR"])
        let results = await mockClient().latest(for: selection, cache: cache)
        XCTAssertEqual(results.map(\.quote), selection.quotes)
        XCTAssertEqual(results[0].rate?.rate, 173.42)
        XCTAssertFalse(results[0].isOffline)
        XCTAssertEqual(results[1].rate, cached)
        XCTAssertTrue(results[1].isOffline)
        XCTAssertNil(results[2].rate)
        XCTAssertTrue(results[2].isOffline)
        XCTAssertEqual(results[3].rate?.rate, 1)
        XCTAssertEqual(cache.latest(for: CurrencyPair(base: "EUR", quote: "JPY"))?.rate, 173.42)
    }

    func testCurrencyFormattingIncludesSymbolAndPreservesSmallRates() {
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(CurrencyDisplay.symbol(for: "EUR", locale: locale), "€")
        XCTAssertEqual(CurrencyDisplay.flag(for: "EUR"), "🇪🇺")
        XCTAssertEqual(CurrencyDisplay.flag(for: "usd"), "🇺🇸")
        XCTAssertEqual(CurrencyDisplay.flag(for: "JPY"), "🇯🇵")
        XCTAssertEqual(CurrencyDisplay.flag(for: "CHF"), "🇨🇭")
        XCTAssertEqual(CurrencyDisplay.flag(for: "XAF"), "🌐")
        XCTAssertEqual(CurrencyDisplay.flag(for: "invalid"), "🌐")
        XCTAssertEqual(CurrencyDisplay.amount(0.0000123456789, code: "USD", locale: locale), "$0.0000123456789")
        XCTAssertEqual(CurrencyDisplay.amount(1.12291234567, code: "EUR", locale: locale), "€1.12291234567")
    }

    func testWidgetLinkCarriesFractionalAmountAndKeepsLegacyLinksCompatible() {
        let selection = CurrencySelection(base: "EUR", quotes: ["USD", "JPY"])
        let link = selection.url(amount: 125.5)
        XCTAssertEqual(CurrencySelection(url: link), selection)
        XCTAssertEqual(CurrencySelection.amount(from: link), 125.5)
        XCTAssertEqual(CurrencySelection.amount(from: selection.url(amount: 0)), 0)
        XCTAssertNil(CurrencySelection.amount(from: selection.url))
        XCTAssertNil(CurrencySelection.amount(from: selection.url(amount: .infinity)))
        XCTAssertNil(CurrencySelection.amount(from: URL(string: "currency://comparison?base=EUR&quotes=USD&amount=nan")!))
    }

    func testWidgetAmountAcceptsBothDecimalSeparatorsAndRejectsInvalidValues() {
        XCTAssertEqual(ConversionAmount.parse("125,5"), 125.5)
        XCTAssertEqual(ConversionAmount.parse("125.5"), 125.5)
        XCTAssertEqual(ConversionAmount.parse(" 100 "), 100)
        XCTAssertEqual(ConversionAmount.parse("0"), 0)
        XCTAssertEqual(ConversionAmount.parse("-5,25"), -5.25)
        for text in ["", "abc", "1,2,3", "nan", "inf", "1e999"] {
            XCTAssertNil(ConversionAmount.parse(text), text)
        }
    }

    func testWidgetUsesFirstThreeCurrenciesInSavedOrder() {
        let settings = ConversionSettings(selection: CurrencySelection(base: "EUR", quotes: ["CHF", "USD", "JPY", "GBP"]), amount: 250.25)
        XCTAssertEqual(settings.widgetSelection.base, "EUR")
        XCTAssertEqual(settings.widgetSelection.quotes, ["CHF", "USD", "JPY"])
        XCTAssertEqual(settings.amount, 250.25)
        let fewer = ConversionSettings(selection: CurrencySelection(base: "USD", quotes: ["GBP"]), amount: 0)
        XCTAssertEqual(fewer.widgetSelection.quotes, ["GBP"])
    }

    func testSharedSettingsReadersSeeEditsAndEmptySelection() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("settings.json")
        let app = SharedConversionStore(url: url)
        let widget = SharedConversionStore(url: url)
        XCTAssertNil(widget.load())
        let initial = ConversionSettings(selection: CurrencySelection(base: "EUR", quotes: ["USD", "JPY", "GBP", "CHF"]), amount: 125.5)
        XCTAssertTrue(app.save(initial))
        XCTAssertEqual(widget.load(), initial)
        let edited = ConversionSettings(selection: CurrencySelection(base: "JPY", quotes: ["CHF", "EUR"]), amount: 1000)
        XCTAssertTrue(app.save(edited))
        XCTAssertEqual(widget.load()?.widgetSelection.quotes, ["CHF", "EUR"])
        XCTAssertEqual(widget.load()?.amount, 1000)
        XCTAssertEqual(widget.load()?.selection.base, "JPY")
        let empty = ConversionSettings(selection: CurrencySelection(base: "JPY", quotes: []), amount: 1000)
        XCTAssertTrue(app.save(empty))
        XCTAssertEqual(widget.load()?.widgetSelection.quotes, [])
    }

    func testQuotePersistenceDistinguishesDeletedSelectionFromLegacyDefaults() {
        XCTAssertEqual(CurrencySelection.restoreQuotes("", legacyQuote: "JPY"), ["JPY"])
        XCTAssertEqual(CurrencySelection.restoreQuotes("USD,JPY,CHF", legacyQuote: "GBP"), ["USD", "JPY", "CHF"])
        let stored = CurrencySelection.storeQuotes(["CHF", "USD", "JPY"])
        XCTAssertEqual(CurrencySelection.restoreQuotes(stored, legacyQuote: "GBP"), ["CHF", "USD", "JPY"])
        XCTAssertEqual(CurrencySelection.restoreQuotes(CurrencySelection.storeQuotes([]), legacyQuote: "GBP"), [])
    }

    private func mockClient() -> FrankfurterClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureURLProtocol.self]
        return FrankfurterClient(session: URLSession(configuration: configuration))
    }
}

private final class FixtureURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        let status = url.path.contains("ERR") ? 422 : 200
        let latest = url.path.hasSuffix("/JPY/EUR")
            ? #"{"date":"2026-10-16","base":"JPY","quote":"EUR","rate":0.0058}"#
            : #"{"date":"2026-10-16","base":"EUR","quote":"JPY","rate":173.42}"#
        let earlier = #"{"date":"2026-10-15","base":"EUR","quote":"JPY","rate":171.0}"#
        let body = url.path.hasSuffix("rates") ? "[\(latest),\(earlier)]" : latest
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
