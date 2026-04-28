# CLAUDE.md — University Endowment Analysis

## Research question
What institutional characteristics predict university endowment size in the United States?

## Reproducing the analysis
Run scripts in order from the project root (not from inside `src/`):

```bash
Rscript src/scrape_endowments.R   # scrape Wikipedia → data/raw/endowments_raw.csv
Rscript src/clean_endowments.R    # clean + join    → data/endowments_clean.csv
Rscript src/model_endowments.R    # OLS + LASSO     → printed output
Rscript src/plot_endowment.R      # figure          → output/figures/endowment_enrollment.png
```

All scripts use relative paths and must be run from the project root.

## File structure

```
data/
  endowments_fallback.csv   # ~125 US universities: endowment, enrollment, founded, control, state
  raw/endowments_raw.csv    # scraped from Wikipedia (159 rows: 90 private, 69 public)
  endowments_clean.csv      # joined + cleaned; 159 rows, 104 have enrollment for modeling
src/
  scrape_endowments.R       # rvest scrape; falls back to endowments_fallback.csv on error
  clean_endowments.R        # name normalization, join, region coding, log transforms
  model_endowments.R        # OLS (lm) and LASSO (glmnet) with shared 5-fold CV
  plot_endowment.R          # ggplot2 log-log scatter with ggrepel labels + OLS trend lines
output/
  figures/endowment_enrollment.png
```

## Data sources
- **Wikipedia scrape**: [List of US universities by endowment](https://en.wikipedia.org/wiki/List_of_colleges_and_universities_in_the_United_States_by_endowment). Two wikitables on the page — private (table 1) then public (table 2). Columns: Rank, Institution, State, FY2025 endowment ($B), FY2024 endowment ($B), Change (%).
- **Fallback CSV** (`data/endowments_fallback.csv`): ~125 universities with enrollment, founding year, and control type. Used to enrich the scraped data via a normalized-key join. 104 of 159 scraped rows matched.

## Key data decisions
- Wikipedia uses legal institution names ("The Trustees of Princeton University"). `clean_endowments.R` has a manual map for ~20 known mismatches, plus regex rules for the common patterns (`^The `, ` and Related Foundations`, etc.).
- Enrollment and founding year come entirely from the fallback CSV — they are not on the Wikipedia page. Rows without a match (55 of 159) are dropped from the modeling sample.
- Region is derived from state abbreviation using standard US Census four-region definitions (Northeast, Midwest, South, West).
- Log transforms: `log_endowment = log(endowment_2025)`, `log_enrollment = log(enrollment)`, `inst_age = 2025 - founded`.

## Model details
- **Outcome**: `log_endowment` (natural log of FY2025 endowment in $B)
- **Predictors**: `log_enrollment`, `inst_age`, `control` (ref: Public), `region` (ref: Midwest)
- **OLS**: `lm()` with full sample (n = 104)
- **LASSO**: `cv.glmnet(alpha = 1)`, same 5-fold CV splits as OLS (set.seed(42)), penalty selected at `lambda.min`
- Both models evaluated on identical 5-fold CV RMSE for a fair comparison

## R packages required
`tidyverse`, `rvest`, `glmnet`, `broom`, `ggrepel`, `scales`
