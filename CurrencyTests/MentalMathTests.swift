import XCTest
@testable import Currency

final class MentalMathTests: XCTestCase {
    func testTwentyPercentCorrectionsAreEligibleAndRoundPracticalExamples() throws {
        for (percent, factor, rounded) in [(20, 1.2, 24.0), (-20, 0.8, 16.0)] {
            let rule = MentalRule(operations: [.percent(percent)])
            XCTAssertTrue(rule.isSimple)
            XCTAssertEqual(rule.factor, factor, accuracy: 1e-12)
            XCTAssertEqual(rule.effort, 3.5)
            XCTAssertEqual(rule.trace(amount: 80).last!.value, 80 * factor, accuracy: 1e-12)
            let step = try XCTUnwrap(rule.trace(amount: 19.99, roundingForMentalMath: true).last)
            XCTAssertEqual(step.calculation, .percent(percent))
            XCTAssertEqual(step.value, rounded, accuracy: 1e-12)
            XCTAssertTrue(step.isApproximate)
        }
        XCTAssertEqual(try XCTUnwrap(MentalRules.recommend(rate: 1.2)).operations, [.percent(20)])
    }

    func testDecimalDivisionsComeFirstAndMultiplicationsLast() {
        let original: [MentalRule.Operation] = [.multiply(100), .percent(-10), .divide(2), .divide(1000), .multiply(2), .multiply(10), .divide(10)]
        let rule = MentalRule(operations: original)
        XCTAssertEqual(rule.operations, [.divide(1000), .divide(10), .percent(-10), .divide(2), .multiply(2), .multiply(100), .multiply(10)])
        let factor = original.reduce(1.0) { $0 * $1.factor }
        for amount in [19.99, 0.01, -87.5] {
            XCTAssertEqual(rule.trace(amount: amount).last!.value, amount * factor, accuracy: 1e-12)
        }
    }

    func testPreviouslySavedRulesGetTheNewOrderWhenDecoded() throws {
        struct LegacyRule: Encodable { let operations: [MentalRule.Operation] }
        let legacy = ["EUR-JPY": LegacyRule(operations: [.multiply(2), .multiply(100), .percent(-10)])]
        let data = try JSONEncoder().encode(legacy)
        let decoded = try JSONDecoder().decode([String: MentalRule].self, from: data)
        let rule = try XCTUnwrap(decoded["EUR-JPY"])
        XCTAssertEqual(rule.operations, [.multiply(2), .percent(-10), .multiply(100)])
        XCTAssertEqual(MentalRules.recommend(rate: 177.82, keeping: rule), rule)
        XCTAssertEqual(try JSONDecoder().decode(MentalRule.self, from: JSONEncoder().encode(rule)), rule)
    }

    func testEarlyDivisionKeepsRoundedCompensationCoherent() {
        let rule = MentalRule(operations: [.compensate(11), .divide(100)])
        XCTAssertEqual(rule.operations, [.divide(100), .compensate(11)])
        let steps = rule.trace(amount: 19.99, roundingForMentalMath: true)
        for (actual, expected) in zip(steps.map(\.value), [0.2, 2, 2.2]) {
            XCTAssertEqual(actual, expected, accuracy: 1e-12)
        }
        XCTAssertEqual(steps.last?.calculation, .add(0.2))
    }

    func testRoundedExampleUsesEachDisplayedResultForTheNextStep() {
        let rule = MentalRule(operations: [.multiply(2), .multiply(100), .percent(-10)])
        let steps = rule.trace(amount: 19.99, roundingForMentalMath: true)
        XCTAssertEqual(steps.map(\.value), [40, 36, 3600])
        XCTAssertTrue(steps.allSatisfy(\.isApproximate))
        XCTAssertEqual(rule.trace(amount: 19.99).last!.value, 3598.2, accuracy: 1e-10)
        XCTAssertTrue(rule.trace(amount: 100, roundingForMentalMath: true).allSatisfy { !$0.isApproximate })
    }

    func testMentalRoundingScalesWithTheAmount() {
        for (input, expected) in [(39.98, 40.0), (43.75, 44), (1234, 1230), (9999, 10000), (0.01999, 0.02), (-43.75, -44), (0, 0)] {
            XCTAssertEqual(MentalRule.roundedForMentalMath(input), expected, accuracy: max(abs(expected), 1e-10) * 1e-12)
        }
        for amount in [1e-8, 0.0001234, 0.1234, 12.34, 1234, 1234567] {
            let rounded = MentalRule.roundedForMentalMath(amount)
            XCTAssertGreaterThan(rounded, 0)
            XCTAssertLessThanOrEqual(abs(rounded / amount - 1), 0.01 + 1e-12)
        }
    }

    func testRoundedCompensationAlsoUsesASimpleSavedAmount() {
        let rule = MentalRule(operations: [.compensate(9)])
        let steps = rule.trace(amount: 19.99, roundingForMentalMath: true)
        XCTAssertEqual(steps.map(\.value), [200, 180])
        XCTAssertEqual(steps.last?.calculation, .subtract(20))
        XCTAssertTrue(steps.allSatisfy(\.isApproximate))
    }

