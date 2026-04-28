library(tidyverse)

# ── 1. Load raw data ──────────────────────────────────────────────────────────
raw <- read_csv("data/raw/endowments_raw.csv", show_col_types = FALSE)
fallback <- read_csv("data/endowments_fallback.csv", show_col_types = FALSE)

# ── 2. Parse numeric columns from raw ────────────────────────────────────────
endow_col_25 <- names(raw)[str_detect(names(raw), "FY2025")]
endow_col_24 <- names(raw)[str_detect(names(raw), "FY2024")]
change_col   <- names(raw)[str_detect(names(raw), "Change")]

raw <- raw |>
  rename(
    institution_raw = Institution,
    state           = State,
    endowment_2025  = all_of(endow_col_25),
    endowment_2024  = all_of(endow_col_24),
    pct_change      = all_of(change_col)
  ) |>
  mutate(
    endowment_2025 = parse_number(endowment_2025),
    endowment_2024 = parse_number(endowment_2024),
    pct_change     = parse_number(pct_change)
  )

# ── 3. Normalize institution names ────────────────────────────────────────────
# Wikipedia legal names → common names used in the fallback
manual_map <- tribble(
  ~institution_raw,                                              ~institution,
  "The Trustees of Princeton University",                        "Princeton University",
  "The University of Pennsylvania",                              "University of Pennsylvania",
  "Columbia University in the City of New York",                 "Columbia University",
  "The George Washington University",                            "George Washington University",
  "The Rockefeller University",                                  "Rockefeller University",
  "The Texas A&M University System & Related Foundations",       "Texas A&M University",
  "The Regents of the University of California",                 "University of California",
  "The Ohio State University",                                   "Ohio State University",
  "The University of Texas at Austin",                           "University of Texas at Austin",
  "The Pennsylvania State University",                           "Pennsylvania State University",
  "The Kansas University Endowment Association",                 "Kansas University",
  "The Board of Trustees of The University of Alabama",          "University of Alabama",
  "The University of Georgia and Related Foundations",           "University of Georgia",
  "The University of Utah",                                      "University of Utah",
  "The University of Texas System",                              "University of Texas System",
  "The University of Texas Southwestern Medical Center",         "UT Southwestern Medical Center",
  "The University System of Maryland Foundation",                "University of Maryland System",
  "The University of Tennessee System",                          "University of Tennessee",
  "The University of Arizona and the University of Arizona Foundation", "University of Arizona",
  "The University of Texas at San Antonio",                      "University of Texas at San Antonio"
)

# General rules: strip leading "The ", then strip parenthetical/suffix junk
normalize_name <- function(x) {
  x |>
    str_remove("^The ") |>
    str_remove(" in the City of New York$") |>
    str_remove(" and Related Foundations$") |>
    str_remove(" System & Related Foundations$") |>
    str_remove("^Trustees of ") |>
    str_remove("^Regents of the ") |>
    str_remove("^Board of Trustees of ") |>
    str_trim()
}

raw <- raw |>
  left_join(manual_map, by = "institution_raw") |>
  mutate(institution = coalesce(institution, normalize_name(institution_raw)))

# ── 4. Join fallback for enrollment, founding year ───────────────────────────
fb_attrs <- fallback |>
  select(institution, enrollment, founded) |>
  # fallback control comes from scrape; keep only the attrs we need
  rename(institution_fb = institution)

# Try exact match first, then hand-rolled fuzzy: lowercase + strip punctuation
normalize_key <- function(x) x |> str_to_lower() |> str_remove_all("[^a-z0-9 ]") |> str_squish()

raw <- raw |> mutate(key = normalize_key(institution))
fb_attrs <- fb_attrs |> mutate(key = normalize_key(institution_fb))

joined <- raw |>
  left_join(fb_attrs |> select(key, enrollment, founded), by = "key")

# ── 5. Region from state ──────────────────────────────────────────────────────
northeast <- c("ME","NH","VT","MA","RI","CT","NY","NJ","PA")
midwest   <- c("OH","IN","IL","MI","WI","MN","IA","MO","ND","SD","NE","KS")
south     <- c("DE","MD","DC","VA","WV","NC","SC","GA","FL","KY","TN","AL","MS","AR","LA","OK","TX")
west      <- c("MT","ID","WY","CO","NM","AZ","UT","NV","WA","OR","CA","AK","HI")

joined <- joined |>
  mutate(region = case_when(
    state %in% northeast ~ "Northeast",
    state %in% midwest   ~ "Midwest",
    state %in% south     ~ "South",
    state %in% west      ~ "West",
    TRUE                 ~ NA_character_
  ))

# ── 6. Log-transformed variables ──────────────────────────────────────────────
joined <- joined |>
  mutate(
    log_endowment  = log(endowment_2025),
    log_enrollment = log(enrollment),
    inst_age       = 2025 - founded
  )

# ── 7. Final column selection and ordering ───────────────────────────────────
clean <- joined |>
  select(
    institution, state, region, control,
    endowment_2025, endowment_2024, pct_change,
    log_endowment, enrollment, log_enrollment,
    founded, inst_age, Rank
  ) |>
  arrange(Rank)

write_csv(clean, "data/endowments_clean.csv")

# ── 8. Summary ────────────────────────────────────────────────────────────────
cat("\n=== Clean dataset: ", nrow(clean), "rows ===\n\n")
cat("Public vs. Private breakdown:\n")
clean |>
  count(control) |>
  mutate(pct = scales::percent(n / sum(n), accuracy = 0.1)) |>
  print()

cat("\nRows with enrollment matched from fallback:", sum(!is.na(clean$enrollment)), "\n")
cat("Rows missing enrollment:                   ", sum( is.na(clean$enrollment)), "\n")
cat("\nRegion breakdown:\n")
clean |> count(region, sort = TRUE) |> print()
