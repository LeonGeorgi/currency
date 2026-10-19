import SwiftUI
import Charts

struct HistoryChart: View {
    @Environment(\.appAccent) private var accent
    let rates: [Rate]
    let quote: String
    let period: RatePeriod
    let startsAtZero: Bool
    @State private var selectedDate: Date?

    private var selected: Rate? {
        guard let selectedDate else { return nil }
        return rates.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }
    private var domain: ClosedRange<Double> {
        let low = rates.map(\.rate).min() ?? 0
        let high = rates.map(\.rate).max() ?? 1
        let padding = max((high - low) * 0.15, abs(low) * 0.001)
        let lowerBound = startsAtZero ? 0 : max(0, low - padding)
        return lowerBound...(high + padding)
    }
    private var change: Double? {
        guard let first = rates.first, let last = rates.last, rates.count > 1 else { return nil }
        return last.rate / first.rate - 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                if let selected {
                    Text(CurrencyDisplay.rate(selected.rate, code: quote))
                        .font(.title2.weight(.semibold)).monospacedDigit()
                    Text(selected.date, format: APIDate.displayStyle)
                        .font(.caption).foregroundStyle(.secondary)
                } else if let change {
                    Text(change, format: .percent.precision(.fractionLength(2)).sign(strategy: .always()))
                        .font(.title2.weight(.semibold)).monospacedDigit()
                        .accessibilityLabel("Veränderung im Zeitraum: \(change.formatted(.percent.precision(.fractionLength(2))))")
                    Text(period.description).font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("history-summary")
                }
            }
            .frame(height: 54, alignment: .topLeading)
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
            .frame(height: 190)
            .accessibilityLabel("Historischer Wechselkurs in \(quote)")
        }
        .padding(.vertical, 8)
        .onChange(of: rates) { selectedDate = nil }
    }
}


struct CurrencyHistoryView: View {
    let pair: CurrencyPair
    let latest: Rate?
    let amount: Double
    @State private var store = ExchangeStore()
    @State private var period: RatePeriod = .month
    @AppStorage("chartStartsAtZero") private var chartStartsAtZero = false

    var body: some View {
        Form {
            if let latest, latest.base == pair.base, latest.quote == pair.quote {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: "\(CurrencyDisplay.flag(for: pair.base)) 1 \(CurrencyDisplay.symbol(for: pair.base)) · \(pair.base)")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(CurrencyDisplay.rate(latest.rate, code: pair.quote))
                            .accessibilityIdentifier("current-exchange-rate")
                            .font(.system(.largeTitle, design: .rounded, weight: .medium))
                            .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                    }
                    .padding(.vertical, 8)
                } footer: {
                    Text("Stand: \(latest.date.formatted(APIDate.displayStyle))")
                }
            }
            if let latest, latest.base == pair.base, latest.quote == pair.quote {
                Section {
                    MentalConversionView(pair: pair, rate: latest.rate, amount: amount)
                } header: {
                    Label("Faustregel", systemImage: "lightbulb")
                }
            }
            Section {
                Picker("Zeitraum", selection: $period) {
                    ForEach(RatePeriod.allCases) { Text($0.title).accessibilityLabel($0.description).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)
                if !store.history.isEmpty {
                    HistoryChart(rates: store.history, quote: pair.quote, period: period, startsAtZero: chartStartsAtZero)
                        .listRowSeparator(.hidden)
                } else if store.loadingHistory {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 240)
                } else if store.historyError == nil {
                    ContentUnavailableView("Noch kein Verlauf", systemImage: "chart.xyaxis.line", description: Text("Versuche einen längeren Zeitraum."))
                }
                if let error = store.historyError {
                    Label(error, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.secondary)
                    Button("Erneut versuchen") { Task { await load() } }
                }
                Toggle("Bei Null beginnen", isOn: $chartStartsAtZero)
                    .accessibilityIdentifier("chart-starts-at-zero")
            } header: {
                Text("Verlauf")
            } footer: {
                Link("Tägliche Referenzkurse · Frankfurter", destination: URL(string: "https://frankfurter.dev")!)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text(verbatim: "\(CurrencyDisplay.flag(for: pair.base)) \(pair.base) → \(CurrencyDisplay.flag(for: pair.quote)) \(pair.quote)"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: period) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        await store.loadHistory(pair: pair, period: period)
    }
}