    func testWorkedExampleAndExactCounterRule() {
        let rule = MentalRule(operations: [.multiply(2), .multiply(100), .percent(-10)])
        XCTAssertEqual(rule.trace(amount: 20).map(\.value), [40, 36, 3600])
        XCTAssertEqual(rule.inverse.trace(amount: 3600).last?.value, 20)
        XCTAssertEqual(rule.inverse.factor, 1 / 180.0, accuracy: 1e-14)
        XCTAssertEqual(rule.effort, 4.5)
        XCTAssertGreaterThan(rule.inverse.effort, rule.effort)
    }

    func testSavedValueBelongsToItsOwnSubcalculation() {
        let rule = MentalRule(operations: [.divide(2), .compensate(11)])
        XCTAssertEqual(rule.trace(amount: 20).map(\.value), [10, 100, 110])
        XCTAssertEqual(rule.trace(amount: 19.99).last!.value, 19.99 * 5.5, accuracy: 1e-12)
    }

    func testPreferTenPercentCorrectionOverMultiplyingByNine() throws {
        XCTAssertGreaterThan(MentalRule.Operation.multiply(9).effort, MentalRule.Operation.multiply(3).effort)
        for rate in [177.82, 180] {
            let rule = try XCTUnwrap(MentalRules.recommend(rate: rate))
            XCTAssertEqual(rule.operations, [.multiply(2), .percent(-10), .multiply(100)])
            XCTAssertEqual(rule.trace(amount: 19.99).last!.value, 3598.2, accuracy: 1e-10)
        }
    }

    func testKnownRuleRemainsStableUntilTooInaccurate() throws {
        let previous = MentalRule(operations: [.multiply(2), .multiply(100), .percent(-10)])
        XCTAssertEqual(MentalRules.recommend(rate: 177.82, keeping: previous), previous)
        let changed = try XCTUnwrap(MentalRules.recommend(rate: 200, keeping: previous))
        XCTAssertNotEqual(changed, previous)
        XCTAssertLessThanOrEqual(abs(changed.error(at: 200)), 0.03)
        let data = try JSONEncoder().encode(["EUR-JPY": previous])
        XCTAssertEqual(try JSONDecoder().decode([String: MentalRule].self, from: data)["EUR-JPY"], previous)
    }

    func testWeightsKeepDivisionHarderAndFavorHalvingForFive() throws {
        let seven = MentalRule(operations: [.multiply(7)])
        XCTAssertEqual(seven.effort, 2)
        XCTAssertEqual(seven.inverse.effort, 6)
        XCTAssertEqual(try XCTUnwrap(MentalRules.recommend(rate: 5)).effort, 2)
        XCTAssertEqual(try XCTUnwrap(MentalRules.recommend(rate: 5)).trace(amount: 20).map(\.value), [10, 100])
    }

    func testGeneratedCrossRatesAndInverseTraces() throws {
        // Same dated snapshot used by the offline prototype. No network in tests.
        let rates = [1.0, 1.6171, 5.7197, 1.5935, 0.9272, 7.524, 24.323, 7.4748, 0.84385, 8.8316, 363.08, 20290.28, 3.4822, 106.864, 136.2, 177.82, 1499.01, 20.6871, 4.5929, 10.624, 1.9868, 70.858, 4.37, 5.331, 11.145, 1.4395, 37.602, 55.7328, 1.1253, 18.493]
        var covered = 0
        for from in rates {
            for to in rates where from != to {
                let rate = to / from
                guard let rule = MentalRules.recommend(rate: rate) else { continue }
                covered += 1
                XCTAssertTrue(rule.isSimple)
                XCTAssertLessThanOrEqual(abs(rule.error(at: rate)), 0.03 + 1e-12)
                let inverse = rule.inverse
                XCTAssertEqual(inverse.error(at: 1 / rate), -rule.error(at: rate) / (1 + rule.error(at: rate)), accuracy: 1e-12)
                for amount in [0, 0.01, 1, 19.99, 100, 9999, -12.5] {
                    let converted = rule.trace(amount: amount).last?.value ?? amount
                    XCTAssertEqual(converted, amount * rule.factor, accuracy: max(1, abs(converted)) * 1e-12)
                    let restored = inverse.trace(amount: converted).last?.value ?? converted
                    XCTAssertEqual(restored, amount, accuracy: max(1, abs(amount)) * 1e-12)
                }
            }
        }
        XCTAssertGreaterThan(covered, 800)
    }

    func testInvalidAndExtremeRates() throws {
        for rate in [0, -1, .nan, .infinity] { XCTAssertNil(MentalRules.recommend(rate: rate)) }
        for rate in [1e-8, 1.0, 1e8] {
            let rule = try XCTUnwrap(MentalRules.recommend(rate: rate))
            XCTAssertEqual(rule.factor, rate, accuracy: rate * 1e-12)
        }
    }
}
