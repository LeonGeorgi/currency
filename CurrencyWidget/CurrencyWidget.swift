import SwiftUI
import WidgetKit
import AppIntents

struct WidgetAmountIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Wechselkurse"
    static let description = IntentDescription("Eigener Betrag mit den ersten drei Vergleichswährungen aus der App.")

    @Parameter(title: "Betrag", default: "1", inputOptions: .init(keyboardType: .numbersAndPunctuation, capitalizationType: .none, autocorrect: false))
    var amount: String
}

struct ExchangeEntry: TimelineEntry, Sendable {
    let date: Date
    let selection: CurrencySelection
    let quotes: [QuoteSnapshot]
    var amount: Double? = 1
    var isPreview = false
    var accent: AppAccent = .original
    var isOffline: Bool { quotes.contains(where: \.isOffline) }

    static let preview = ExchangeEntry(date: .now,
        selection: CurrencySelection(base: "EUR", quotes: ["JPY", "USD", "GBP"]),
        quotes: [("JPY", 162.48), ("USD", 1.1229), ("GBP", 0.85423)].map {
            QuoteSnapshot(quote: $0.0, rate: Rate(date: .now, base: "EUR", quote: $0.0, rate: $0.1), isOffline: false)
        }, isPreview: true)
}

struct ExchangeProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ExchangeEntry { .preview }

    func snapshot(for configuration: WidgetAmountIntent, in context: Context) async -> ExchangeEntry {
        if context.isPreview {
            let amount = ConversionAmount.parse(configuration.amount)
            guard let settings = SharedConversionStore.shared.load() else {
                var preview = ExchangeEntry.preview
                preview.amount = amount
                return preview
            }
            let selection = settings.widgetSelection
            let quotes = selection.quotes.map { quote in
                QuoteSnapshot(quote: quote, rate: RateCache.shared.latest(for: CurrencyPair(base: selection.base, quote: quote)), isOffline: false)
            }
            return ExchangeEntry(date: .now, selection: selection, quotes: quotes, amount: amount, accent: settings.accent)
        }
        return await entry(for: configuration)
    }

    func timeline(for configuration: WidgetAmountIntent, in context: Context) async -> Timeline<ExchangeEntry> {
        let entry = await entry(for: configuration)
        let nextRefresh = Date().addingTimeInterval(entry.isOffline ? 30 * 60 : 4 * 60 * 60)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func entry(for configuration: WidgetAmountIntent) async -> ExchangeEntry {
        let amount = ConversionAmount.parse(configuration.amount)
        guard let settings = SharedConversionStore.shared.load() else {
            return ExchangeEntry(date: .now, selection: CurrencySelection(base: "EUR", quotes: []), quotes: [], amount: amount)
        }
        let selection = settings.widgetSelection
        guard amount != nil else {
            return ExchangeEntry(date: .now, selection: selection, quotes: [], amount: nil, accent: settings.accent)
        }
        let quotes = await FrankfurterClient().latest(for: selection)
        return ExchangeEntry(date: .now, selection: selection, quotes: quotes, amount: amount, accent: settings.accent)
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
                        sourceAmount(amount)
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
                    Text("Ändere den Betrag über „Widget bearbeiten“.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .tint(entry.accent.color)
        .containerBackground(Color(uiColor: .systemGroupedBackground), for: .widget)
        .widgetURL(URL(string: "currency://open")!)
    }

    private func sourceAmount(_ amount: Double) -> some View {
        HStack(spacing: 6) {
            Text(verbatim: "\(CurrencyDisplay.flag(for: entry.selection.base)) \(entry.selection.base)")
                .font(.caption2.weight(.medium))
            Text(CurrencyDisplay.amount(amount, code: entry.selection.base))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ausgangsbetrag: \(CurrencyDisplay.amount(amount, code: entry.selection.base)) \(entry.selection.base)")
    }

    private func smallContent(amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            sourceAmount(amount)
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                ForEach(entry.quotes) { snapshot in
                    quoteRow(snapshot, amount: amount, compact: true)
                }
            }
            Spacer(minLength: 0)
            Text(footer).font(.caption2).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func mediumContent(amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                sourceAmount(amount)
                Spacer(minLength: 0)
                Text(footer).font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    ForEach(entry.quotes) { snapshot in
                        quoteRow(snapshot, amount: amount, compact: false)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(entry.quotes) { snapshot in
                        quoteRow(snapshot, amount: amount, compact: false)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func quoteRow(_ snapshot: QuoteSnapshot, amount: Double, compact: Bool) -> some View {
        HStack(spacing: compact ? 7 : 6) {
            Text(CurrencyDisplay.flag(for: snapshot.quote))
                .font(.system(size: compact ? 23 : 22))
                .frame(width: compact ? 28 : 26)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(snapshot.quote)
                    if snapshot.isOffline {
                        Image(systemName: "wifi.slash")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                Text(convertedAmount(snapshot, amount: amount))
                    .font(.system(size: compact ? 14 : 17, weight: .medium, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        AppIntentConfiguration(kind: "ExchangeWidget", intent: WidgetAmountIntent.self, provider: ExchangeProvider()) { entry in
            ExchangeWidgetView(entry: entry)
        }
        .configurationDisplayName("Wechselkurse")
        .description("Eigener Betrag mit den ersten drei Vergleichswährungen aus der App.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    CurrencyWidget()
} timeline: {
    ExchangeEntry.preview
}
