import SwiftUI
import WidgetKit

struct ExchangeEntry: TimelineEntry, Sendable {
    let date: Date
    let selection: CurrencySelection
    let quotes: [QuoteSnapshot]
    var amount: Double? = 1
    var isPreview = false
    var isOffline: Bool { quotes.contains(where: \.isOffline) }

    static let preview = ExchangeEntry(date: .now,
        selection: CurrencySelection(base: "EUR", quotes: ["JPY", "USD", "GBP"]),
        quotes: [("JPY", 162.48), ("USD", 1.1229), ("GBP", 0.85423)].map {
            QuoteSnapshot(quote: $0.0, rate: Rate(date: .now, base: "EUR", quote: $0.0, rate: $0.1), isOffline: false)
        }, isPreview: true)
}

struct ExchangeProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExchangeEntry { .preview }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (ExchangeEntry) -> Void) {
        if context.isPreview {
            guard let settings = SharedConversionStore.shared.load() else { completion(.preview); return }
            let selection = settings.widgetSelection
            let quotes = selection.quotes.map { quote in
                QuoteSnapshot(quote: quote, rate: RateCache.shared.latest(for: CurrencyPair(base: selection.base, quote: quote)), isOffline: false)
            }
            completion(ExchangeEntry(date: .now, selection: selection, quotes: quotes, amount: settings.amount))
            return
        }
        Task { completion(await entry()) }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ExchangeEntry>) -> Void) {
        Task {
            let entry = await entry()
            let nextRefresh = Date().addingTimeInterval(entry.isOffline ? 30 * 60 : 4 * 60 * 60)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private func entry() async -> ExchangeEntry {
        guard let settings = SharedConversionStore.shared.load() else {
            return ExchangeEntry(date: .now, selection: CurrencySelection(base: "EUR", quotes: []), quotes: [])
        }
        let selection = settings.widgetSelection
        let quotes = await FrankfurterClient().latest(for: selection)
        return ExchangeEntry(date: .now, selection: selection, quotes: quotes, amount: settings.amount)
    }
}

struct ExchangeWidgetView: View {
    let entry: ExchangeEntry
    @Environment(\.widgetFamily) private var family
    private var dates: [Date] { entry.quotes.compactMap { $0.rate?.date }.sorted() }

    var body: some View {
        Group {
            if let amount = entry.amount {
                if entry.quotes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sourceAmount(amount, large: family == .systemMedium)
                        Text("Vergleichswährungen in der App auswählen")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else if family == .systemMedium {
                    mediumContent(amount: amount)
                } else {
                    smallContent(amount: amount)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Betrag prüfen", systemImage: "exclamationmark.circle").font(.headline)
                    Text("Öffne die App, um den Betrag zu korrigieren.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(Color(uiColor: .systemGroupedBackground), for: .widget)
        .widgetURL(URL(string: "currency://open")!)
    }

    private func sourceAmount(_ amount: Double, large: Bool) -> some View {
        VStack(alignment: .leading, spacing: large ? 8 : 3) {
            Text(verbatim: "\(CurrencyDisplay.flag(for: entry.selection.base)) \(entry.selection.base)")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .lineLimit(1)
            Text(CurrencyDisplay.amount(amount, code: entry.selection.base))
                .font(.system(size: large ? 34 : 26, weight: .medium, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ausgangsbetrag: \(CurrencyDisplay.amount(amount, code: entry.selection.base)) \(entry.selection.base)")
    }

    private func smallContent(amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sourceAmount(amount, large: false)
            Spacer(minLength: 0)
            VStack(spacing: 5) {
                ForEach(entry.quotes) { snapshot in
                    HStack(spacing: 5) {
                        Text(verbatim: "\(CurrencyDisplay.flag(for: snapshot.quote)) \(snapshot.quote)")
                            .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: true, vertical: false)
                        if snapshot.isOffline {
                            Image(systemName: "wifi.slash").font(.system(size: 8)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Text(convertedAmount(snapshot, amount: amount))
                            .font(.system(size: entry.quotes.count > 2 ? 11 : 14, weight: .semibold, design: .rounded))
                            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(quoteDescription(snapshot, amount: amount))
                }
            }
            Text(footer).font(.system(size: 9)).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func mediumContent(amount: Double) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    sourceAmount(amount, large: true)
                    Spacer(minLength: 0)
                    Text(footer).font(.system(size: 10)).foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(width: geometry.size.width * 0.30, alignment: .leading)

                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    if entry.quotes.count <= 2 {
                        ForEach(entry.quotes) { snapshot in
                            GridRow { quoteCard(snapshot, amount: amount) }
                        }
                    } else {
                        GridRow {
                            quoteCard(entry.quotes[0], amount: amount)
                            quoteCard(entry.quotes[1], amount: amount)
                        }
                        GridRow {
                            quoteCard(entry.quotes[2], amount: amount)
                                .gridCellColumns(2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func quoteCard(_ snapshot: QuoteSnapshot, amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(CurrencyDisplay.flag(for: snapshot.quote))
                Text(snapshot.quote).fontWeight(.semibold).foregroundStyle(.secondary)
                if snapshot.isOffline {
                    Image(systemName: "wifi.slash").foregroundStyle(.secondary)
                }
            }
            .font(.caption2).lineLimit(1)
            Text(convertedAmount(snapshot, amount: amount))
                .font(.system(size: entry.quotes.count > 2 ? 17 : 21, weight: .semibold, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(quoteDescription(snapshot, amount: amount))
    }

    private func convertedAmount(_ snapshot: QuoteSnapshot, amount: Double) -> String {
        snapshot.rate.map { CurrencyDisplay.amount(amount * $0.rate, code: snapshot.quote) } ?? "—"
    }

    private func quoteDescription(_ snapshot: QuoteSnapshot, amount: Double) -> String {
        let result = snapshot.rate.map { CurrencyDisplay.amount(amount * $0.rate, code: snapshot.quote) } ?? String(localized: "Nicht verfügbar")
        if snapshot.isOffline {
            return String(localized: "\(snapshot.quote): \(result), gespeicherter Kurs oder offline")
        }
        return String(localized: "\(snapshot.quote): \(result)")
    }

    private var footer: String {
        if entry.isPreview { return String(localized: "Beispielkurse") }
        guard let first = dates.first, let last = dates.last else { return String(localized: "Zum Laden App öffnen") }
        let date = first == last ? first.formatted(APIDate.compactStyle)
            : "\(first.formatted(APIDate.compactStyle))–\(last.formatted(APIDate.compactStyle))"
        return String(localized: "Stand: \(date)")
    }
}

@main
struct CurrencyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ExchangeWidget", provider: ExchangeProvider()) { entry in
            ExchangeWidgetView(entry: entry)
        }
        .configurationDisplayName("Wechselkurse")
        .description("Dein Betrag und die ersten drei Vergleichswährungen aus der App.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    CurrencyWidget()
} timeline: {
    ExchangeEntry.preview
}
