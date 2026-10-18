# Mental currency conversion rules: conservative revision

This experiment now distinguishes numerical approximation coverage from human usability. The first version found a short expression for every sampled conversion by treating eighths, sixths, and other derived operations as cheap. User feedback rejected that definition of “easy”. Its earlier 100% numerical coverage is **not evidence of 100% usability**.

## Evidence and design decision

The [primary research note](mental-arithmetic-evidence.md) reviews five experimental papers on arithmetic strategies, operand size, working memory, carrying, familiarity, and individual differences. These support considering the work behind an instruction and the amount being processed. They do not supply a calibrated latency table for the currency rules. The changes below are conservative engineering choices informed by those findings and the user’s explicit preferences.

- Exclude sixths, eighths, division by integers 3–9, and 12.5% corrections from the default vocabulary.
- Allow doubling, halving, ×3, ×5, and decimal shifts. Allow percentage corrections derived from halves and tenths: 5%, 10%, 15%, 20%, 25%, and 50%.
- Count the work inside each correction. Subtracting 10% needs finding a tenth and subtracting it. Subtracting 25% needs two halvings and subtraction. A 15% correction needs finding 10%, halving that share, combining the shares, and applying the correction. It is not one elementary action.
- Keep an explicit estimate of how many values the described method retains. Triple is represented as doubling plus the original; ×5 as halving plus a decimal shift. These are specified strategies, not claims that everyone uses them or that every action takes equal time.
- Limit the default to four estimated elementary actions, including a possible decimal shift, and at most one percentage correction. Do not label three consecutive halvings as one cheap division; the vocabulary also limits standalone halvings to two per rule.
- Target 2% relative error, allowing up to 3% only when it saves at least one estimated action. Within a work budget, prefer fewer retained values, then lower error.
- If no rule meets the error and effort limits, return **no simple rule**. Numerical coverage is allowed to fall rather than silently introducing unfamiliar arithmetic.

## Reproducibility

- Reference date: **2026-10-16**, using the same [Frankfurter EUR snapshot](https://api.frankfurter.dev/v1/latest?base=EUR) as the initial experiment. This revision deliberately reuses the dated snapshot to isolate the model change.
- 29 foreign quotes plus EUR: **30 currencies and 870 directed conversions**. Cross-rates are derived from a single EUR snapshot and are not independent market observations.
- The [experiment branch](https://github.com/LeonGeorgi/currency/tree/codex/mental-math-prototype) contains the standalone offline `Shared/MentalMathPrototype.html` and `scripts/evaluate-mental-math-prototype.mjs`.
- Run `node scripts/evaluate-mental-math-prototype.mjs` on that branch. Results are written to ignored `build/MentalMath/evaluation.json`. The HTML includes the same pure module and the full source snapshot. No production app feature or telemetry is introduced.

## Results with the four-action budget

| Strict error limit | Rules found | Coverage | Median absolute error among covered pairs |
| ---: | ---: | ---: | ---: |
| 1% | 199/870 | 22.9% | 0.465% |
| 2% | 378/870 | 43.4% | 0.955% |
| 3% | 517/870 | 59.4% | 1.315% |
| 5% | 710/870 | 81.6% | 2.233% |

The adaptive 2%/3% policy covers **517/870** directions, with **353** explicit gaps. Of the covered directions, 374 stay within 2%. Median absolute error among covered directions is 1.31%. These are mathematical approximation errors, not observed human error rates.

## Selected generated rules

Apply instructions left to right; every correction refers to the current result. Positive error means too high, negative error too low. A compact percentage label must be accompanied by its underlying procedure in the demo.

| Direction | Reference rate | Conservative rule | Signed error | Estimated actions |
| --- | ---: | --- | ---: | ---: |
| EUR → JPY | 177.82 | ×2 → ×100 → −10% | +1.226% | 4 |
| JPY → EUR | 0.00562366438 | ÷100 → halve → +10% | -2.199% | 4 |
| EUR → USD | 1.1253 | +10% | -2.248% | 2 |
| USD → EUR | 0.888651915 | −10% | +1.277% | 2 |
| EUR → GBP | 0.84385 | −15% | +0.729% | 4 |
| GBP → EUR | 1.18504474 | +20% | +1.262% | 3 |
| EUR → CHF | 0.9272 | −10% | -2.934% | 2 |
| CHF → EUR | 1.07851596 | +10% | +1.992% | 2 |
| EUR → CNY | 7.524 | ×5 → +50% | -0.319% | 4 |
| CNY → EUR | 0.132908028 | No short rule within the limits | — | — |
| EUR → INR | 106.864 | ×100 → +10% | +2.935% | 3 |
| INR → EUR | 0.00935768828 | ÷100 → −5% | +1.521% | 4 |
| EUR → KRW | 1499.01 | ×1,000 → +50% | +0.066% | 3 |
| KRW → EUR | 0.000667106957 | No short rule within the limits | — | — |
| EUR → SEK | 11.145 | ×10 → +10% | -1.301% | 3 |
| SEK → EUR | 0.0897263347 | ÷10 → −10% | +0.305% | 3 |
| EUR → THB | 37.602 | No short rule within the limits | — | — |
| THB → EUR | 0.0265943301 | No short rule within the limits | — | — |
| EUR → TRY | 55.7328 | ×100 → halve → +10% | -1.315% | 4 |
| TRY → EUR | 0.0179427554 | ÷100 → ×2 → −10% | +0.319% | 4 |
| EUR → IDR | 20290.28 | ×2 → ×10,000 | -1.431% | 2 |
| IDR → EUR | 4.92846821e-05 | ÷10,000 → halve | +1.451% | 2 |
| EUR → AUD | 1.6171 | ×2 → −20% | -1.057% | 4 |
| AUD → EUR | 0.618390947 | halve → +25% | +1.069% | 4 |

For example, EUR → USD now uses +10% (−2.248%), and JPY → EUR uses `÷100 → halve → +10%` (−2.199%). The previous +12.5% answers were numerically better but did not meet the user’s idea of a practical shortcut. EUR → GBP uses −15% (+0.729%), which is explicitly counted as four actions with three retained values, not treated as an effortless single operation.

## What the numerical checks do and do not establish

- The hypothetical 180 JPY/EUR example remains exact with `×2 → ×100 → −10%`.
- Generated instructions are checked by executing their steps for amounts 0, 0.01, 1, 5, 19.99, 100, and 9,999 on every covered 3% conversion. The relative discrepancy from the derived factor is approximately 2.2 × 10^-16, consistent with floating-point rounding.
- The runner also samples 1,001 logarithmically spaced rates from 10^-6 to 10^6 and reports gaps. It does not silently enlarge the default operation budget.
- Approximation error is amount-independent without intermediate rounding. Human difficulty is **not** amount-independent: operands, carries, retained intermediate values and familiarity matter. The present prototype only shows the specific amount’s intermediate values; it does not yet have a scientifically calibrated amount-sensitive difficulty score.
- Four elementary actions is a product limit, not an experimentally established boundary. Counts such as “double once” operate at the instruction level; multidigit carries can add further work.

## Next validation

Compare complete instructions with target users using round prices and awkward values such as 19.99 and 87.50. Counterbalance the rule and amount order; record successful answers, time, abandonment, and perceived ease. Distinguish first use from practice. Use these observations to decide whether optional derived corrections such as 15% and 25% are acceptable and to calibrate any numerical difficulty weights. The studies in the evidence note motivate this procedure; they do not replace it.

The prototype remains on its separate branch. The main branch contains the findings and scientific evidence only.
