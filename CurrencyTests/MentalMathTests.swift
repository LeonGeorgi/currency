import XCTest
@testable import Currency

final class MentalMathTests: XCTestCase {
    func testPercentCorrectionBeatsChainedMultiplicationsForYen() throws {
        let chain = MentalRule(operations: [.multiply(2), .multiply(8), .multiply(10)])
        let correction = MentalRule(operations: [.multiply(2), .percent(-20), .multiply(100)])
        XCTAssertTrue(correction.isSimple)
        XCTAssertLessThan(correction.effort, chain.effort)
        for rate in [160.0, 164.48] {
            let rule = try XCTUnwrap(MentalRules.recommend(rate: rate))
            XCTAssertEqual(rule.operations, correction.operations)
            XCTAssertLessThanOrEqual(abs(rule.error(at: rate)), 0.05)
        }
        XCTAssertEqual(correction.trace(amount: 100, roundingForMentalMath: true).map(\.value), [200, 160, 16000])
        // Exact small multipliers and powers of ten should remain convenient.
        XCTAssertEqual(MentalRule(operations: [.multiply(8), .multiply(10)]).effort, 4)
        XCTAssertEqual(MentalRule(operations: [.multiply(2), .multiply(2)]).effort, 3)
        XCTAssertEqual(try XCTUnwrap(MentalRules.recommend(rate: 4)).operations, [.multiply(4)])
    }

    func testFivePercentPrefersTheSimplestRuleOverAMoreAccurateOne() throws {
        let rule = try XCTUnwrap(MentalRules.recommend(rate: 1.04))
        XCTAssertTrue(rule.operations.isEmpty)
        XCTAssertLessThanOrEqual(abs(rule.error(at: 1.04)), 0.05)
        // A zero-action identity wins even though +5% is closer to the reference rate.
        XCTAssertLessThan(abs(MentalRule(operations: [.percent(5)]).error(at: 1.04)), abs(rule.error(at: 1.04)))
        XCTAssertTrue(try XCTUnwrap(MentalRules.recommend(rate: 0.96)).operations.isEmpty)
        let outside = try XCTUnwrap(MentalRules.recommend(rate: 1.06))
        XCTAssertFalse(outside.operations.isEmpty)
        XCTAssertLessThanOrEqual(abs(outside.error(at: 1.06)), 0.05)
    }

    func testReverseSearchFindsAnEasierRuleThanTheExactInverse() throws {
        let rules = MentalRules.recommendDirections(rate: 0.9)
        let forward = try XCTUnwrap(rules.forward)
        let reverse = try XCTUnwrap(rules.reverse)
        XCTAssertEqual(forward.operations, [.percent(-10)])
        XCTAssertEqual(reverse.operations, [.percent(10)])
        XCTAssertLessThan(reverse.effort, forward.inverse.effort)
        XCTAssertLessThanOrEqual(abs(reverse.error(at: 1 / 0.9)), 0.05)
        XCTAssertEqual(reverse.trace(amount: 90, roundingForMentalMath: true).last?.value, 99)
        for rate in [0.13678, 0.86627, 1.16842, 164.48, 180.0] {
            let pair = MentalRules.recommendDirections(rate: rate)
            XCTAssertNotNil(pair.forward)
            let counter = try XCTUnwrap(pair.reverse)
            XCTAssertLessThanOrEqual(abs(counter.error(at: 1 / rate)), 0.05 + 1e-12)
        }
    }

    func testTwoHalvingsBecomeOneQuarterStepWithoutDiscountingTheWork() throws {
        let rule = MentalRule(operations: [.divide(2), .divide(2)])
        XCTAssertEqual(rule.operations, [.divide(4)])
        XCTAssertEqual(rule.displayedSteps, 1)
        XCTAssertEqual(rule.actions, 2)
        XCTAssertEqual(rule.mentalSteps, 2)
        XCTAssertEqual(rule.effort, 2)
        XCTAssertTrue(rule.isSimple)
        XCTAssertEqual(rule.trace(amount: 100).map(\.value), [25])
        XCTAssertEqual(rule.trace(amount: 19.99, roundingForMentalMath: true).map(\.value), [5])
        XCTAssertEqual(try XCTUnwrap(MentalRules.recommend(rate: 0.25)).operations, [.divide(4)])
        XCTAssertEqual(rule.inverse.trace(amount: 25).last?.value, 100)
        XCTAssertFalse(MentalRule(operations: [.divide(4), .divide(2)]).isSimple)
    }

    func testSavedHalvingsAreCompactedButSeparateSubcalculationsStayIntact() throws {
        struct LegacyRule: Encodable { let operations: [MentalRule.Operation] }
        let data = try JSONEncoder().encode(LegacyRule(operations: [.divide(2), .divide(2), .multiply(100)]))
        let decoded = try JSONDecoder().decode(MentalRule.self, from: data)
        XCTAssertEqual(decoded.operations, [.divide(4), .multiply(100)])
        XCTAssertEqual(try JSONDecoder().decode(MentalRule.self, from: JSONEncoder().encode(decoded)), decoded)
        let separate = MentalRule(operations: [.divide(2), .compensate(11), .divide(2)])
        XCTAssertEqual(separate.operations, [.divide(2), .compensate(11), .divide(2)])
        XCTAssertEqual(separate.trace(amount: 20).map(\.value), [10, 100, 110, 55])
    }

