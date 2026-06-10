**************************************
* To reprint/update the project tree
**************************************
1. Open Bash (Linux) Terminal in R to repository location
2. Run cmd //c "tree D:/Repos/rshiny_fitbit-dashboard /F /A > project_tree.txt"

-------------------------------------------------------------------------------
# In your new project, initialize renv
renv::init()

# This will discover packages used in your code and install them
# But it won't automatically copy from old projects

# To replicate packages from an old project:
# 1. If you have renv.lock from old project, copy it to new project
# 2. Then run:
renv::restore()

# If you don't have renv.lock, but have a list of packages:
# Create a file with package names, then:
packages <- c("shiny", "dplyr", "ggplot2", "readxl", ...)  # your packages
renv::install(packages)

# 1. You write your Shiny app code
# 2. When you need a package, install it:
install.packages("shiny")  # Goes to project library

# 3. After adding several packages, snapshot:
renv::snapshot()  # Updates renv.lock

# 4. Later, if someone else clones your project, they run:
renv::restore()  # Installs exact versions from renv.lock

# See what packages are in your project library
renv::dependencies()  # Shows packages your code uses
renv::status()        # Shows differences between library and lockfile

# Check if cache is enabled
renv::config$cache()

# Enable cache if not already (it usually is)
renv::config$cache$enabled(TRUE)

# Set cache location (optional - defaults to ~/.cache/R/renv)
Sys.setenv(RENV_PATHS_CACHE = "D:/R/renv/cache")  # Custom location