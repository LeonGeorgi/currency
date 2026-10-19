import SwiftUI
import WidgetKit

struct ContentView: View {
    @AppStorage("baseCurrency") private var base = "EUR"
    @AppStorage("quoteCurrency") private var legacyQuote = "JPY"
    @AppStorage("quoteCurrencies") private var storedQuotes = ""
    @AppStorage("conversionAmount") private var amount = 1.0
    @State private var editMode = EditMode.inactive
    @State private var navigationPath: [CurrencyPair] = []
    @State private var store = ExchangeStore()
    @State private var picker: CurrencyPickerKind?
    @State private var showingInfo = false
    @State private var showingSettings = false
    @Environment(\.appAccent) private var accent
    @ScaledMetric(relativeTo: .largeTitle) private var amountFontSize = 60
    @FocusState private var editingAmount: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var quotes: [String] { CurrencySelection.restoreQuotes(storedQuotes, legacyQuote: legacyQuote) }
    private var selection: CurrencySelection { CurrencySelection(base: base, quotes: quotes) }
    private var sharedSettings: ConversionSettings { ConversionSettings(selection: selection, amount: amount, accent: accent) }
    private var rateDates: [Date] { store.quotes.compactMap { $0.rate?.date }.sorted() }
    private var presetAmounts: [Double] {
        let reference = store.euroReference
        let units = reference?.base == base ? reference.map { 1 / $0.rate } : nil
        return ConversionAmount.presets(for: base, unitsPerEuro: base == "EUR" ? 1 : units)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section {
                    primaryCurrency
                        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listSectionSeparator(.hidden)

                Section {
                    if quotes.isEmpty {
                        ContentUnavailableView("Deine Vergleiche", systemImage: "plus.circle", description: Text("Füge über das Plus eine Währung hinzu."))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    ForEach(quotes, id: \.self) { quote in
                        comparisonCard(quote)
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 12, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .onMove(perform: moveQuotes)
                    .onDelete(perform: deleteQuotes)
                } header: {
                    HStack {
                        Text("Vergleiche").font(.title3.weight(.semibold)).foregroundStyle(Color.primary)
                        Spacer()
                        Button("Währungen auswählen", systemImage: "plus") {
                            editingAmount = false
                            picker = .comparisons
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .textCase(nil)
                    .padding(.bottom, 8)
                }
                .listSectionSeparator(.hidden)

                Section {
                    VStack(spacing: 12) {
                        if let first = rateDates.first, let last = rateDates.last {
                            Label {
                                if first == last {
                                    Text("Stand: \(first.formatted(APIDate.displayStyle))")
                                } else {
                                    Text("Stand je Währung: \(first.formatted(APIDate.displayStyle)) – \(last.formatted(APIDate.displayStyle))")
                                }
                            } icon: {
                                Image(systemName: "clock")
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        if store.quotes.contains(where: \.isOffline) {
                            Button("Kurse erneut laden", systemImage: "arrow.clockwise") {
                                Task { await store.loadRates(selection: selection) }
                            }
                            .font(.subheadline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .listSectionSeparator(.hidden)
            }
            .listStyle(.plain)
            .environment(\.editMode, $editMode)
            .listRowSpacing(0)
            .scrollContentBackground(.hidden)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Währungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton().environment(\.editMode, $editMode)
                        .accessibilityIdentifier("edit-currencies")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Mehr", systemImage: "ellipsis") {
                        Button("Einstellungen", systemImage: "gearshape") { showingSettings = true }
                            .accessibilityIdentifier("open-settings")
                        Button("Aktualisieren", systemImage: "arrow.clockwise") { Task { await refresh() } }
                        Button("Über Devisen", systemImage: "info.circle") { showingInfo = true }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { editingAmount = false }
                }
            }
            .navigationDestination(for: CurrencyPair.self) { pair in
                CurrencyHistoryView(pair: pair, latest: store.quotes.first { $0.quote == pair.quote }?.rate, amount: amount)
            }
            .refreshable { await refresh() }
            .sheet(item: $picker) { kind in
                switch kind {
                case .base:
                    CurrencyPicker(currencies: store.currencies, selection: base) { currency in
                        if quotes.contains(currency.code) { makePrimary(currency.code) }
                        else { base = currency.code }
                    }
                case .comparisons:
                    ComparisonPicker(currencies: store.currencies.filter { $0.code != base }, initialSelection: quotes.filter { $0 != base }) { values in
                        storedQuotes = CurrencySelection.storeQuotes(values)
                    }
                }
            }
            .sheet(isPresented: $showingInfo) { InfoView() }
            .sheet(isPresented: $showingSettings) { AppearanceSettingsView() }
            .task { await store.loadCurrencies() }
            .task(id: selection) { await store.loadRates(selection: selection) }
            .onChange(of: sharedSettings, initial: true) { _, settings in
                guard !ScreenshotSupport.isEnabled else { return }
                SharedConversionStore.shared.save(settings)
            }
            .task(id: sharedSettings) {
                guard !ScreenshotSupport.isEnabled else { return }
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                WidgetCenter.shared.reloadTimelines(ofKind: "ExchangeWidget")
            }
            .onOpenURL { url in
                guard url.scheme == "currency" else { return }
                // Widgets only open the app. Cached links must never replace its saved selection.
                navigationPath.removeAll()
                editingAmount = false
            }
            .onChange(of: editMode) { _, _ in editingAmount = false }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await refresh() }
                } else if !ScreenshotSupport.isEnabled {
                    SharedConversionStore.shared.save(sharedSettings)
                    WidgetCenter.shared.reloadTimelines(ofKind: "ExchangeWidget")
                }
            }
        }
    }

    private var primaryCurrency: some View {
        VStack(spacing: 16) {
            Button {
                editingAmount = false
                picker = .base
            } label: {
                HStack(spacing: 8) {
                    Text(verbatim: "\(CurrencyDisplay.flag(for: base)) \(base)").fontWeight(.semibold)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.semibold))
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .accessibilityLabel("Von: \(base). Währung auswählen")

            VStack(spacing: 6) {
                TextField("Betrag", value: $amount, format: .currency(code: base).precision(.significantDigits(1...12)))
                    .font(.system(size: amountFontSize, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .focused($editingAmount)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .accessibilityLabel("Betrag in \(base)")
                Text(currencyName(base)).font(.subheadline).foregroundStyle(.secondary)
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(presetAmounts, id: \.self) { preset in
                            Button {
                                editingAmount = false
                                amount = preset
                            } label: {
                                Text(CurrencyDisplay.amount(preset, code: base))
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .fixedSize()
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .controlSize(.large)
                            .tint(amount == preset ? accent.color : Color.primary)
                            .accessibilityAddTraits(amount == preset ? [.isSelected] : [])
                            .accessibilityHint("Als Betrag verwenden")
                            .accessibilityIdentifier("amount-preset-\(preset)")
                            .id(preset)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("amount-presets")
                .onAppear {
                    if presetAmounts.contains(amount) { proxy.scrollTo(amount, anchor: .center) }
                }
                .onChange(of: base) { _, _ in
                    if let first = presetAmounts.first { proxy.scrollTo(first, anchor: .leading) }
                }
                .onChange(of: presetAmounts) { _, values in
                    if let target = values.contains(amount) ? amount : values.first {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }
        }
        .padding(.vertical, 20)
    }

    private func comparisonCard(_ quote: String) -> some View {
        let snapshot = store.quotes.first { $0.quote == quote }
        return HStack(spacing: 16) {
            if editMode.isEditing {
                comparisonContent(quote, snapshot: snapshot)
            } else {
                Button {
                    navigationPath.append(CurrencyPair(base: base, quote: quote))
                } label: {
                    comparisonContent(quote, snapshot: snapshot)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("comparison-\(quote)")
                .accessibilityLabel("\(quote): \(snapshot?.rate.map { CurrencyDisplay.amount(amount * $0.rate, code: quote) } ?? String(localized: "Nicht verfügbar")). Verlauf anzeigen")
                Button {
                    editingAmount = false
                    makePrimary(quote)
                } label: {
                    Image(systemName: "scope").font(.subheadline.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("\(quote) zur Hauptwährung machen")
            }
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
    }

    private func comparisonContent(_ quote: String, snapshot: QuoteSnapshot?) -> some View {
        HStack(spacing: 14) {
            Text(CurrencyDisplay.flag(for: quote)).font(.system(size: 32)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(quote).font(.subheadline.weight(.semibold))
                        Text(currencyName(quote)).font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(quote).font(.subheadline.weight(.semibold))
                        Text(currencyName(quote)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                if let rate = snapshot?.rate, rate.base == base {
                    Text(CurrencyDisplay.amount(amount * rate.rate, code: quote))
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                } else if store.loadingRate {
                    ProgressView().frame(height: 27)
                } else {
                    Text("Nicht verfügbar").foregroundStyle(.secondary)
                }
                if snapshot?.isOffline == true {
                    Label(snapshot?.rate == nil ? String(localized: "Konnte nicht geladen werden") : String(localized: "Gespeicherter Kurs"), systemImage: "wifi.slash")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    private func moveQuotes(from offsets: IndexSet, to destination: Int) {
        var values = quotes
        values.move(fromOffsets: offsets, toOffset: destination)
        storedQuotes = CurrencySelection.storeQuotes(values)
    }

    private func deleteQuotes(at offsets: IndexSet) {
        var values = quotes
        values.remove(atOffsets: offsets)
        storedQuotes = CurrencySelection.storeQuotes(values)
    }

    private func makePrimary(_ quote: String) {
        // Replace the promoted currency with the previous base, retaining all other comparisons.
        let nextQuotes = quotes.map { $0 == quote ? base : $0 }
        storedQuotes = CurrencySelection.storeQuotes(nextQuotes)
        base = quote
    }

    private func currencyName(_ code: String) -> String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }

    private func refresh() async {
        await store.loadRates(selection: selection)
    }

}

private enum CurrencyPickerKind: String, Identifiable {
    case base, comparisons
    var id: Self { self }
}

struct ComparisonPicker: View {
    @Environment(\.appAccent) private var accent
    let currencies: [Currency]
    let onSave: ([String]) -> Void
    @State private var selected: [String]
    @State private var search = ""
    @Environment(\.dismiss) private var dismiss

    init(currencies: [Currency], initialSelection: [String], onSave: @escaping ([String]) -> Void) {
        self.currencies = currencies
        self.onSave = onSave
        _selected = State(initialValue: initialSelection)
    }

    private var filtered: [Currency] {
        // Keep saved currencies visible even if the currency catalog is unavailable offline.
        let missing = selected.filter { code in !currencies.contains { $0.code == code } }
            .map { Currency(code: $0, name: $0) }
        return (currencies + missing).filter {
            search.isEmpty || $0.title.localizedStandardContains(search) || $0.name.localizedStandardContains(search)
        }.sorted { $0.code < $1.code }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { currency in
                Button {
                    if selected.contains(currency.code) {
                        selected.removeAll { $0 == currency.code }
                    } else {
                        selected.append(currency.code)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(verbatim: "\(CurrencyDisplay.flag(for: currency.code)) \(currency.code) · \(CurrencyDisplay.symbol(for: currency.code))")
                                .fontWeight(.semibold)
                            Text(currency.localizedName).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selected.contains(currency.code) {
                            Image(systemName: "checkmark").foregroundStyle(accent.color)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected.contains(currency.code) ? [.isSelected] : [])
            }
            .overlay { if filtered.isEmpty { ContentUnavailableView.search(text: search) } }
            .searchable(text: $search, prompt: "Name oder Währungscode")
            .navigationTitle("Währungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { onSave(selected); dismiss() }
                }
            }
        }
    }
}

struct CurrencyPicker: View {
    let currencies: [Currency]
    let selection: String
    let onSelect: (Currency) -> Void
    @State private var search = ""
    @Environment(\.dismiss) private var dismiss
    private var filtered: [Currency] {
        currencies.filter { search.isEmpty || $0.title.localizedStandardContains(search) || $0.name.localizedStandardContains(search) }
            .sorted { $0.code < $1.code }
    }
    var body: some View {
        NavigationStack {
            List(filtered) { currency in
                Button {
                    onSelect(currency)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(verbatim: "\(CurrencyDisplay.flag(for: currency.code)) \(currency.code) · \(CurrencyDisplay.symbol(for: currency.code))").fontWeight(.semibold).foregroundStyle(.primary)
                            Text(currency.localizedName).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if currency.code == selection { Image(systemName: "checkmark") }
                    }
                }
            }
            .overlay { if filtered.isEmpty { ContentUnavailableView.search(text: search) } }
            .searchable(text: $search, prompt: "Name oder Währungscode")
            .navigationTitle("Währung auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
    }
}

private struct InfoView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Datenquelle") {
                    Text("Frankfurter stellt tägliche Referenzkurse aus offiziellen Quellen bereit. An Wochenenden und Feiertagen kann der zuletzt veröffentlichte Kurs angezeigt werden.")
                    Link("Frankfurter API", destination: URL(string: "https://frankfurter.dev")!)
                    Text("Die Kurse dienen der Orientierung. Tatsächliche Umrechnungskurse können durch Gebühren und Aufschläge abweichen.").foregroundStyle(.secondary)
                }
                Section("Homescreen-Widget") {
                    Text("Halte den Homescreen gedrückt und wähle Bearbeiten → Widget hinzufügen → Devisen. Das Widget übernimmt Betrag, Hauptwährung und die ersten drei Vergleichswährungen aus der App.")
                    Text("Über Bearbeiten kannst du die Vergleichswährungen verschieben und löschen. Ihre Reihenfolge bestimmt die Anzeige im Widget. Tippe auf das Widget, um die App zu öffnen. iOS bestimmt den genauen Zeitpunkt der Aktualisierung.")
                }
                Section("Offline") {
                    Text("Zuletzt geladene Kurse und Zeitreihen bleiben auf diesem Gerät gespeichert. Schlägt eine Aktualisierung fehl, werden gespeicherte Daten entsprechend gekennzeichnet.")
                }
            }
            .navigationTitle("Über Devisen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }
}
