import Foundation

/// Relative effort weights and search vocabulary explored in the offline experiment.
/// Scores rank procedures; they do not predict human response times.
struct MentalRule: Codable, Hashable, Sendable {
    enum Operation: Codable, Hashable, Sendable {
        case multiply(Int), divide(Int), percent(Int), compensate(Int)

        var factor: Double {
            switch self {
            case .multiply(let n), .compensate(let n): Double(n)
            case .divide(let n): 1 / Double(n)
            case .percent(let p): 1 + Double(p) / 100
            }
        }
        var actions: Int {
            switch self {
            case .compensate: 2
            case .percent(let p): switch abs(p) { case 10, 50: 2; case 15: 4; default: 3 }
            default: 1
            }
        }
        var retained: Int {
            switch self { case .percent(let p): abs(p) == 15 ? 3 : 2; case .compensate: 2; default: 1 }
        }
        var effort: Double {
            switch self {
            case .multiply(let n): n == 2 || Self.isDecimalShift(n) ? 1 : [5, 9].contains(n) ? 3 : n <= 9 ? 2 : 4
            case .divide(let n): n == 2 || Self.isDecimalShift(n) ? 1 : n == 4 ? 3 : n == 5 ? 4 : [3, 6].contains(n) ? 5 : [7, 8, 9].contains(n) ? 6 : 7
            case .compensate: 2.5
            case .percent: Double(actions) + Double(retained - 1) * 0.5
            }
        }
        var isScale: Bool {
            switch self { case .multiply(let n), .divide(let n): Self.isDecimalShift(n); default: false }
        }
        static func isDecimalShift(_ n: Int) -> Bool {
            guard n >= 10 else { return false }
            var value = n
            while value.isMultiple(of: 10) { value /= 10 }
            return value == 1
        }
        var isSimple: Bool {
            switch self {
            case .multiply(let n): (2...9).contains(n) || Self.isDecimalShift(n)
            case .divide(let n): n == 2 || Self.isDecimalShift(n)
            case .percent(let p): [5, 10, 15, 20, 25, 50, -5, -10, -15, -20, -25].contains(p)
            case .compensate(let n): [3, 9, 11, 99, 101].contains(n)
            }
        }
    }

    enum Calculation: Equatable, Sendable {
        case multiply(Int), divide(Int), percent(Int), add(Double), subtract(Double)

        func apply(to value: Double) -> Double {
            switch self {
            case .multiply(let n): value * Double(n)
            case .divide(let n): value / Double(n)
            case .percent(let p): value * (1 + Double(p) / 100)
            case .add(let n): value + n
            case .subtract(let n): value - n
            }
        }
    }
    struct Step: Equatable, Sendable {
        let calculation: Calculation
        let value: Double
        let isApproximate: Bool
    }

    let operations: [Operation]
    var factor: Double { operations.reduce(1) { $0 * $1.factor } }
    var effort: Double { operations.reduce(0) { $0 + $1.effort } }
    var actions: Int { operations.reduce(0) { $0 + $1.actions } }
    var retained: Int { operations.map(\.retained).max() ?? 1 }
    var displayedSteps: Int {
        operations.reduce(0) { count, operation in
            if case .compensate = operation { count + 2 } else { count + 1 }
        }
    }
    func error(at rate: Double) -> Double { factor / rate - 1 }
    var isSimple: Bool {
        operations.allSatisfy(\.isSimple) && actions <= 4 && effort <= 6 && displayedSteps <= 4 &&
        operations.filter { $0 == .divide(2) }.count <= 2 && operations.filter { !$0.isScale }.count <= 3 &&
        operations.filter { if case .percent = $0 { true } else { false } }.count <= 1
    }

    /// Keep examples compact without rounding small currency amounts down to zero.
    static func roundedForMentalMath(_ value: Double) -> Double {
        guard value.isFinite, value != 0 else { return value }
        let exponent = floor(log10(abs(value)))
        for digits in 1...3 {
            let unit = pow(10, exponent - Double(digits) + 1)
            guard unit.isFinite, unit > 0 else { continue }
            let rounded = (value / unit).rounded() * unit
            guard rounded.isFinite, rounded != 0 else { continue }
            if digits == 3 || abs(rounded / value - 1) <= 0.01 + 1e-12 { return rounded }
        }
        return value
    }

    func trace(amount: Double, roundingForMentalMath: Bool = false) -> [Step] {
        var value = amount
        var isApproximate = false
        var result: [Step] = []
        for operation in operations {
            let calculations: [Calculation]
            switch operation {
            case .multiply(let n): calculations = [.multiply(n)]
            case .divide(let n): calculations = [.divide(n)]
            case .percent(let p): calculations = [.percent(p)]
            case .compensate(let n):
                let saved = roundingForMentalMath ? Self.roundedForMentalMath(value) : value
                isApproximate = isApproximate || abs(saved - value) > abs(value) * 1e-12
                let power = n == 3 ? 2 : n < 20 ? 10 : 100
                calculations = [.multiply(power), n > power ? .add(saved) : .subtract(saved)]
            }
            for calculation in calculations {
                let calculated = calculation.apply(to: value)
                value = roundingForMentalMath ? Self.roundedForMentalMath(calculated) : calculated
                isApproximate = isApproximate || abs(value - calculated) > abs(calculated) * 1e-12
                result.append(Step(calculation: calculation, value: value, isApproximate: isApproximate))
            }
        }
        return result
    }

