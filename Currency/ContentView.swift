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
    @ScaledMetric(relativeTo: .largeTitle) private var amountFontSize = 50
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
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    amountPresets
                        .padding(.horizontal, -16)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
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
                        comparisonRow(quote)
                            .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 4))
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 48 }
                    }
                    .onMove(perform: moveQuotes)
                    .onDelete(perform: deleteQuotes)
                } header: {
                    HStack {
                        Text("Vergleiche")
                        Spacer()
                        Button("Währungen auswählen", systemImage: "plus") {
                            editingAmount = false
                            picker = .comparisons
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .textCase(nil)
                } footer: {
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
                            .font(.caption).foregroundStyle(Color(uiColor: .secondaryLabel))
                        }
                        if store.quotes.contains(where: \.isOffline) {
                            Button("Kurse erneut laden", systemImage: "arrow.clockwise") {
                                Task { await store.loadRates(selection: selection) }
                            }
                            .font(.subheadline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(12)
            .contentMargins(.top, 0, for: .scrollContent)
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
                        Button("Erscheinungsbild", systemImage: "paintpalette") { showingSettings = true }
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
            .sheet(isPresented: $showingInfo) {
                NavigationStack {
                    InfoView()
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { showingInfo = false } } }
                }
            }
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
        VStack(spacing: 4) {
            Button {
                editingAmount = false
                picker = .base
            } label: {
                HStack(spacing: 8) {
                    Text(verbatim: "\(CurrencyDisplay.flag(for: base)) \(currencyName(base))")
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Image(systemName: "chevron.down").font(.caption2.weight(.medium))
                }
                .font(.callout.weight(.medium))
                .foregroundStyle(accent.color)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Von: \(base). Währung auswählen")

            VStack(spacing: 6) {
                ZStack {
                    TextField("Betrag", value: $amount, format: .number.grouping(.never).precision(.significantDigits(1...16)))
                        .multilineTextAlignment(.center)
                        .keyboardType(.decimalPad)
                        .focused($editingAmount)
                        .opacity(editingAmount ? 1 : 0)
                        .accessibilityHidden(!editingAmount)
                        .accessibilityLabel("Betrag in \(base)")
                        .accessibilityIdentifier("amount-input")
                    Button {
                        editingAmount = true
                    } label: {
                        HStack(spacing: 8) {
                            // Balance the pencil's width so the amount itself stays centered.
                            Image(systemName: "pencil")
                                .font(.body.weight(.medium))
                                .hidden()
                                .accessibilityHidden(true)
                            Text(CurrencyDisplay.amount(amount, code: base))
                                .foregroundStyle(Color.primary)
                            Image(systemName: "pencil")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.tint)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Betrag bearbeiten")
                    .accessibilityValue(CurrencyDisplay.amount(amount, code: base))
                    .accessibilityIdentifier("edit-amount")
                    .opacity(editingAmount ? 0 : 1)
                    .allowsHitTesting(!editingAmount)
                    .accessibilityHidden(editingAmount)
                }
                .frame(minHeight: 44)
                .font(.system(size: amountFontSize, weight: .medium, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private var amountPresets: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(presetAmounts, id: \.self) { preset in
                        Button {
                            editingAmount = false
                            amount = preset
                        } label: {
                            Text(preset, format: .currency(code: base).precision(.fractionLength(0...CurrencyDisplay.fractionDigits(for: base))))
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .fixedSize()
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                        .tint(amount == preset ? accent.color : Color.primary)
                        .accessibilityAddTraits(amount == preset ? [.isSelected] : [])
                        .accessibilityHint("Als Betrag verwenden")
                        .accessibilityIdentifier("amount-preset-\(preset)")
                        .id(preset)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
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

    private func comparisonRow(_ quote: String) -> some View {
        let snapshot = store.quotes.first { $0.quote == quote }
        return HStack(spacing: 2) {
            if editMode.isEditing {
                comparisonContent(quote, snapshot: snapshot)
            } else {
                Button {
                    navigationPath.append(CurrencyPair(base: base, quote: quote))
                } label: {
                    comparisonContent(quote, snapshot: snapshot)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Als Ausgangswährung verwenden", systemImage: "scope") { makePrimary(quote) }
                }
                .accessibilityIdentifier("comparison-\(quote)")
                .accessibilityLabel("\(quote): \(snapshot?.rate.map { CurrencyDisplay.amount(amount * $0.rate, code: quote) } ?? String(localized: "Nicht verfügbar")). Verlauf anzeigen")
                Button {
                    editingAmount = false
                    makePrimary(quote)
                } label: {
                    Image(systemName: "scope").font(.body)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(quote) zur Hauptwährung machen")
                .accessibilityIdentifier("make-primary-\(quote)")
            }
        }
        .frame(minHeight: 60)
    }

    private func comparisonContent(_ quote: String, snapshot: QuoteSnapshot?) -> some View {
        HStack(spacing: 10) {
            Text(CurrencyDisplay.flag(for: quote)).font(.system(size: 25)).accessibilityHidden(true)
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 6) {
                        comparisonLabel(quote)
                        comparisonAmount(quote, snapshot: snapshot)
                    }
                } else {
                    HStack(spacing: 8) {
                        comparisonLabel(quote)
                        Spacer(minLength: 4)
                        comparisonAmount(quote, snapshot: snapshot)
                            .layoutPriority(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }

    private func comparisonLabel(_ quote: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(currencyName(quote)).font(.subheadline).lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            Text(quote).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func comparisonAmount(_ quote: String, snapshot: QuoteSnapshot?) -> some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
            if let rate = snapshot?.rate, rate.base == base {
                Text(CurrencyDisplay.amount(amount * rate.rate, code: quote))
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
            } else if store.loadingRate {
                ProgressView().frame(height: 27)
            } else {
                Text("Nicht verfügbar").font(.subheadline).foregroundStyle(.secondary)
            }
            if snapshot?.isOffline == true {
                Label(snapshot?.rate == nil ? String(localized: "Konnte nicht geladen werden") : String(localized: "Gespeicherter Kurs"), systemImage: "wifi.slash")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
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
        editingAmount = false
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

struct InfoView: View {
    var body: some View {
        Form {
            Section("Datenquelle") {
                Text("Frankfurter stellt tägliche Referenzkurse aus offiziellen Quellen bereit. An Wochenenden und Feiertagen kann der zuletzt veröffentlichte Kurs angezeigt werden.")
                Link("Frankfurter API", destination: URL(string: "https://frankfurter.dev")!)
                Text("Die Kurse dienen der Orientierung. Tatsächliche Umrechnungskurse können durch Gebühren und Aufschläge abweichen.").foregroundStyle(.secondary)
            }
            Section("Homescreen-Widget") {
                Text("Halte den Homescreen gedrückt und wähle Bearbeiten → Widget hinzufügen → Devisen. Das Widget übernimmt die Hauptwährung und die ersten drei Vergleichswährungen aus der App. Deinen eigenen Betrag legst du über „Widget bearbeiten“ fest.")
                Text("Über Bearbeiten kannst du die Vergleichswährungen verschieben und löschen. Ihre Reihenfolge bestimmt die Anzeige im Widget. Tippe auf das Widget, um die App zu öffnen. iOS bestimmt den genauen Zeitpunkt der Aktualisierung.")
            }
            Section("Offline") {
                Text("Zuletzt geladene Kurse und Zeitreihen bleiben auf diesem Gerät gespeichert. Schlägt eine Aktualisierung fehl, werden gespeicherte Daten entsprechend gekennzeichnet.")
            }
        }
        .navigationTitle("Über Devisen")
        .navigationBarTitleDisplayMode(.inline)
    }
}
