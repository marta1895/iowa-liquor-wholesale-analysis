# Iowa Liquor Wholesale: A 14-Year Market Diagnostic (2012–2025)

End-to-end analysis of Iowa's state-controlled liquor wholesale market across 14 years and ~31 million transactions. The goal: move past headline sales totals and uncover how the market actually shifted — where revenue concentrated, how the category mix evolved, and how premium-versus-value pricing tiers separate the spirits market.

## Dashboard preview

<img width="1440" height="801" alt="dashboard" src="https://github.com/user-attachments/assets/2363b9dc-e9fe-4c56-a5de-10de74f436ad" />


**[View the interactive dashboard on Tableau Public](https://public.tableau.com/app/profile/marta.narozhnyak/viz/iowa_liquor_wholesale_visualiz/IowaLiquorWholesaleAnalysis)**

## Data

**Source:** `bigquery-public-data.iowa_liquor_sales.sales` on Google BigQuery — every wholesale liquor transaction reported by the Iowa Alcoholic Beverages Division since 2012.

**Scope:** ~31 million transaction rows, January 2012 onward, across 99 Iowa counties and ~44 post-2017 categories.

**Important context — what this data actually represents:**

Iowa is one of 17 U.S. "control states," meaning the state government acts as the sole wholesale distributor for all liquor sold in Iowa. **This dataset captures state-to-retailer transactions, not consumer purchases.** Seasonal patterns and category trends reflect retailer purchasing behavior (including pre-holiday stocking) rather than direct consumer demand.

## Tech stack

- **BigQuery SQL** — analytical queries, window functions, percentile aggregations, cost-aware querying on a 30M+ row dataset
- **Python** (pandas, scipy, statsmodels) — statistical hypothesis testing on query outputs
- **Tableau Desktop / Public** — interactive dashboard with KPI tiles, geographic mapping, heatmap, and category bars

## Repository structure

```
iowa-liquor-wholesale-diagnostic/
├── README.md
├── iowa_liquor_wholesale_analysis.sql       # BigQuery: all analytical queries
├── iowa_liquor_wholesale_stat.ipynb         # Python: z-test + t-test notebooks
├── iowa_liquor_wholesale_visualiz.twb       # Tableau workbook
├── dashboard.png                            # Dashboard screenshot
└── data/
    ├── 01a_yearly_growth.csv
    ├── 01b_monthly_seasonality.csv
    ├── 02_categories_shift.csv
    ├── 03_sales_by_counties.csv
    ├── 03_sales_by_counties_top_5.csv
    └── 04_category_price_tiers.csv
```

## Analysis

The SQL is organized around four diagnostic questions, each tied to a decision a category manager or business strategist would actually face. Two of the four are paired with statistical tests in Python.

### Q1 — How have Iowa liquor sales changed over time?

Yearly totals with year-over-year growth, plus monthly seasonality across all 14 years.

**Key findings:**

- Total wholesale revenue grew from **$255M in 2012 to $447M in 2024** — roughly **75% cumulative growth**, averaging ~5% annually through 2019.
- The 2020 COVID lockdown drove a **+13.6% single-year spike** as bars and restaurants closed and at-home consumption surged.
- **2025 marked the first year-over-year decline (-5.0%)** in the dataset — possibly reflecting demographic shifts, post-COVID normalization, or cannabis legalization in nearby states.
- **October and December are the peak wholesale months** (around $34–36M each), reflecting retailer pre-holiday stocking. **January is the consistent annual low** (around $24M).

### Q2 — Has the category mix shifted over time?

Volume-share comparison between two stable years, with statistical testing of the largest observed shift.

**Methodology note:** Iowa renamed and reorganized its liquor categories in 2017, with 2016 as the messy in-between year where both old and new names appeared in the data. You can see the cutover clearly — distinct category counts jump from ~73 to 96 in 2016, then settle at ~47 from 2017 onward. Picking **2018 vs 2024** keeps the comparison clean: both years use the same modern category system.

**Key findings:**

- **WHISKEY LIQUEUR was the dominant gainer**, jumping from 5.79% to 14.66% of volume share, a **+8.87 percentage point shift**, likely driven by the rapid growth of flavored whiskey brands.
- **AMERICAN CORDIALS & LIQUEURS was the biggest loser** (-3.34 pp), reflecting a broader consumer migration away from sweet liqueurs.
- **Premium spirits gained share at the expense of value imports:** 100% AGAVE TEQUILA (+2.07 pp) and STRAIGHT BOURBON WHISKIES (+0.95 pp) grew, while IMPORTED VODKAS (-1.58 pp) and BLENDED WHISKIES (-0.81 pp) declined, in line with the growing preference for premium spirits in the U.S.

**Statistical test:** Two-proportion z-test on WHISKEY LIQUEUR's volume share between 2018 and 2024.

- H₀: share_2018 = share_2024  |  H₁: share_2018 ≠ share_2024  |  α = 0.05
- Result: z = 1,076.64, p < 0.001 → reject H₀
- The +8.87 pp shift is **statistically and practically significant** (a 153% relative increase on a 5.79% base).

### Q3 — Where does revenue concentrate?

County-level revenue ranking + per-store productivity + cumulative share of statewide totals.

**Key findings:**

- Iowa liquor revenue is **heavily geographically concentrated.** Polk County alone (containing Des Moines, the state capital) drives **22.9%** of statewide wholesale revenue.
- The **top 5 counties cover ~50%** of statewide revenue; the **top 20 capture around 78%** — out of Iowa's 99 counties. A textbook Pareto-style distribution.
- **College-town counties show outsized per-store revenue.** Johnson County (Iowa City / University of Iowa) and Story County (Ames / Iowa State) also stand out for outsized per-store revenue.

### Q4 — Are there meaningful price tiers, and do categories price differently?

Median, 25th, and 75th percentile bottle prices per category for 2024, with a t-test comparing a premium vs a value category.

**Methodology note:** Single recent year analysis (2024), since 2025 anomalous and 2026 incomplete, avoids price inflation across a multi-year window.

**Key findings:**

- **Categories cluster into clear price tiers.** Single Malt Scotch leads at a median wholesale price of **$52.47/bottle**, with Single Barrel Bourbon Whiskies and Bottled-in-Bond Bourbon close behind at $37.50.
- At the opposite end, **Triple Sec ($3.75 median) and Imported Distilled Spirits Specialty ($7.35) sit at the bottom of the price range**.

**Statistical test:** Welch's two-sample t-test on per-bottle wholesale price, Single Malt Scotch vs American Vodkas (2024 transactions).

- H₀: mean_price(Scotch) = mean_price(Vodkas)  |  H₁: mean_price(Scotch) ≠ mean_price(Vodkas)  |  α = 0.05
- Result: t = 83.04, p < 0.001 → reject H₀
- **Single Malt Scotch wholesales at $67.59 per bottle on average — roughly 6× the $10.64 price of American Vodkas.** A clear premium-vs-value pricing tier in Iowa's wholesale liquor market.

## Limitations

- **Wholesale, not consumer.** All findings reflect state-to-retailer transactions, not consumer purchasing behavior. The October/December peak, for example, reflects retailer stocking cycles ahead of holidays, not direct consumer drinking patterns.
- **Iowa-specific.** Control-state economics differ from open-market states with private wholesale distribution; These results should not be applied to other groups or markets.
- **Statistical sensitivity at this scale.** The dataset is huge, which affects the statistics. With millions of transactions in the data, statistical tests will almost always flag a difference as "significant" — even when the actual change is tiny. The findings here hold up because the differences are also big in real-world terms (Whiskey Liqueur grew 153%; Scotch costs 6× more than Vodkas), not just statistically. A smaller dataset might produce different conclusions.
- **2016–2017 taxonomy restructuring.** Comparing pre-2016 data directly to post-2017 data would produce misleading category-level results because of category renames and consolidations during the transition. The 2018 vs 2024 comparison was chosen specifically to avoid this artifact.
