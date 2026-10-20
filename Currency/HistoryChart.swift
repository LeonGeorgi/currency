import SwiftUI
import Charts

struct HistoryChart: View {
    @Environment(\.appAccent) private var accent
    let rates: [Rate]
    let latest: Rate?
    let base: String
    let quote: String
    let isLoading: Bool
    let hasError: Bool
    @Binding var period: RatePeriod
    @Binding var startsAtZero: Bool
    @State private var selectedDate: Date?

    private var selected: Rate? {
        guard let selectedDate else { return nil }
        return rates.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }
    private var current: Rate? { selected ?? latest ?? rates.last }
    private var domain: ClosedRange<Double> {
        let low = rates.map(\.rate).min() ?? 0
        let high = rates.map(\.rate).max() ?? 1
        let padding = max((high - low) * 0.15, abs(low) * 0.001)
        return (startsAtZero ? 0 : max(0, low - padding))...(high + padding)
    }
    private var change: Double? {
        guard let first = rates.first, let last = rates.last, rates.count > 1 else { return nil }
        return last.rate / first.rate - 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: "\(CurrencyDisplay.amount(1, code: base)) =")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let current {
                        Text(CurrencyDisplay.rate(current.rate, code: quote))
                            .font(.system(.largeTitle, design: .rounded, weight: .medium))
                            .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                            .accessibilityIdentifier("current-exchange-rate")
                    }
                    if let selected {
                        Text(selected.date, format: APIDate.displayStyle)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Menu("Diagrammoptionen", systemImage: "slider.horizontal.3") {
                    Toggle("Bei Null beginnen", isOn: $startsAtZero)
                        .accessibilityIdentifier("chart-starts-at-zero")
                }
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("chart-options")
            }
            VStack(alignment: .leading, spacing: 3) {
                if let change {
                    Text(change, format: .percent.precision(.fractionLength(2)).sign(strategy: .always()))
                        .font(.subheadline.weight(.medium)).foregroundStyle(accent.color)
                        .monospacedDigit()
                        .accessibilityLabel("Veränderung im Zeitraum: \(change.formatted(.percent.precision(.fractionLength(2))))")
                }
                Text(period.description).font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("history-summary")
            }
            Picker("Zeitraum", selection: $period) {
                ForEach(RatePeriod.allCases) { Text($0.title).accessibilityLabel($0.description).tag($0) }
            }
            .pickerStyle(.segmented)

            if !rates.isEmpty {
                Chart {
                    ForEach(rates) { rate in
                        AreaMark(x: .value(String(localized: "Datum"), rate.date), yStart: .value(String(localized: "Minimum"), domain.lowerBound), yEnd: .value(String(localized: "Kurs"), rate.rate))
                            .foregroundStyle(LinearGradient(colors: [accent.color.opacity(0.20), accent.color.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value(String(localized: "Datum"), rate.date), y: .value(String(localized: "Kurs"), rate.rate))
                            .foregroundStyle(accent.color)
                            .accessibilityLabel(rate.date.formatted(APIDate.displayStyle))
                            .accessibilityValue(CurrencyDisplay.rate(rate.rate, code: quote))
                    }
                    if let selected {
                        RuleMark(x: .value(String(localized: "Datum"), selected.date)).foregroundStyle(.secondary.opacity(0.5))
                        PointMark(x: .value(String(localized: "Datum"), selected.date), y: .value(String(localized: "Kurs"), selected.rate)).foregroundStyle(accent.color)
                    }
                }
                .environment(\.timeZone, APIDate.calendar.timeZone)
                .chartYScale(domain: domain)
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
                .chartXSelection(value: $selectedDate)
                .frame(height: 180)
                .accessibilityLabel("Historischer Wechselkurs in \(quote)")
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 180)
            } else if !hasError {
                ContentUnavailableView("Noch kein Verlauf", systemImage: "chart.xyaxis.line", description: Text("Versuche einen längeren Zeitraum."))
            }
        }
        .padding(.vertical, 4)
        .onChange(of: rates) { selectedDate = nil }
    }
}

struct CurrencyHistoryView: View {
    let pair: CurrencyPair
    let latest: Rate?
    let amount: Double
    @State private var store = ExchangeStore()
    @State private var period: RatePeriod = .month
    @State private var sharedRate: Rate?
    @AppStorage("chartStartsAtZero") private var chartStartsAtZero = false

    private var currentRate: Rate? {
        if let latest, latest.base == pair.base, latest.quote == pair.quote { return latest }
        return store.history.last
    }

    var body: some View {
        Form {
            Section {
                HistoryChart(rates: store.history, latest: currentRate, base: pair.base, quote: pair.quote,
                             isLoading: store.loadingHistory, hasError: store.historyError != nil,
                             period: $period, startsAtZero: $chartStartsAtZero)
                    .listRowSeparator(.hidden)
                if let error = store.historyError {
                    Label(error, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.secondary)
                    Button("Erneut versuchen") { Task { await load() } }
                }
            } footer: {
                if let currentRate {
                    Text("Stand: \(currentRate.date.formatted(APIDate.displayStyle))")
                }
            }
            if let currentRate {
                Section {
                    MentalConversionView(pair: pair, rate: currentRate.rate, amount: amount)
                } header: {
                    HStack {
                        Label("Faustregel", systemImage: "lightbulb")
                        Spacer()
                        Button("Kopfrechenkarte teilen", systemImage: "square.and.arrow.up") { sharedRate = currentRate }
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("share-mental-card")
                    }
                } footer: {
                    Link("Tägliche Referenzkurse · Frankfurter", destination: URL(string: "https://frankfurter.dev")!)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .contentMargins(.top, 12, for: .scrollContent)
        .listSectionSpacing(12)
        .navigationTitle(Locale.current.localizedString(forCurrencyCode: pair.quote) ?? pair.quote)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sharedRate) { rate in MentalSharePreview(rate: rate) }
        .task(id: period) { await load() }
        .refreshable { await load() }
    }

    private func load() async { await store.loadHistory(pair: pair, period: period) }
}
