import SwiftUI

struct MentalConversionView: View {
    let pair: CurrencyPair
    let rate: Double
    let amount: Double
    // Recompute cached choices when the difficulty model changes.
    @AppStorage("mentalRules.v2") private var storedRules = Data()
    @State private var rule: MentalRule?
    @State private var isLoading = true

    private var exampleAmount: Double { amount.isFinite ? amount : 20 }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let rule {
                MentalCalculationFlow(rule: rule, amount: exampleAmount, from: pair.base, to: pair.quote)
                    .accessibilityIdentifier("mental-calculation")
                Text("Genau: \(CurrencyDisplay.amount(exampleAmount * rate, code: pair.quote))")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("mental-exact-result")
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text("Für diesen Kurs gibt es gerade keine einfache Faustregel.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .task(id: rate) { await loadRule() }
    }

    private func loadRule() async {
        let remembered = (try? JSONDecoder().decode([String: MentalRule].self, from: storedRules)) ?? [:]
        let previous = ScreenshotSupport.isEnabled ? nil : remembered[pair.key]
        let next = await Task.detached(priority: .userInitiated) {
            MentalRules.recommend(rate: rate, keeping: previous)
        }.value
        guard !Task.isCancelled else { return }
        rule = next
        isLoading = false
        guard !ScreenshotSupport.isEnabled, let next, remembered[pair.key] != next else { return }
        var updated = remembered
        updated[pair.key] = next
        if let encoded = try? JSONEncoder().encode(updated) { storedRules = encoded }
    }
}

/// Native text and layout; only the curved connector needs a small custom Shape.
private struct MentalCalculationFlow: View {
    let rule: MentalRule
    let amount: Double
    let from: String
    let to: String
    @ScaledMetric(relativeTo: .body) private var valueHeight = 30.0
    @ScaledMetric(relativeTo: .body) private var gap = 8.0
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var steps: [MentalRule.Step] { rule.trace(amount: amount, roundingForMentalMath: true) }
    private var values: [Double] { [amount] + steps.map(\.value) }

    private func isApproximate(at index: Int) -> Bool {
        index > 0 && (index == values.count - 1 || steps[index - 1].isApproximate)
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize { accessibleLayout }
            else {
                ViewThatFits(in: .horizontal) {
                    regularLayout
                    accessibleLayout
                }
            }
        }
        // Read the calculation in order rather than reading two visual columns.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibleSequence))
    }

