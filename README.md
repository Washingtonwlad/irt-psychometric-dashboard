# IRT Psychometric Dashboard: Item Calibration & Analysis with PISA 2022

![R](https://img.shields.io/badge/R-4.3%2B-blue?logo=r)
![mirt](https://img.shields.io/badge/mirt-1.40%2B-orange)
![Quarto](https://img.shields.io/badge/Quarto-1.4%2B-blueviolet?logo=quarto)
![Shiny](https://img.shields.io/badge/Shiny-1.8%2B-red?logo=r)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-In%20Progress-yellow)

> **How do individual test items behave across the ability continuum — and what do their parameters tell us about measurement quality?**

---

## Overview

Classical Test Theory (CTT) describes item difficulty as the proportion of correct responses in a sample — a statistic that changes every time the sample changes. Item Response Theory (IRT) resolves this by modeling the probability of a correct response as a function of both **person ability** (θ) and **item parameters** that are invariant across samples.

This project applies IRT to PISA 2022 cognitive reading items, producing:

1. **Item calibration** under 1PL, 2PL, and 3PL models with comparative fit analysis
2. **Item Characteristic Curves (ICC)** and **Test Information Functions (TIF)** with organizational interpretation
3. **Differential Item Functioning (DIF)** analysis across country groups
4. **Interactive Shiny dashboard** for item-level exploration and model comparison

The analytical lens is explicitly psychometric: items are treated as measurement instruments with quantifiable properties, not as generic binary variables.

---

## Dataset

**Source:** [PISA 2022 — Cognitive Item Data File](https://www.oecd.org/pisa/data/) — OECD  
**Format:** SPSS (.sav) — loaded via `haven::read_sav()`  
**Coverage:** ~600,000 students across 80+ countries  
**Domain:** Reading literacy cognitive items (dichotomous responses)

> **Data access:** The raw PISA 2022 data file is not included in this repository due to file size constraints (~1GB). Download the **Cognitive Item Data File** (SPSS format) from the OECD PISA data portal and place it in `data/raw/`.

---

## Project Structure

```
irt-psychometric-dashboard/
│
├── README.md
├── .gitignore
│
├── analysis/
│   └── irt_analysis.qmd          # Quarto document — full IRT pipeline
│
├── app/
│   └── app.R                     # Shiny interactive dashboard
│
├── src/
│   └── irt_functions.R           # Reusable IRT helper functions
│
├── reports/
│   └── figures/                  # Exported plots (ICC, TIF, DIF)
│
└── data/
    ├── raw/                      # PISA .sav file (not tracked by git)
    └── processed/                # Cleaned item response matrix (.rds)
```

---

## Analytical Pipeline

### Phase 1 — Data preparation (`analysis/irt_analysis.qmd`)
Load PISA 2022 cognitive items, select reading domain, construct binary response matrix. Document missing data patterns and item response distributions.

### Phase 2 — Model calibration
Fit 1PL (Rasch), 2PL, and 3PL models using `mirt`. Compare model fit via AIC, BIC, and likelihood ratio tests. Document parameter estimates with psychometric interpretation.

### Phase 3 — Item diagnostics
Generate Item Characteristic Curves (ICC) and Item Information Functions (IIF) for each item. Identify misfitting items using standardized residuals and infit/outfit statistics.

### Phase 4 — Test Information Function
Compute Test Information Function (TIF) to identify the ability range where the test measures most precisely. Compare information across model specifications.

### Phase 5 — DIF analysis
Test for Differential Item Functioning across country groups using the Lord's χ² test. Flag items that may function differently across cultural contexts.

### Phase 6 — Interactive dashboard (`app/app.R`)
Shiny app with:
- Model selector (1PL / 2PL / 3PL)
- Item browser with ICC and parameter estimates
- Test Information Function plot
- DIF flag explorer

---

## Key Psychometric Concepts

| Concept | Symbol | Interpretation |
|---------|--------|----------------|
| Person ability | θ (theta) | Latent trait measured by the test — standardized, mean=0 |
| Item difficulty | b | θ value at which P(correct) = 0.50 |
| Item discrimination | a | Slope of the ICC — how well the item separates ability levels |
| Pseudo-guessing | c | Lower asymptote — P(correct) for very low θ |
| Item Information | I(θ) | Precision of measurement at each ability level |
| Test Information | TIF | Sum of item information — where the test measures best |
| DIF | — | Item behaves differently across demographic groups |

---

## Technical Stack

| Component | Package |
|-----------|---------|
| IRT modeling | `mirt` |
| Data loading | `haven` |
| Data manipulation | `dplyr`, `tidyr` |
| Visualization | `ggplot2`, `patchwork` |
| Reporting | `Quarto` |
| Dashboard | `shiny`, `shinydashboard` |
| DIF analysis | `mirt` (lordif) |

---

## Setup

```r
# Install required packages
install.packages(c("mirt", "haven", "dplyr", "tidyr",
                   "ggplot2", "patchwork", "shiny",
                   "shinydashboard", "quarto"))
```

```r
# Render Quarto analysis
quarto::quarto_render("analysis/irt_analysis.qmd")
```

```r
# Run Shiny dashboard
shiny::runApp("app/app.R")
```

> Place PISA 2022 Cognitive Item Data File (.sav) in `data/raw/` before running.

---

## Author

**Washington Casamen Nolasco**  
Psychologist · Behavioral Data Scientist  
Specialization: Psychometrics, IRT, People Analytics, Bayesian Modeling  
[GitHub](https://github.com/Washingtonwlad) · [Upwork](#) · [LinkedIn](#)

---

## License

MIT License — see [LICENSE](LICENSE) for details.
