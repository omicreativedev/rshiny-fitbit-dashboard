# R/colours.R
# Okabe-Ito color palette - Colorblind accessible
# Source: Okabe, M., & Ito, K. (2008)

# The palette (9 colors)
okabe_ito <- c(
  black      = "#000000",
  orange     = "#E69F00",
  lightblue  = "#56B4E9",
  green      = "#009E73",
  yellow     = "#F5C710",      # Amber (better on white backgrounds)
  blue       = "#0072B2",
  vermillion = "#D55E00",
  purple     = "#CC79A7",
  grey       = "#999999",
  white      = "#FFFFFF",
  lightgrey  = "#E5E7EB"
)

# Data colors - mapped to metrics
clr <- list(
  # Core metrics
  hr       = okabe_ito["vermillion"],   # Heart rate
  steps    = okabe_ito["blue"],         # Steps
  deep     = okabe_ito["green"],        # Deep sleep
  light    = okabe_ito["lightblue"],   # Light sleep
  rem      = okabe_ito["purple"],       # REM sleep
  wake     = okabe_ito["orange"],       # Wake
  calories = okabe_ito["yellow"],       # Calories
  spo2     = okabe_ito["green"],        # SpO2
  bg       = okabe_ito["white"],        # Backgrounds
  
  # Zone minutes
  fat_burn = okabe_ito["lightblue"],
  cardio   = okabe_ito["yellow"],
  peak     = okabe_ito["vermillion"],
  
  # UI text (grays from palette)
  text_primary   = okabe_ito["black"],
  text_secondary = okabe_ito["grey"],
  
  # Reference lines
  target_line = okabe_ito["grey"],
  grid_line = okabe_ito["lightgrey"]
)

# Helper for custom color orders
get_okabe_ito <- function(n = 9, start = 1) {
  colors <- unname(okabe_ito)
  colors[start:min(start + n - 1, length(colors))]
}