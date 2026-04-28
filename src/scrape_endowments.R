library(tidyverse)
library(rvest)

url <- "https://en.wikipedia.org/wiki/List_of_colleges_and_universities_in_the_United_States_by_endowment"

endowments_raw <- tryCatch({
  page <- read_html(url)
  tables <- page |> html_elements("table.wikitable") |> html_table(fill = TRUE)

  if (length(tables) < 2) stop("Expected at least 2 tables, found ", length(tables))

  clean_table <- function(df, control_type) {
    df |>
      as_tibble(.name_repair = "unique") |>
      mutate(control = control_type)
  }

  # First table is private, second is public (matches Wikipedia page order)
  private <- clean_table(tables[[1]], "Private")
  public  <- clean_table(tables[[2]], "Public")

  message("Private table: ", nrow(private), " rows, ", ncol(private), " cols")
  message("Public table:  ", nrow(public),  " rows, ", ncol(public),  " cols")

  bind_rows(private, public)
}, error = function(e) {
  message("Scraping failed: ", conditionMessage(e))
  message("Falling back to data/endowments_fallback.csv")
  read_csv("data/endowments_fallback.csv", show_col_types = FALSE) |>
    mutate(control = if_else(control %in% c("Public", "Private"), control, NA_character_))
})

glimpse(endowments_raw)

write_csv(endowments_raw, "data/raw/endowments_raw.csv")
message("Saved to data/raw/endowments_raw.csv (", nrow(endowments_raw), " rows)")
