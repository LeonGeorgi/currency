import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

enum MentalCardStyle: String, CaseIterable, Identifiable, Sendable {
    case classic, soft, color
    var id: Self { self }
    var title: String {
        switch self {
        case .classic: String(localized: "Klassisch")
        case .soft: String(localized: "Sanft")
        case .color: String(localized: "Farbig")
        }
    }
}

/// Amount-independent instructions: compensation refers to a remembered number, never an example value.
struct MentalCardStep: Equatable, Sendable {
    let symbol: String
    let instruction: String

    static func steps(for rule: MentalRule) -> [Self] {
        func word(_ value: Int) -> String {
            let formatter = NumberFormatter()
            formatter.locale = .current
            formatter.numberStyle = .spellOut
            return formatter.string(from: NSNumber(value: value)) ?? value.formatted()
        }
        func decimalShift(_ n: Int, multiplying: Bool) -> String? {
            guard MentalRule.Operation.isDecimalShift(n) else { return nil }
            let places = String(n).count - 1
            if places == 1 {
                return multiplying ? String(localized: "Komma 1 Stelle →") : String(localized: "Komma 1 Stelle ←")
            }
            return multiplying ? String(localized: "Komma \(places.formatted()) Stellen →") : String(localized: "Komma \(places.formatted()) Stellen ←")
        }
        func multiplication(_ n: Int) -> String {
            decimalShift(n, multiplying: true) ?? (n == 2 ? String(localized: "Verdoppeln") : String(localized: "Mal \(word(n))"))
        }
        if rule.operations.isEmpty {
            return [Self(symbol: "≈", instruction: String(localized: "Ungefähr gleich"))]
        }
        return rule.operations.flatMap { operation -> [Self] in
            switch operation {
            case .multiply(let n):
                return [Self(symbol: "×\(n.formatted())", instruction: multiplication(n))]
            case .divide(let n):
                let instruction = decimalShift(n, multiplying: false) ?? (n == 2 ? String(localized: "Halbieren") : n == 4 ? String(localized: "Ein Viertel nehmen") : String(localized: "Durch \(word(n)) teilen"))
                return [Self(symbol: n == 4 ? "×¼" : "÷\(n.formatted())", instruction: instruction)]
            case .percent(let p):
                return [Self(symbol: "\(p < 0 ? "−" : "+")\(abs(p))%", instruction: p < 0 ? String(localized: "\(word(abs(p))) Prozent abziehen") : String(localized: "\(word(abs(p))) Prozent dazu"))]
            case .third(let increasing):
                return [Self(symbol: increasing ? "+⅓" : "−⅓", instruction: increasing ? String(localized: "Ein Drittel dazu") : String(localized: "Ein Drittel abziehen"))]
            case .compensate(let n):
                let power = n == 3 ? 2 : n < 20 ? 10 : 100
                return [
                    Self(symbol: "×\(power)", instruction: String(localized: "Merken. \(multiplication(power))")),
                    Self(symbol: "\(n > power ? "+" : "−") \(String(localized: "Start"))", instruction: n > power ? String(localized: "Gemerkte Zahl addieren") : String(localized: "Gemerkte Zahl abziehen"))
                ]
            }
        }
    }
}

struct MentalShareCard: View {
    let rate: Rate
    let rules: MentalRules.Directions
    let accent: AppAccent
    var style: MentalCardStyle = .classic

