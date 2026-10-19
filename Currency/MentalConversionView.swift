import SwiftUI

struct MentalConversionView: View {
    let pair: CurrencyPair
    let rate: Double
    let amount: Double
    @State private var rules = MentalRules.Directions(forward: nil, reverse: nil)
    @State private var isLoading = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var exampleAmount: Double { amount.isFinite ? amount : 20 }
    private var reversePair: CurrencyPair { CurrencyPair(base: pair.quote, quote: pair.base) }
    private var reverseAmount: Double {
        let converted = exampleAmount * rate
        return converted.isFinite ? MentalRule.roundedForMentalMath(converted) : 20
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if dynamicTypeSize.isAccessibilitySize {
                stackedCalculations
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        calculation(rule: rules.forward, pair: pair, amount: exampleAmount, rate: rate, reverse: false, compact: true)
                        calculation(rule: rules.reverse, pair: reversePair, amount: reverseAmount, rate: 1 / rate, reverse: true, compact: true)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    stackedCalculations
                }
            }
        }
        .padding(.vertical, 4)
        .task(id: rate) { await loadRules() }
    }

    private var stackedCalculations: some View {
        VStack(alignment: .leading, spacing: 20) {
            calculation(rule: rules.forward, pair: pair, amount: exampleAmount, rate: rate, reverse: false)
            calculation(rule: rules.reverse, pair: reversePair, amount: reverseAmount, rate: 1 / rate, reverse: true)
        }
    }

    private func calculation(rule: MentalRule?, pair: CurrencyPair, amount: Double, rate: Double,
                             reverse: Bool, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: "\(pair.base) → \(pair.quote)")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if let rule {
                let example = rule.example(amount: amount, from: pair.base, rate: rate)
                MentalCalculationFlow(example: example, from: pair.base, to: pair.quote, compact: compact)
                    .accessibilityIdentifier(reverse ? "mental-calculation-reverse" : "mental-calculation")
                Text("Genau: \(CurrencyDisplay.amount(example.exactResult, code: pair.quote))")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier(reverse ? "mental-exact-result-reverse" : "mental-exact-result")
            } else {
                Text("Für diesen Kurs gibt es gerade keine einfache Faustregel.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func loadRules() async {
        let next = await Task.detached(priority: .userInitiated) {
            MentalRules.recommendDirections(rate: rate)
        }.value
        guard !Task.isCancelled else { return }
        rules = next
        isLoading = false
    }
}

/// Native text and layout; only the curved connector needs a small custom Shape.
private struct MentalCalculationFlow: View {
    @Environment(\.appAccent) private var accent
    let example: MentalRule.Example
    let from: String
    let to: String
    var compact = false
    @ScaledMetric(relativeTo: .body) private var valueHeight = 30.0
    @ScaledMetric(relativeTo: .body) private var gap = 8.0
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var amount: Double { example.amount }
    private var steps: [MentalRule.Step] { example.steps }
    private var values: [Double] { [amount] + steps.map(\.value) }

    private func isApproximate(at index: Int) -> Bool {
        index > 0 && (index == values.count - 1 || steps[index - 1].isApproximate)
    }