    func testJPYToCZKPrefersTheShorterThirdRuleWithinTheErrorLimit() throws {
        // Frankfurter JPY/CZK snapshot dated 2026-10-16; no network in tests.
        let rate = 0.13678
        let rule = try XCTUnwrap(MentalRules.recommend(rate: rate))
        let multiplications = MentalRule(operations: [.divide(100), .multiply(2), .multiply(7)])
        XCTAssertEqual(rule.operations, [.divide(10), .third(increasing: true)])
        XCTAssertLessThan(rule.effort, multiplications.effort)
        XCTAssertLessThan(rule.displayedSteps, multiplications.displayedSteps)
        XCTAssertLessThanOrEqual(abs(rule.error(at: rate)), 0.05)
        XCTAssertEqual(rule.trace(amount: 300).map(\.value), [30, 40])
        // The longer subtract-third variant is equivalent, but is not preferable.
        let alternative = MentalRule(operations: [.divide(10), .multiply(2), .third(increasing: false)])
        XCTAssertTrue(alternative.isSimple)
        XCTAssertEqual(rule.factor, alternative.factor, accuracy: 1e-12)
        // A shorter rule must still respect the accuracy limit.
        let outside = try XCTUnwrap(MentalRules.recommend(rate: 0.145))
        XCTAssertGreaterThan(abs(rule.error(at: 0.145)), 0.05)
        XCTAssertLessThanOrEqual(abs(outside.error(at: 0.145)), 0.05)
    }

    func testThirdCorrectionsAreSelectedAndHaveExactCounterRules() throws {
        for (increasing, factor, expected) in [(true, 4.0 / 3, 120.0), (false, 2.0 / 3, 60.0)] {
            let rule = try XCTUnwrap(MentalRules.recommend(rate: factor))
            XCTAssertEqual(rule.operations, [.third(increasing: increasing)])
            XCTAssertTrue(rule.isSimple)
            XCTAssertGreaterThan(rule.effort, MentalRule.Operation.percent(10).effort)
            XCTAssertEqual(rule.trace(amount: 90).last!.value, expected, accuracy: 1e-12)
            XCTAssertEqual(rule.inverse.factor, 1 / factor, accuracy: 1e-12)
            for amount in [0.01, 19.99, 90, -12.5] {
                let converted = rule.trace(amount: amount).last!.value
                XCTAssertEqual(rule.inverse.trace(amount: converted).last!.value, amount, accuracy: 1e-10)
            }
            XCTAssertEqual(try JSONDecoder().decode(MentalRule.self, from: JSONEncoder().encode(rule)), rule)
        }
    }

    func testThirdCorrectionRoundsAndKeepsDecimalMultiplicationLast() {
        let rule = MentalRule(operations: [.multiply(10), .third(increasing: true)])
        XCTAssertEqual(rule.operations, [.third(increasing: true), .multiply(10)])
        let steps = rule.trace(amount: 19.99, roundingForMentalMath: true)
        XCTAssertEqual(steps.first!.value, 26.7, accuracy: 1e-12)
        XCTAssertEqual(steps.last!.value, 267, accuracy: 1e-12)
        XCTAssertTrue(steps.allSatisfy(\.isApproximate))
        XCTAssertFalse(MentalRule(operations: [.third(increasing: true), .percent(10)]).isSimple)
        XCTAssertFalse(MentalRule(operations: [.third(increasing: false), .third(increasing: false)]).isSimple)
    }

    func testPreferTwentyPercentReductionOverEightTenths() throws {
        let correction = MentalRule(operations: [.percent(-20)])
        let eightTenths = MentalRule(operations: [.multiply(8), .divide(10)])
        XCTAssertLessThan(correction.effort, eightTenths.effort)
        for rate in [0.79, 0.8, 0.81] {
            XCTAssertEqual(try XCTUnwrap(MentalRules.recommend(rate: rate)).operations, [.percent(-20)])
        }
        XCTAssertEqual(try XCTUnwrap(MentalRules.recommend(rate: 1.6)).operations, [.multiply(2), .percent(-20)])
        // A standalone ×8 still stays available when no decimal division is needed.
        XCTAssertEqual(try XCTUnwrap(MentalRules.recommend(rate: 8)).operations, [.multiply(8)])
    }

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
        XCTAssertEqual(MentalRules.recommend(rate: 177.82), rule)
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

    func testRulesAreRecomputedAndRemainCodable() throws {
        let previous = MentalRule(operations: [.multiply(2), .multiply(100), .percent(-10)])
        XCTAssertEqual(MentalRules.recommend(rate: 177.82), previous)
        let changed = try XCTUnwrap(MentalRules.recommend(rate: 200))
        XCTAssertNotEqual(changed, previous)
        XCTAssertLessThanOrEqual(abs(changed.error(at: 200)), 0.05)
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
                XCTAssertLessThanOrEqual(abs(rule.error(at: rate)), 0.05 + 1e-12)
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
