# Mental currency conversion rules with explicit difficulty weights

This experiment now distinguishes numerical approximation coverage from human usability. The first version found a short expression for every sampled conversion by treating eighths, sixths, and other derived operations as cheap. User feedback rejected that definition of “easy”. Its earlier 100% numerical coverage is **not evidence of 100% usability**.

## Evidence and design decision

The [primary research note](mental-arithmetic-evidence.md) reviews five experimental papers on arithmetic strategies, operand size, working memory, carrying, familiarity, and individual differences. These support considering the work behind an instruction and the amount being processed. They do not supply a calibrated latency table for the currency rules. The changes below are conservative engineering choices informed by those findings and the user’s explicit preferences.

- Allow direct **×3 through ×10**, alongside doubling, halving and decimal shifts. Direct multiplication and its inverse division have different eligibility: direct ÷3–÷9 stays outside the simple search. ÷4 and ÷5 remain available as two halvings or doubling followed by ÷10.
- Retain familiar decompositions, including ×5 as halving then ×10, and compensation around 10/100. Do not force a decomposition when a direct small multiplier is preferred.
- Separate instruction-level arithmetic actions from estimated effort. Add 0.5 points for each extra retained value in each subcalculation; repeated use of a saved branch is charged again. A direct multiplication is one instruction-level action. Doubling, halving and decimal shifts have effort weight 1; direct ×3, ×4, ×6, ×7, ×8 and ×9 have weight 2. Direct ×5 has weight 3 to keep its two-action halving/shift route preferred. These are user-guided heuristics, not measured seconds or universal difficulty rankings.
- Count the work inside corrections: ±5% has three actions, ±10% two, ±15% four, ±20% and ±25% three, and +50% two. −50% is simply halving. Corrections retain the necessary input/share values; a direct multiply has one running value at this abstraction level. Digit-level carries are not separately modeled.
- Merge decimal shifts and cancel opposing double/halve steps before scoring. Keep alternatives with different action counts so a cheaper score cannot discard a route needed under a tighter action limit.
- Limit the default to four instruction-level arithmetic actions, at most three non-scale search operations, two standalone halvings and one percentage correction. Exclude sixths, eighths and 12.5% corrections from the simple vocabulary.
- Target 2% relative error, accepting up to 3% only for a lower **effort score**, rather than merely fewer displayed instructions. Within a score, prefer fewer retained values, lower error, then fewer arithmetic actions.
- Every rule found in either direction gets its exact counter-rule, even when it requires a harder division. Both directions use the same explicit difficulty model; larger division weights express the user’s preference and are not scientifically measured times.

## Reproducibility