    private var regularLayout: some View {
        HStack(alignment: .top, spacing: 8) {
            Grid(horizontalSpacing: 5, verticalSpacing: gap) {
                ForEach(values.indices, id: \.self) { index in
                    GridRow(alignment: .firstTextBaseline) {
                        Text(isApproximate(at: index) ? "≈" : "")
                            .frame(height: valueHeight)
                        Text(values[index].formatted(.number.precision(.significantDigits(1...12))))
                            .gridColumnAlignment(.trailing)
                            .frame(height: valueHeight)
                        Text(index == 0 ? CurrencyDisplay.symbol(for: from) : index == values.count - 1 ? CurrencyDisplay.symbol(for: to) : "")
                            .gridColumnAlignment(.leading)
                            .frame(height: valueHeight)
                    }
                    .font(.custom("PatrickHand-Regular", size: 24, relativeTo: .body))
                    .foregroundStyle(index == values.count - 1 ? Color.accentColor : Color.primary)
                    .lineLimit(1).minimumScaleFactor(0.55)
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(steps.indices, id: \.self) { index in
                    HStack(spacing: 6) {
                        ScribbleCalculationArrow(variation: index)
                            .stroke(style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(Color.accentColor.opacity(0.65))
                            .frame(width: 16, height: valueHeight + gap)
                            .scaleEffect(x: layoutDirection == .rightToLeft ? -1 : 1)
                            .accessibilityHidden(true)
                        Text(operation(steps[index].calculation))
                            .font(.custom("PatrickHand-Regular", size: 19, relativeTo: .caption))
                            .rotationEffect(.degrees(index.isMultiple(of: 2) ? -1.2 : 0.8))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .accessibilityLabel(accessibleOperation(steps[index].calculation))
                    }
                    .frame(height: valueHeight + gap)
                }
            }
            .frame(width: 78, alignment: .leading)
            .padding(.top, valueHeight / 2)
        }
    }

    private var accessibleLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(values.indices, id: \.self) { index in
                Text(value(at: index))
                    .font(.custom("PatrickHand-Regular", size: 24, relativeTo: .body))
                    .foregroundStyle(index == values.count - 1 ? Color.accentColor : Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if index < steps.count {
                    HStack(spacing: 16) {
                        ScribbleCalculationArrow(variation: index)
                            .stroke(style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(Color.accentColor.opacity(0.65))
                            .frame(width: 24, height: 48)
                            .accessibilityHidden(true)
                        Text(operation(steps[index].calculation))
                            .font(.custom("PatrickHand-Regular", size: 24, relativeTo: .body)).foregroundStyle(.secondary)
                    }
                    .padding(.leading, 16)
                }
            }
        }
    }

    private func value(at index: Int) -> String {
        let value = values[index]
        if index == 0 { return CurrencyDisplay.amount(value, code: from) }
        let formatted = index == values.count - 1 ? CurrencyDisplay.amount(value, code: to) : value.formatted(.number.precision(.significantDigits(1...12)))
        return (isApproximate(at: index) ? "≈ " : "") + formatted
    }
    private func operation(_ calculation: MentalRule.Calculation) -> String {
        func number(_ value: Double) -> String { value.formatted(.number.precision(.significantDigits(1...12))) }
        switch calculation {
        case .multiply(let n): return "× \(n.formatted())"
        case .divide(let n): return "÷ \(n.formatted())"
        case .percent(let p): return "\(p < 0 ? "−" : "+") \(abs(p).formatted()) %"
        case .add(let n): return "+ \(n < 0 ? "(\(number(n)))" : number(n))"
        case .subtract(let n): return "− \(n < 0 ? "(\(number(n)))" : number(n))"
        }
    }
    private func accessibleOperation(_ calculation: MentalRule.Calculation) -> String {
        switch calculation {
        case .multiply(let n): String(localized: "Mal \(n)")
        case .divide(let n): String(localized: "Geteilt durch \(n)")
        case .percent(let p): p < 0 ? String(localized: "\(abs(p)) Prozent abziehen") : String(localized: "\(p) Prozent hinzufügen")
        case .add(let n): String(localized: "\(n.formatted()) addieren")
        case .subtract(let n): String(localized: "\(n.formatted()) abziehen")
        }
    }
    private var accessibleSequence: String {
        ([value(at: 0)] + steps.enumerated().map { "\(accessibleOperation($0.element.calculation)): \(value(at: $0.offset + 1))" }).joined(separator: ". ")
    }
}

/// A single pen stroke with a small, open arrowhead aligned to the curve.
private struct ScribbleCalculationArrow: Shape {
    var variation: Int

    func path(in rect: CGRect) -> Path {
        let bend = CGFloat(variation.isMultiple(of: 2) ? 0.94 : 1.0)
        let tip = CGPoint(x: 2, y: rect.height - 4)
        let control = CGPoint(x: rect.width * bend, y: rect.height * 0.66)
        let dx = control.x - tip.x
        let dy = control.y - tip.y
        let length = hypot(dx, dy)
        let backwards = CGVector(dx: dx / length, dy: dy / length)
        let headLength = min(rect.height * 0.17, 7)
        let headWidth = headLength * 0.48
        let upperWing = CGPoint(x: tip.x + backwards.dx * headLength + backwards.dy * headWidth,
                                y: tip.y + backwards.dy * headLength - backwards.dx * headWidth)
        let outerWing = CGPoint(x: tip.x + backwards.dx * headLength - backwards.dy * headWidth,
                                y: tip.y + backwards.dy * headLength + backwards.dx * headWidth)
        var path = Path()
        path.move(to: CGPoint(x: 2, y: 4))
        path.addCurve(to: tip,
                      control1: CGPoint(x: rect.width * bend, y: rect.height * 0.24),
                      control2: control)
        path.move(to: upperWing)
        path.addLine(to: tip)
        path.addLine(to: outerWing)
        return path
    }
}