    var body: some View {
        Group {
            if steps.isEmpty {
                HStack(spacing: 5) {
                    Text(CurrencyDisplay.amount(amount, code: from))
                    Text("≈")
                        .font(.custom("PatrickHand-Regular", size: compact ? 23 : 25, relativeTo: .title3).weight(.semibold))
                        .foregroundStyle(accent.color)
                    Text(CurrencyDisplay.amount(amount, code: to))
                }
                .font(.custom("PatrickHand-Regular", size: compact ? 17 : 19, relativeTo: .subheadline))
                .foregroundStyle(.secondary)
            } else if dynamicTypeSize.isAccessibilitySize { accessibleLayout }
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
        HStack(alignment: .top, spacing: compact ? 6 : 8) {
            Grid(horizontalSpacing: compact ? 3 : 5, verticalSpacing: gap) {
                ForEach(values.indices, id: \.self) { index in
                    GridRow(alignment: .firstTextBaseline) {
                        Text((isApproximate(at: index) ? "≈ " : "") + number(at: index))
                            .gridColumnAlignment(.trailing)
                            .frame(height: valueHeight)
                        Text(index == 0 ? CurrencyDisplay.symbol(for: from) : index == values.count - 1 ? CurrencyDisplay.symbol(for: to) : "")
                            .gridColumnAlignment(.leading)
                            .frame(height: valueHeight)
                    }
                    .font(.custom("PatrickHand-Regular", size: compact ? 17 : 19, relativeTo: .subheadline))
                    .foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.55)
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(steps.indices, id: \.self) { index in
                    HStack(spacing: 6) {
                        ScribbleCalculationArrow(variation: index)
                            .stroke(style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(accent.color.opacity(0.45))
                            .frame(width: 16, height: valueHeight + gap)
                            .scaleEffect(x: layoutDirection == .rightToLeft ? -1 : 1)
                            .accessibilityHidden(true)
                        Text(operation(steps[index].calculation))
                            .font(.custom("PatrickHand-Regular", size: compact ? 23 : 25, relativeTo: .title3).weight(.semibold))
                            .rotationEffect(.degrees(index.isMultiple(of: 2) ? -1.2 : 0.8))
                            .foregroundStyle(accent.color)
                            .fixedSize(horizontal: true, vertical: false)
                            .accessibilityLabel(accessibleOperation(steps[index].calculation))
                    }
                    .frame(height: valueHeight + gap)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.top, valueHeight / 2)
        }
    }

    private var accessibleLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(values.indices, id: \.self) { index in
                Text(value(at: index))
                    .font(.custom("PatrickHand-Regular", size: 20, relativeTo: .body))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if index < steps.count {
                    HStack(spacing: 16) {
                        ScribbleCalculationArrow(variation: index)
                            .stroke(style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(accent.color.opacity(0.45))
                            .frame(width: 24, height: 48)
                            .accessibilityHidden(true)
                        Text(operation(steps[index].calculation))
                            .font(.custom("PatrickHand-Regular", size: 28, relativeTo: .title3).weight(.semibold))
                            .foregroundStyle(accent.color)
                    }
                    .padding(.leading, 16)
                }
            }
        }
    }

    private func number(at index: Int) -> String {
        if index == 0 || index == values.count - 1 {
            let code = index == 0 ? from : to
            return values[index].formatted(.number.precision(.fractionLength(CurrencyDisplay.fractionDigits(for: code))))
        }
        return values[index].formatted(.number.precision(.significantDigits(1...12)))
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
        case .divide(4): return "× 1/4"
        case .divide(let n): return "÷ \(n.formatted())"
        case .percent(let p): return "\(p < 0 ? "−" : "+") \(abs(p).formatted()) %"
        case .third(let increasing): return increasing ? "+ 1/3" : "− 1/3"
        case .add(let n): return "+ \(n < 0 ? "(\(number(n)))" : number(n))"
        case .subtract(let n): return "− \(n < 0 ? "(\(number(n)))" : number(n))"
        }
    }
    private func accessibleOperation(_ calculation: MentalRule.Calculation) -> String {
        switch calculation {
        case .multiply(let n): String(localized: "Mal \(n)")
        case .divide(let n): String(localized: "Geteilt durch \(n)")
        case .percent(let p): p < 0 ? String(localized: "\(abs(p)) Prozent abziehen") : String(localized: "\(p) Prozent hinzufügen")
        case .third(let increasing): increasing ? String(localized: "Ein Drittel hinzufügen") : String(localized: "Ein Drittel abziehen")
        case .add(let n): String(localized: "\(n.formatted()) addieren")
        case .subtract(let n): String(localized: "\(n.formatted()) abziehen")
        }
    }
    private var accessibleSequence: String {
        if steps.isEmpty { return "\(CurrencyDisplay.amount(amount, code: from)) ≈ \(CurrencyDisplay.amount(amount, code: to))" }
        return ([value(at: 0)] + steps.enumerated().map { "\(accessibleOperation($0.element.calculation)): \(value(at: $0.offset + 1))" }).joined(separator: ". ")
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
