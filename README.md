# University Endowment Analysis

## Research Question

What institutional characteristics predict university endowment size in the United States?

## Data

`data/endowments_fallback.csv` contains data on ~120 US universities including endowment size, enrollment, founding year, and control type (public/private). Originally sourced from Wikipedia's list of US universities by endowment.

## Goal

Build a reproducible data science pipeline that:
1. Scrapes up-to-date endowment data from Wikipedia
2. Cleans and merges with institutional attributes
3. Models endowment size using OLS and LASSO
4. Produces a publication-quality visualization
