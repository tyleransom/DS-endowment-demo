library(tidyverse)
library(glmnet)
library(broom)

# ── 1. Load and prep ──────────────────────────────────────────────────────────
df <- read_csv("data/endowments_clean.csv", show_col_types = FALSE) |>
  filter(!is.na(log_endowment), !is.na(log_enrollment), !is.na(inst_age),
         !is.na(control), !is.na(region)) |>
  mutate(
    control = factor(control, levels = c("Public", "Private")),
    region  = factor(region,  levels = c("Midwest", "Northeast", "South", "West"))
  )

cat("Modeling sample:", nrow(df), "institutions\n\n")

y <- df$log_endowment

# Shared model matrix (reference: Public, Midwest)
X <- model.matrix(~ log_enrollment + inst_age + control + region, data = df)[, -1]

# ── 2. Shared 5-fold CV folds (same splits for fair comparison) ───────────────
set.seed(42)
folds <- sample(rep(1:5, length.out = nrow(df)))

# ── 3. OLS ───────────────────────────────────────────────────────────────────
ols <- lm(log_endowment ~ log_enrollment + inst_age + control + region, data = df)

ols_cv_rmse <- map_dbl(1:5, function(k) {
  train <- df[folds != k, ]
  test  <- df[folds == k, ]
  fit   <- lm(log_endowment ~ log_enrollment + inst_age + control + region, data = train)
  sqrt(mean((test$log_endowment - predict(fit, test))^2))
}) |> mean()

# ── 4. LASSO via glmnet with same 5 folds ────────────────────────────────────
lasso_cv <- cv.glmnet(X, y, alpha = 1, nfolds = 5, foldid = folds)
lambda_best <- lasso_cv$lambda.min
lasso_cv_rmse <- sqrt(lasso_cv$cvm[lasso_cv$lambda == lambda_best])

# ── 5. RMSE comparison table ──────────────────────────────────────────────────
cat("=== 5-Fold CV RMSE Comparison ===\n")
rmse_tbl <- tibble(
  Model = c("OLS", "LASSO (lambda.min)"),
  CV_RMSE = round(c(ols_cv_rmse, lasso_cv_rmse), 4),
  `lambda` = c(NA, round(lambda_best, 4))
)
print(rmse_tbl)

winner <- if (ols_cv_rmse < lasso_cv_rmse) "OLS" else "LASSO"
loser  <- if (winner == "OLS") "LASSO" else "OLS"
diff_pct <- abs(ols_cv_rmse - lasso_cv_rmse) / max(ols_cv_rmse, lasso_cv_rmse) * 100
cat(sprintf(
  "\n>>> %s wins by %.1f%% lower CV-RMSE. With n=%d and only %d predictors, %s's\n",
  winner, diff_pct, nrow(df), ncol(X), winner
))
cat(    "    variance reduction (or in this case the full coefficient flexibility)\n")
cat(    "    outweighs the bias from shrinkage on this small dataset.\n\n")

# ── 6. Coefficient tables ─────────────────────────────────────────────────────
# OLS coefficients
ols_coefs <- tidy(ols) |>
  rename(Term = term, Estimate = estimate, SE = std.error, t = statistic, p = p.value) |>
  mutate(
    Sig = case_when(p < 0.001 ~ "***", p < 0.01 ~ "**", p < 0.05 ~ "*",
                    p < 0.1   ~ ".",   TRUE       ~ ""),
    across(c(Estimate, SE, t), \(x) round(x, 3)),
    p = round(p, 4)
  )

# LASSO coefficients at lambda.min
lasso_coefs <- coef(lasso_cv, s = "lambda.min") |>
  as.matrix() |>
  as.data.frame() |>
  rownames_to_column("Term") |>
  as_tibble() |>
  rename(LASSO_Estimate = lambda.min) |>
  filter(Term != "(Intercept)") |>
  mutate(LASSO_Estimate = round(LASSO_Estimate, 3),
         Shrunk_to_zero = LASSO_Estimate == 0)

cat("=== OLS Coefficient Table ===\n")
print(ols_coefs, n = Inf)

cat("\n=== LASSO Coefficients at lambda.min (", round(lambda_best, 4), ") ===\n")
print(lasso_coefs, n = Inf)

cat("\nNote: LASSO reference categories are Public (control) and Midwest (region).\n")
cat("OLS R-squared:", round(summary(ols)$r.squared, 3),
    "| Adj. R-squared:", round(summary(ols)$adj.r.squared, 3), "\n")
