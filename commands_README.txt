**************************************
* To reprint/update the project tree
**************************************
1. Open Bash (Linux) Terminal in R to repository location
2. Run cmd //c "tree D:/Repos/rshiny_fitbit-dashboard /F /A > project_tree.txt"

**************************************
*Run Shiny App
**************************************
In console type shiny::runApp()

**************************************
* Using the project with Renv (a container system for R)
**************************************
Open the project in RStudio by double-clicking the rshiny_fitbit-dashboard.Rproj file

In the R console, run: renv::restore()

Wait for all packages to install

Run the app by typing: shiny::runApp()

If renv is not installed
If you see an error about renv, first install it: install.packages("renv")

Troubleshooting
Make sure you have opened the .Rproj file, not just the folder

The first time you run renv::restore() it may take several minutes

FOR DEPLOYMENT
# On server  
git clone your-repo
cd your-repo
R -e "renv::restore()"
R -e "shiny::runApp()"
# Server has EXACT same packages you developed with
-------------------------------------------------------------------------------
// Personal Notes

When installing additional packages ie install.packages("name") then renv::snapshot() to update renv

Commit changes locally:
git add .
git commit -m "message"

# Check if git remote is enabled
git remote -v

# If need to create token -> https://github.com/settings/tokens
Use a Personal Access Token (PAT) - Create one here (select "repo" scope)
Or use GitHub CLI - gh auth login
Or use Git Credential Manager
When prompted for username, enter your GitHub username. For password, paste the PAT.

# Add remote location to push to
git remote add origin https://github.com/omicreativedev/rshiny-fitbit-dashboard.git

# Push to GitHub salome branch
git push -u origin main:salome

# If a branch exists and you want to force update it
git push -u origin main:salome --force
-------------------------------------------------------------------------------