- Reference date: **2026-10-16**, using the same [Frankfurter EUR snapshot](https://api.frankfurter.dev/v1/latest?base=EUR) as the initial experiment. This revision deliberately reuses the dated snapshot to isolate the model change.
- 29 foreign quotes plus EUR: **30 currencies and 870 directed conversions**. Cross-rates are derived from a single EUR snapshot and are not independent market observations.
- The [experiment branch](https://github.com/LeonGeorgi/currency/tree/codex/mental-math-prototype) contains the standalone offline `Shared/MentalMathPrototype.html` and `scripts/evaluate-mental-math-prototype.mjs`.
- Run `node scripts/evaluate-mental-math-prototype.mjs` on that branch. Results are written to ignored `build/MentalMath/evaluation.json`. The HTML includes the same pure module and the full source snapshot. The HTML remains an offline experiment. The app now has a Swift rule generator and worked-example view; see the production integration notes below.

## Results with the four-action budget

| Strict error limit | Rules found | Coverage | Median absolute error among covered pairs |
| ---: | ---: | ---: | ---: |
| 1% | 650/870 | 74.7% | 0.474% |
| 2% | 825/870 | 94.8% | 0.946% |
| 3% | 864/870 | 99.3% | 1.324% |
| 5% | 870/870 | 100.0% | 2.284% |

The adaptive 2%/3% policy finds independently eligible rules for **864/870** directions, with **6** gaps. Of those rules, 613 stay within 2%. Median absolute reference error is 1.32%. Higher mathematical coverage follows from accepting direct small multiplication; it is not evidence that all these routes are easy for people. Four instruction-level actions can have an effort score greater than four.

## Difficulty score and its breakdown

Every selected rule and every counter-rule receives a relative score from the same pure `difficulty(rule)` function. The search uses that same score to rank eligible rules. The demo exposes the arithmetic/memory split and the contribution of each subcalculation; the central weights are also shown as a table.

**Score = sum of operation weights + 0.5 × extra values retained in each subcalculation.** A lower score means less predicted effort in this heuristic model. This is not a time estimate, an error probability, or a calibrated easy/hard classification. Scores currently do not depend on the entered amount, number of digits, decimal places or carries.

| Operation | Starting weight |
| --- | ---: |
| Double, halve, or shift the decimal point | 1 |
| Add/subtract a saved value | 1 |
| Direct ×3, ×4, ×6, ×7, ×8, ×9 | 2 |
| Direct ×5 | 3 |
| Direct ÷4 / ÷5 | 3 / 4 |
| Direct ÷3 / ÷6 | 5 |
| Direct ÷7 / ÷8 / ÷9 | 6 |
| Other direct multiplication / division | 4 / 7 |
| Each extra retained value, per subcalculation | +0.5 |

Decimal shifts include ×10, ÷10, ×100, ÷100, etc. Known decompositions are scored as their actual instructions, so two halvings cost 2 rather than the direct ÷4 weight of 3. Division weights make hard counter-rules comparable without adding them to the easy search vocabulary. Direct ×5 keeps a higher weight than its two-point halving/shift alternative, as explicitly requested by the user.

Percentage procedures are decomposed too: ±10% = a decimal shift plus addition/subtraction (2 arithmetic points) and retaining the input (+0.5). ±15% uses four arithmetic points and two extra retained values (+1). ±5%, ±20% and ±25% each total 3.5; +50% totals 2.5; −50% is simply halving at 1 point.

| Example | Arithmetic | Memory | Total |
| --- | ---: | ---: | ---: |
| Direct ×7: ×7 | 2 | 0 | 2 |
| Direct ÷7: ÷7 | 6 | 0 | 6 |
| Direct ×5: ×5 | 3 | 0 | 3 |
| Halve then ×10: halve → ×10 | 2 | 0 | 2 |
| Subtract 10%: −10% | 2 | 0.5 | 2.5 |
| Undo subtracting 10%: ×10 → ÷9 | 7 | 0 | 7 |
| Add 15%: +15% | 4 | 1 | 5 |

One retained value means only the running result at this abstraction level. It does not mean multidigit multiplication uses no working memory. Extra branch values are charged while their subcalculation is active; sequential branches do not all remain live at once. The existing peak-retained-value estimate stays available as additional context.

The constants are explicit design assumptions informed by the evidence note and user preferences. Their values are not measurements from those papers. Validation should compare complete rules on round and awkward amounts before fitting any empirical weights or predicting seconds.

## Direct multiplication and its counter-rule

| Directly allowed | Preferred exact instructions | Exact counter-rule of the direct multiplication |
| --- | --- | --- |
| ×3 | ×3 | ÷3 |
| ×4 | ×4 | halve → halve |
| ×5 | halve → ×10 | ×2 → ÷10 |
| ×6 | ×6 | ÷6 |
| ×7 | ×7 | ÷7 |
| ×8 | ×8 | ÷8 |
| ×9 | ×9 | ÷9 |
| ×10 | ×10 | ÷10 |

The division side is deliberately asymmetric: ÷3, ÷6, ÷7, ÷8 and ÷9 are shown as harder counter-rules, while the independently simple reverse search must find another approximation. ×10/÷10 are decimal shifts. ×5 is also directly allowed, but its higher score preserves the user's preferred “halve → ×10” procedure. Direct ×4 can win a tie over two doublings because it has the same effort score and fewer arithmetic instructions.

## Familiar decompositions remain available

| Calculation | Exact alternative |
| --- | --- |
| ×3 | save input → double → add saved input |
| ×4 | double → double |
| ×5 | halve → ×10 |
| ÷5 | double → ÷10 |
| ×25 | halve → halve → ×100 |
| ÷25 | double → double → ÷100 |
| ×50 | halve → ×100 |
| ÷50 | double → ÷100 |
| −50% | halve |
| ×9 / ×11 | save input → ×10 → subtract/add saved input |
| ×99 / ×101 | save input → ×100 → subtract/add saved input |

Saving an input adds a memory penalty of 0.5 points per extra retained value, but does not count as an arithmetic action. “Saved input” means the value at the start of that subcalculation, including when it follows another operation. The trace shows the actual intermediate values. The demo compares preferred methods with a search that excludes direct ×3–×9, so the earlier procedures remain inspectable.

The previous revision covered **547/870** directions independently and **658/870** including counter-rules. The new multiplication vocabulary substantially increases numerical availability while leaving the error thresholds and four-action cap unchanged. The scientific evidence note does not validate the current weights or assert that a multidigit ×7 takes the same time for every person or amount.

## Every rule includes its counter-rule

For every generated rule, reverse the instruction order and undo each step. This is always displayed beside the original rule, including when no independently easy reverse rule exists. The demo shows independently searched rules for both directions and lets the two example amounts be changed separately. Swapping currencies also swaps those amounts.

Use integer operations in the inverse instructions: undoing −10% is **×10 → ÷9**, rather than decimal division or reciprocal fraction notation. Undoing +10% is **×10 → ÷11**, and undoing +50% is **×2 → ÷3**. Changing the percentage sign does not undo a correction. Harder counter-rules remain visible without claiming they meet the conservative vocabulary or presenting their heuristic difficulty score as an experimental measurement.

| Original direction and rule | Exact counter-rule | Counter-rule's signed reference error |
| --- | --- | ---: |
| EUR → JPY: ×2 → ×9 → ×10 | JPY → EUR: ÷10 → ÷9 → halve | -1.211% |
| EUR → USD: +10% | USD → EUR: ×10 → ÷11 | +2.300% |
| EUR → CHF: −10% | CHF → EUR: ×10 → ÷9 | +3.022% |
| EUR → CNY: ×10 → −25% | CNY → EUR: ×4 → ÷3 → ÷10 | +0.320% |
| EUR → KRW: ×1,000 → +50% | KRW → EUR: ×2 → ÷3 → ÷1,000 | -0.066% |

“Exact” means that the counter-rule undoes the approximate rule; both still approximate the reference conversion. For rule multiplier `f` and reference rate `r`, forward error is `e = f/r − 1`. Reverse error is `r/f − 1 = −e/(1+e)`, so it must be recalculated. For example, the CHF counter-rule exceeds 3% even though the original stays within 3%; the demo flags this rather than hiding the counter-rule.

At the adaptive default, **864/870** directions have independently eligible rules. Including counter-rules makes **870/870** available: **6** additional directions have an inverse only. Of the 864 counter-rules, **11** exceed 3% reference error; the largest is **3.0918%**. Availability includes harder inverses and does not measure human usability.

## Selected independently generated rules

This table lists independently searched shortcuts only; missing entries can still have a counter-rule as described above. Apply instructions left to right; every correction refers to the current result. Positive error means too high, negative error too low. A compact percentage label must be accompanied by its underlying procedure in the demo.

| Direction | Reference rate | Selected rule | Signed error | Arithmetic actions | Effort score |
| --- | ---: | --- | ---: | ---: | ---: |
| EUR → JPY | 177.82 | ×2 → ×9 → ×10 | +1.226% | 3 | 4 |
| JPY → EUR | 0.00562366438 | halve → ÷100 → +10% | -2.199% | 4 | 4.5 |
| EUR → USD | 1.1253 | +10% | -2.248% | 2 | 2.5 |
| USD → EUR | 0.888651915 | −10% | +1.277% | 2 | 2.5 |
| EUR → GBP | 0.84385 | −15% | +0.729% | 4 | 5 |
| GBP → EUR | 1.18504474 | +20% | +1.262% | 3 | 3.5 |
| EUR → CHF | 0.9272 | −10% | -2.934% | 2 | 2.5 |
| CHF → EUR | 1.07851596 | +10% | +1.992% | 2 | 2.5 |
| EUR → CNY | 7.524 | ×10 → −25% | -0.319% | 4 | 4.5 |
| CNY → EUR | 0.132908028 | ×9 → ÷100 → +50% | +1.574% | 4 | 5.5 |
| EUR → INR | 106.864 | ×100 → +10% | +2.935% | 3 | 3.5 |
| INR → EUR | 0.00935768828 | ÷100 → −5% | +1.521% | 4 | 4.5 |
| EUR → KRW | 1499.01 | ×1,000 → +50% | +0.066% | 3 | 3.5 |
| KRW → EUR | 0.000667106957 | ×6 → ÷10,000 → +10% | -1.065% | 4 | 5.5 |
| EUR → SEK | 11.145 | save, ×10 → +saved | -1.301% | 2 | 2.5 |
| SEK → EUR | 0.0897263347 | ×9 → ÷100 | +0.305% | 2 | 3 |
| EUR → THB | 37.602 | halve → ×7 → save, ×10 → +saved | +2.388% | 4 | 5.5 |
| THB → EUR | 0.0265943301 | ×3 → ×9 → ÷1,000 | +1.525% | 3 | 5 |
| EUR → TRY | 55.7328 | ×7 → ×8 | +0.479% | 2 | 4 |
| TRY → EUR | 0.0179427554 | ×2 → ×9 → ÷1,000 | +0.319% | 3 | 4 |
| EUR → IDR | 20290.28 | ×2 → ×10,000 | -1.431% | 2 | 2 |
| IDR → EUR | 4.92846821e-05 | halve → ÷10,000 | +1.451% | 2 | 2 |
| EUR → AUD | 1.6171 | ×2 → ×8 → ÷10 | -1.057% | 3 | 4 |
| AUD → EUR | 0.618390947 | ×6 → ÷10 | -2.974% | 2 | 3 |

## What the numerical checks do and do not establish

- The hypothetical 180 JPY/EUR example remains exact. The search can now select ×2 → ×9 → ×10, with ÷10 → ÷9 → halve as its counter-rule.
- Step execution is compared with the derived multiplier for amounts 0, 0.01, 1, 5, 19.99, 100 and 9,999 on every covered 3% route. The largest relative discrepancy is approximately 2.2 × 10^-16.
- **1,524 generated rules** undergo **10,668 round trips** at those amounts. The largest relative round-trip discrepancy is about **3.6e-16**. Rational reciprocals and the reverse-error formula are checked separately.
- All eight direct multipliers from 3 through 10 are executed explicitly, with their inverses and any available decomposition. The existing twelve exact-method examples are also checked. The runner verifies that hard division has not entered the simple operation vocabulary and that ×5 still prefers halving then ×10.
- The runner also samples 1,001 logarithmically spaced rates from 10^-6 to 10^6, reporting coverage and gaps.
- Approximation error is amount-independent without intermediate rounding. Human difficulty is not: digits, carries, working memory and familiarity matter. Direct multiplication is one instruction here, not one digit-level mental operation.
- Difficulty scores for both directions are checked for finiteness, additive breakdowns and agreement with the score used by the search. The runner also checks ×7 versus ÷7, direct ×5 versus its preferred decomposition, memory costs and the zero-operation identity.
- Effort weights and the four-action cap are product hypotheses. The numerical checks establish arithmetic consistency, not human speed or error rates.

## Next validation

Compare direct multiplication, decomposition and harder reverse division with target users using round prices and awkward values such as 19.99 and 87.50. Counterbalance the rule and amount order; record successful answers, time, abandonment, and perceived ease. Distinguish first use from practice. Use these observations to decide whether optional derived corrections such as 15% and 25% are acceptable and to calibrate any numerical difficulty weights. The studies in the evidence note motivate this procedure; they do not replace it.

## Production integration

The offline prototype remains on its experiment branch. The app now uses `Currency/MentalMath.swift` for a Swift implementation of the accepted vocabulary and relative operation/memory weights. Eligible app examples have at most four arithmetic actions, four displayed steps, three non-scale search operations and six effort points. Hard integer division remains available in exact inverses. The UI contains no difficulty score.

Following feedback on the app, direct ×9 now costs 3 effort points rather than 2. It remains eligible, but ×2 → ×9 → ×10 costs 5 and loses to ×2 → ×100 → −10%, which costs 4.5. At equal effort, retained values and approximation error, the app prefers fewer displayed steps before fewer arithmetic actions. This avoids showing a longer saved-value procedure when the percentage route is equally easy. These remain product heuristics, not experimentally calibrated weights; the historical prototype results above use the original weights. The app uses a new rule-cache version so existing installations regenerate their choices once.

The currency detail view places an always-visible calculation above the chart, using the saved amount, intermediate values, and short, subtly uneven curved arrows labeled with the arithmetic. Patrick Hand (the Rudolstadt notes typeface) gives the compact example a handwritten appearance. The app shows only the selected forward rule; reverse controls are omitted to keep the example compact. The entered amount and exact conversion retain up to twelve significant digits.

The mental example rounds each intermediate result before using it in the next step. It tries one or two significant digits when the individual rounding error stays within 1%, otherwise using three. Small nonzero amounts retain their scale. Saved amounts in compensation procedures are rounded as well, so the instruction labels stay practical. Once a step involves rounding, it and subsequent results carry an approximation sign. For example, 19.99 → ×2 → 40 → ×100 → 4,000 → −10% → 3,600. The exact rule trace remains available for numerical checks; the example can accumulate additional rounding error beyond the rule's 3% rate approximation limit, and the precise conversion remains visible below it.

Rules are saved per currency pair and reused while their reference error stays within 3% and they still meet the production complexity limits. The first search runs off the main thread. Screenshots use isolated sample data and do not save rule choices. A larger-type layout presents the same ordered steps with full-width amounts. VoiceOver reads amounts and operations in calculation order.

The production limits make its eligible set a subset of the experiment’s; do not report the experiment’s numerical coverage as app coverage. Unit tests exercise cross-rate bounds, saved-value procedures, inverse round trips, rule stability and persistence coding. Screenshot tests capture the worked example and chart separately in all five languages.
