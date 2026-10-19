import XCTest
@testable import Currency

final class MentalMathTests: XCTestCase {
    func testWorkedExampleAndExactCounterRule() {
        let rule = MentalRule(operations: [.multiply(2), .multiply(100), .percent(-10)])
        XCTAssertEqual(rule.trace(amount: 20).map(\.value), [40, 4000, 3600])
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