    private var base: String { rate.base }
    private var quote: String { rate.quote }
    private var ink: Color {
        guard style == .color else { return .primary }
        let color = UIColor(accent.color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func linear(_ channel: CGFloat) -> CGFloat {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        return luminance > 0.179 ? .black : .white
    }
    private var secondaryInk: Color { style == .color ? ink : .secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(spacing: 12) {
                Text("Faustformeln für").font(.subheadline).foregroundStyle(secondaryInk)
                HStack(alignment: .top, spacing: 12) {
                    currency(base)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.subheadline).foregroundStyle(secondaryInk)
                        .padding(.top, 10)
                        .accessibilityHidden(true)
                    currency(quote)
                }
            }
            .frame(maxWidth: .infinity)

            if let forward = rules.forward {
                direction(forward, from: base, to: quote)
            }
            if let reverse = rules.reverse {
                if rules.forward != nil { Divider() }
                direction(reverse, from: quote, to: base)
            }

            Divider()
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Stand: \(rate.date.formatted(APIDate.displayStyle))")
                }
                .font(.caption2).foregroundStyle(secondaryInk)
                Spacer(minLength: 0)
                Image(accent.previewName)
                    .resizable().scaledToFit().frame(width: 32, height: 32)
                    .accessibilityLabel("App-Icon")
            }
        }
        .padding(26)
        .frame(width: 360)
        .foregroundStyle(ink)
        .background {
            RoundedRectangle(cornerRadius: 24).fill(.white)
            if style == .soft {
                RoundedRectangle(cornerRadius: 24).fill(
                    LinearGradient(colors: [accent.color.opacity(0.05), accent.color.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            } else if style == .color {
                RoundedRectangle(cornerRadius: 24).fill(accent.color)
                RoundedRectangle(cornerRadius: 24).fill(
                    LinearGradient(colors: [.clear, ink == .white ? .black.opacity(0.18) : .white.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            }
        }
    }

    private func currency(_ code: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(CurrencyDisplay.flag(for: code)).font(.system(size: 26))
                Text(CurrencyDisplay.symbol(for: code))
                    .font(.system(size: 32, weight: .medium, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            Text(Locale.current.localizedString(forCurrencyCode: code) ?? code)
                .font(.caption).foregroundStyle(secondaryInk)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private func direction(_ rule: MentalRule, from: String, to: String) -> some View {
        let steps = MentalCardStep.steps(for: rule)
        return VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: "\(CurrencyDisplay.symbol(for: from)) → \(CurrencyDisplay.symbol(for: to))")
                .font(.caption.weight(.medium)).foregroundStyle(secondaryInk)
            if steps.count <= 3 {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(steps.indices, id: \.self) { index in
                        if index > 0 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11)).foregroundStyle(secondaryInk.opacity(0.5))
                                .padding(.top, 14)
                                .accessibilityHidden(true)
                        }
                        step(steps[index]).frame(maxWidth: .infinity)
                    }
                }
            } else {
                // Rare four-step rules keep a clear reading order without squeezing their labels.
                VStack(spacing: 10) {
                    ForEach(steps.indices, id: \.self) { index in
                        if index > 0 {
                            Image(systemName: "arrow.down").font(.caption2).foregroundStyle(secondaryInk.opacity(0.5))
                                .accessibilityHidden(true)
                        }
                        step(steps[index])
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func step(_ step: MentalCardStep) -> some View {
        VStack(spacing: 7) {
            Text(step.symbol)
                .font(.custom("PatrickHand-Regular", size: 30))
                .foregroundStyle(style == .color ? ink : accent.color)
                .frame(height: 40)
                .lineLimit(1).minimumScaleFactor(0.55)
                .accessibilityHidden(true)
            Text(step.instruction)
                .font(.system(size: 11.5)).foregroundStyle(secondaryInk)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
    }

    var accessibleDescription: String {
        let names = "\(Locale.current.localizedString(forCurrencyCode: base) ?? base), \(Locale.current.localizedString(forCurrencyCode: quote) ?? quote)"
        let instructions = [(base, quote, rules.forward), (quote, base, rules.reverse)].compactMap { from, to, rule in
            rule.map { "\(from) → \(to): " + MentalCardStep.steps(for: $0).map(\.instruction).joined(separator: ", ") }
        }
        return ([String(localized: "Faustformeln für"), names] + instructions + [String(localized: "Stand: \(rate.date.formatted(APIDate.displayStyle))")]).joined(separator: ". ")
    }
}

struct MentalCardPNG: Transferable, Sendable {
    let data: Data
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
            .suggestedFileName { $0.filename }
    }
}

struct MentalSharePreview: View {
    let rate: Rate
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccent) private var accent
    @Environment(\.locale) private var locale
    @AppStorage("mentalCardStyle") private var style: MentalCardStyle = .soft
    @State private var image: UIImage?
    @State private var export: MentalCardPNG?
    @State private var description = ""
    @State private var failed = false
    @State private var noRule = false
    @State private var renderedStyle: MentalCardStyle?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Stil", selection: $style) {
                        ForEach(MentalCardStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("mental-card-style")
                    if let image, let export {
                        Image(uiImage: image)
                            .resizable().scaledToFit()
                            .accessibilityLabel(description)
                            .accessibilityValue(renderedStyle?.title ?? "")
                            .accessibilityIdentifier("mental-share-image")
                        ShareLink(item: export, preview: SharePreview(Text("Kopfrechenkarte"), image: Image(uiImage: image))) {
                            Label("Karte teilen", systemImage: "square.and.arrow.up")
                                .font(.headline).frame(maxWidth: .infinity, minHeight: 30)
                        }
                        .buttonStyle(.glassProminent).controlSize(.large)
                        .disabled(renderedStyle != style)
                        .accessibilityIdentifier("mental-share-export")
                    } else if noRule {
                        ContentUnavailableView("Keine einfache Faustregel", systemImage: "lightbulb", description: Text("Für diesen Kurs gibt es gerade keine einfache Faustregel."))
                    } else if failed {
                        ContentUnavailableView {
                            Label("Karte konnte nicht erstellt werden", systemImage: "photo")
                        } actions: {
                            Button("Erneut versuchen") { Task { await prepare() } }
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 240)
                    }
                }
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Kopfrechenkarte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("mental-share-close")
                }
            }
            .task(id: style) { await prepare() }
        }
        .tint(accent.color)
    }

    @MainActor
    private func prepare() async {
        failed = false
        noRule = false
        image = nil
        export = nil
        renderedStyle = nil
        let selectedStyle = style
        let value = rate.rate
        let rules = await Task.detached(priority: .userInitiated) { MentalRules.recommendDirections(rate: value) }.value
        guard !Task.isCancelled else { return }
        guard rules.forward != nil || rules.reverse != nil else { noRule = true; return }
        let card = MentalShareCard(rate: rate, rules: rules, accent: accent, style: selectedStyle)
        // A fixed light canvas and type size make the shared image independent of the sender's display settings.
        let renderer = ImageRenderer(content: card.environment(\.colorScheme, .light).environment(\.locale, locale).dynamicTypeSize(.large))
        renderer.scale = 3
        renderer.isOpaque = false
        guard let rendered = renderer.uiImage, let data = rendered.pngData() else { failed = true; return }
        description = card.accessibleDescription
        image = rendered
        export = MentalCardPNG(data: data, filename: "\(rate.base)-\(rate.quote)-\(APIDate.string(rate.date)).png")
        renderedStyle = selectedStyle
    }
}
