library(tidyverse)
library(ggrepel)

df <- read_csv("data/endowments_clean.csv", show_col_types = FALSE) |>
  filter(!is.na(endowment_2025), !is.na(enrollment), !is.na(control)) |>
  mutate(control = factor(control, levels = c("Public", "Private")))

top10 <- df |> slice_min(Rank, n = 10)

pal <- c("Public" = "#2166ac", "Private" = "#d6604d")

p <- ggplot(df, aes(x = enrollment, y = endowment_2025, color = control, shape = control)) +
  geom_smooth(method = "lm", se = TRUE, linewidth = 0.7, alpha = 0.12) +
  geom_point(alpha = 0.75, size = 2.5, stroke = 0.4) +
  geom_text_repel(
    data        = top10,
    aes(label   = institution),
    size        = 2.8,
    fontface    = "italic",
    lineheight  = 0.9,
    box.padding = 0.4,
    point.padding = 0.25,
    max.overlaps  = Inf,
    segment.color = "grey55",
    segment.size  = 0.35,
    min.segment.length = 0.15,
    seed = 42
  ) +
  scale_x_log10(
    labels = scales::label_comma(),
    breaks = c(1000, 3000, 10000, 30000, 100000, 300000)
  ) +
  scale_y_log10(
    labels = scales::label_dollar(suffix = "B"),
    breaks = c(0.5, 1, 2, 5, 10, 20, 50)
  ) +
  scale_color_manual(values = pal, name = "Control") +
  scale_shape_manual(values = c("Public" = 16, "Private" = 17), name = "Control") +
  annotation_logticks(sides = "bl", linewidth = 0.3, color = "grey60") +
  labs(
    title    = "University Endowment vs. Enrollment",
    subtitle = "FY2025 endowment; top 10 institutions labeled; lines show OLS fit per group",
    x        = "Total Enrollment (log scale)",
    y        = "Endowment (billions USD, log scale)",
    caption  = "Source: Wikipedia — List of US universities by endowment"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title        = element_text(face = "bold", size = 13, margin = margin(b = 4)),
    plot.subtitle     = element_text(color = "grey40", size = 9.5, margin = margin(b = 10)),
    plot.caption      = element_text(color = "grey55", size = 7.5, hjust = 1),
    panel.grid.minor  = element_blank(),
    panel.grid.major  = element_line(color = "grey92"),
    axis.ticks        = element_blank(),
    legend.position   = "inside",
    legend.position.inside = c(0.87, 0.15),
    legend.background = element_rect(fill = alpha("white", 0.85), color = NA),
    legend.title      = element_text(size = 9),
    legend.text       = element_text(size = 8.5),
    plot.margin       = margin(12, 16, 10, 12)
  )

out_path <- "output/figures/endowment_enrollment.png"
ggsave(out_path, p, width = 7, height = 5.5, dpi = 300, bg = "white")
cat("Saved:", out_path, "\n")
cat("Institutions plotted:", nrow(df), "\n")
cat("Top 10 labeled:\n")
top10 |> select(Rank, institution, endowment_2025, enrollment, control) |> print(n = 10)
