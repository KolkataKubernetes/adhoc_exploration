# Descriptives Strategy

## Parking Lot

- Map of program payments by program description?
- Stacked barchart of payment counts by program type
- Stacked barchart of payment volumes by program types
- Stacked barchart of payment counts by payee type
- Stacked barchart of payment volumes by program type
- Heatmap of paymount counts (using lat/long), sf package: across years
- Heatmap of paymount volumes (using lat/long), sf package: across years
- One-two other visuals you think will help explore variation in the data

## General Considerations
- Use the function below to define a style that keeps formatting consistent
theme_im <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title.position = "plot",
      plot.caption.position = "plot",
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_line(linewidth = 0.3),
      panel.grid.major.y = element_line(linewidth = 0.3),
      legend.position = "top",
      legend.title = element_text(face = "bold"),
      plot.title = element_text(face = "bold"),
      axis.title = element_text(face = "bold")
    )
}
-
