# First, make sure renv is active
renv::activate()

# Install packages used in your project (including all dependencies from your code)
packages <- c(
  "shiny",
  "shinyfullscreen",  
  "shinyjs",          
  "readxl",
  "tidyverse",
  "plotly",
  "lubridate",
  "jsonlite",
  "scales",
  "DT",
  "zoo",
  "rmarkdown",
  "digest"
)

# Install packages within renv
renv::install(packages)

# After installation, snapshot to record them in renv.lock
renv::snapshot()