    var inverse: MentalRule {
        func multiply(_ n: Int) -> [Operation] {
            switch n { case 1: []; case 20: [.multiply(2), .multiply(10)]; default: [.multiply(n)] }
        }
        return MentalRule(operations: operations.reversed().flatMap { operation -> [Operation] in
            switch operation {
            case .multiply(let n), .compensate(let n):
                return switch n { case 4: [.divide(2), .divide(2)]; case 5: [.multiply(2), .divide(10)]; default: [.divide(n)] }
            case .divide(let n): return multiply(n)
            case .percent(let p):
                let divisor = 100 + p, common = MentalRules.gcd(100, divisor)
                return multiply(100 / common) + (divisor / common == 1 ? [] : [.divide(divisor / common)])
            }
        })
    }
}

enum MentalRules {
    private struct Key: Hashable {
        let numerator: Int
        let denominator: Int
        let mentalSteps: Int
        let actions: Int
    }
    static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
    private static let catalogue: [(factor: Double, rule: MentalRule)] = {
        let vocabulary: [MentalRule.Operation] = [.multiply(2), .divide(2)] +
            (3...9).map { .multiply($0) } + [3, 9, 11, 99, 101].map { .compensate($0) } +
            [5, 10, 15, 20, 25, 50, -5, -10, -15, -20, -25].map { .percent($0) }
        var choices: [Key: MentalRule] = [:]
        func rational(_ operation: MentalRule.Operation) -> (Int, Int) {
            switch operation {
            case .multiply(let n), .compensate(let n): (n, 1)
            case .divide(let n): (1, n)
            case .percent(let p): (100 + p, 100)
            }
        }
        func visit(_ numerator: Int, _ denominator: Int, _ steps: [MentalRule.Operation]) {
            for shift in -8...8 {
                let scale = Int(pow(10, Double(abs(shift))))
                let n = numerator * (shift > 0 ? scale : 1), d = denominator * (shift < 0 ? scale : 1)
                let factor = Double(n) / Double(d)
                guard factor >= 1e-9, factor <= 1e9 else { continue }
                var halves = steps.filter { $0 == .divide(2) }
                var multiplying = steps.filter { if case .multiply = $0 { true } else if case .compensate = $0 { true } else { false } }
                while !halves.isEmpty, let index = multiplying.firstIndex(of: .multiply(2)) {
                    halves.removeLast(); multiplying.remove(at: index)
                }
                let corrections = steps.filter { if case .percent = $0 { true } else { false } }
                let scaleSteps: [MentalRule.Operation] = shift == 0 ? [] : [shift > 0 ? .multiply(scale) : .divide(scale)]
                let rule = MentalRule(operations: halves + multiplying + scaleSteps + corrections)
                guard rule.isSimple else { continue }
                let common = gcd(n, d)
                let key = Key(numerator: n / common, denominator: d / common, mentalSteps: rule.operations.filter { !$0.isScale }.count, actions: rule.actions)
                if let existing = choices[key] {
                    if rule.effort > existing.effort { continue }
                    if rule.effort == existing.effort && rule.retained >= existing.retained && rule.displayedSteps >= existing.displayedSteps { continue }
                }
                choices[key] = rule
            }
            guard steps.count < 3 else { return }
            for operation in vocabulary {
                if case .percent = operation, steps.contains(where: { if case .percent = $0 { true } else { false } }) { continue }
                if operation == .divide(2), steps.filter({ $0 == .divide(2) }).count >= 2 { continue }
                let (n, d) = rational(operation)
                if let last = steps.last {
                    let (lastN, lastD) = rational(last)
                    if lastN == d && lastD == n { continue }
                }
                let nextN = numerator * n, nextD = denominator * d, common = gcd(nextN, nextD)
                visit(nextN / common, nextD / common, steps + [operation])
            }
        }
        visit(1, 1, [])
        return choices.map { (factor: Double($0.key.numerator) / Double($0.key.denominator), rule: $0.value) }
            .sorted { $0.factor == $1.factor ? String(describing: $0.rule.operations) < String(describing: $1.rule.operations) : $0.factor < $1.factor }
    }()

    static func recommend(rate: Double, keeping previous: MentalRule? = nil) -> MentalRule? {
        guard rate.isFinite, rate > 0 else { return nil }
        if let previous, previous.isSimple, abs(previous.error(at: rate)) <= 0.03 { return previous }
        func choose(tolerance: Double) -> MentalRule? {
            var low = 0, high = catalogue.count
            while low < high {
                let middle = (low + high) / 2
                if catalogue[middle].factor < rate * (1 - tolerance) { low = middle + 1 } else { high = middle }
            }
            var best: MentalRule?
            for candidate in catalogue[low...] {
                if candidate.factor > rate * (1 + tolerance) + 1e-12 { break }
                let rule = candidate.rule, error = abs(rule.error(at: rate))
                guard error <= tolerance + 1e-12 else { continue }
                if let current = best {
                    if rule.effort > current.effort { continue }
                    if rule.effort == current.effort {
                        if rule.retained > current.retained { continue }
                        if rule.retained == current.retained {
                            if error > abs(current.error(at: rate)) { continue }
                            if error == abs(current.error(at: rate)) {
                                if rule.displayedSteps > current.displayedSteps { continue }
                                if rule.displayedSteps == current.displayedSteps && rule.actions >= current.actions { continue }
                            }
                        }
                    }
                }
                best = rule
            }
            return best
        }
        let strict = choose(tolerance: 0.02), relaxed = choose(tolerance: 0.03)
        if let strict, relaxed == nil || strict.effort <= relaxed!.effort { return strict }
        return relaxed
    }
}
