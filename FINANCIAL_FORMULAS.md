# Financial Formulas and Methodology

Implemented in `lib/features/*/domain/` (pure Dart). Every calculation returns a `CalcResult` with a status;
**missing inputs are never replaced with zero**.

| Status | Meaning |
|---|---|
| `ok` | Value computed |
| `missing_input` | A required input is absent |
| `zero_denominator` | Denominator is 0 |
| `negative_denominator` | Denominator < 0 (e.g. negative equity, loss base year) |
| `not_meaningful` | Mathematically defined but misleading (e.g. negative CAGR end value, non-consecutive years) |

## Input normalization

- Expense fields (cost of sales, admin, selling, operating expenses, finance cost, tax, capex) are stored as
  **positive magnitudes**; bracketed values in statements are negatives and are converted with `abs()`.
- Gross profit is derived as Revenue − Cost of Sales only when it is missing (noted in `derivations`).
- Unit captions ("Rupees in '000", "Rs. in million") scale extracted values to absolute amounts.

## Horizontal analysis

- **YoY growth %** = (Current − Previous) / Previous × 100. Previous = 0 → zero denominator; Previous < 0 →
  negative denominator; non-consecutive years → not meaningful.
- **CAGR %** = ((End / Begin)^(1 / n) − 1) × 100 where **n = elapsed years** (FY1→FY3 ⇒ n = 2).
  Begin ≤ 0 → rejected; End < 0 → not meaningful; End = 0 → −100%.
- Metrics: Revenue, Gross Profit, Operating Profit, Net Profit, Total Assets, Shareholders' Equity.

## Vertical analysis

Line item / Revenue × 100 for Cost of Sales, Gross Profit, Admin, Selling, Operating Expenses, Operating
Profit, Finance Cost, Net Profit. Revenue ≤ 0 → not calculated.

## Ratios

| Ratio | Formula | Notes |
|---|---|---|
| Current ratio | Current Assets / Current Liabilities | |
| Quick ratio | (Current Assets − Inventory) / Current Liabilities | Inventory required (not assumed 0) |
| Gross margin % | Gross Profit / Revenue × 100 | |
| Net margin % | Net Profit / Revenue × 100 | |
| ROE % | Net Profit / Average Equity × 100 | Average of opening and closing equity when the prior year exists; otherwise closing equity (stated in the note) |
| Debt-to-equity | Total Debt / Equity | Negative equity → `negative_denominator` |
| Interest coverage | Operating Profit / Finance Cost | Finance cost 0 → zero denominator ("unbounded") |
| Cash conversion | Operating Cash Flow / Net Profit | Net loss → not meaningful |
| Asset turnover | Revenue / Average Total Assets | Same averaging rule as ROE |
| Admin expense % | Admin Expenses / Revenue × 100 | Used for overhead efficiency |

## Data integrity checks

Errors (block confirmation unless the user explicitly overrides): currency mismatch between companies, fewer
than 2 years, revenue ≤ 0, total assets ≤ 0, current assets > total assets, current liabilities > total
liabilities, negative inventory. Warnings: missing required fields, fewer than 3 years, non-consecutive or
different years, Total Assets ≠ Liabilities + Equity, Gross Profit ≠ Revenue − COGS (2% tolerance).

## Forecasting (year 4)

1. **Linear trend** – ordinary least squares on (year, value): slope b = Σ(x−x̄)(y−ȳ) / Σ(x−x̄)²,
   intercept a = ȳ − b·x̄, forecast = a + b·(last year + 1). Needs ≥ 2 values. Applied to Revenue and Net Profit.
2. **Weighted moving growth** – forecast = Y3 × (1 + Σ wᵢ·gᵢ), gᵢ = YoY growth, most recent first.
   Default weights 0.5 / 0.3 / 0.2 (configurable, must sum to 1). With only two growth rates (three years) the
   first two weights are re-normalized: 0.625 / 0.375. Not computed if any base year is ≤ 0 or the latest value ≤ 0.
3. **Margin stability** – projected item = forecast revenue × average historical (item / revenue). Applied to
   Cost of Sales, Admin, Selling, Finance Cost and Net Profit. Forecast revenue = weighted growth, else linear.

Forecasts are labelled estimates; assumptions (slope, weights, rates, shares) are stored with each forecast.

## Scoring (100 points)

Points per criterion = weight × normalized score, normalized linearly between a *worst* value (0%) and a
*best* value (100%), clamped to [0, 1]. Bands (configurable in `ScoringThresholds`):

| Criterion | Metric | 0% at | 100% at |
|---|---|---|---|
| Revenue growth | Revenue CAGR % | −5 | 20 |
| Return on equity | Latest-year ROE % | 0 | 25 |
| Overhead efficiency | Average admin expenses % of revenue | 15 | 3 |
| Balance sheet safety | ½ current ratio (0.8 → 2.0) + ½ D/E (2.0 → 0.5) | | |
| Cash flow quality | Cumulative OCF / cumulative net profit | 0 | 1.2 |
| Gross margin (industry) | Latest gross margin % | 10 | 60 |
| Asset turnover (industry) | Latest asset turnover | 0.2 | 1.5 |

Special cases: negative equity → 0 points for ROE and the D/E half (a real weakness, not missing data);
non-positive cumulative profit → 0 points for cash-flow quality. Any other missing input marks the criterion
**incomplete** (no points); a company with an incomplete criterion has an incomplete total.

### Industry weights (%)

| Criterion | Other (base spec) | Technology / SaaS | Manufacturing | Capital intensive |
|---|---:|---:|---:|---:|
| Revenue growth | 25 | 25 | 20 | 15 |
| Return on equity | 25 | 25 | 20 | 20 |
| Overhead efficiency | 20 | 10 | 15 | 10 |
| Balance sheet safety | 15 | 10 | 20 | 25 |
| Cash flow quality | 15 | 15 | 15 | 15 |
| Gross margin | – | 15 | – | – |
| Asset turnover | – | – | 10 | 15 |

Banking and Insurance are `specialized_unsupported`: analysis and forecasts run but no score/verdict is issued.
Weights are editable per analysis; they must sum to 100 and the applied set is stored on the analysis.

## Verdict rules

Let gap = score A − score B (rounded to 2 dp).

| Condition | Verdict |
|---|---|
| Industry unsupported | Specialized analysis required |
| Either score incomplete | Insufficient data |
| gap > 10 | Company A scored higher |
| gap < −10 | Company B scored higher |
| \|gap\| ≤ 5 | Tie / Hold both |
| 5 < \|gap\| ≤ 10 | Inconclusive – review required (not defined by the specification) |

The explanation lists both totals, the gap, the leader for each criterion, detected weaknesses (current
ratio < 1, D/E > 1, negative equity, interest cover < 1.5x, net loss, cash conversion < 0.8x, shrinking
revenue) and the disclaimer that this is not investment advice.
