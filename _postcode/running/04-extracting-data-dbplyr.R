# Download your own Garmin database and adapt the working directory so the database can be found from it.
# Chapter 4: From SQLite to R
# R >= 4.1 is required. Install the packages listed below before running.
# The expected database is _inputs/DBs/garmin_activities.db, produced by GarminDB.
# Results use your own activities; the notebook's values require its original data.

# ---- Ready the tools ----
# If needed, install once:
# install.packages(c("DBI", "RSQLite", "dbplyr", "dplyr", "fs"))
library(DBI)
library(dbplyr)
library(dplyr)
library(fs)

# ---- Locate the headquarters ----
# Chapter 5's default project headquarters.
setwd(
    path(path_home(), "DataSharp", "enter-the-mind", "running")
)

# ---- Describe the project ----
dir_inputs  <- path("_inputs")
dir_outputs <- path("_outputs")
dir_out_figures  <- path(dir_outputs, "figs")
dir_out_datasets <- path(dir_outputs, "data")
dir_create(c(dir_outputs, dir_out_figures, dir_out_datasets))
file_database <- path(dir_inputs, "DBs", "garmin_activities.db")

if (!file.exists(file_database)) {
    stop("Garmin database not found: ", file_database,
         ". Adapt setwd() above or file_database to match your download.")
}

# ---- Publication snapshot ----
programme_start <- "2026-06-29"
# Exclusive end: the published post has eight runs and 220 activities.
# Change these dates for your programme and a later snapshot.
analysis_end <- "2026-07-28"

# ---- Open the database and run the examples ----
con <- DBI::dbConnect(
    RSQLite::SQLite(),
    dbname = file_database,
    flags = RSQLite::SQLITE_RO
)


print(
    dbListTables(con)
)

# ---- Lazy tables ----
activities <- tbl(con, "activities") |>
    filter(start_time < !!analysis_end)
print(activities)

# The following won't work
print(activities |> nrow())
# The following will work because the data were collected.
print(collect(activities) |> nrow())

# ---- Collect the running activities ----
my_runs <-
    activities |>
        filter(sport == "running", start_time >= !!programme_start) |>
        collect()
print(my_runs)

# ---- The same extraction in SQL ----
query <- paste(
    "SELECT * ", ## Select every column
    "FROM activities ", ## Choose the table
    "WHERE sport = 'running' ", ## First filter
    "AND start_time >= ", DBI::dbQuoteString(con, programme_start),
    "AND start_time < ", DBI::dbQuoteString(con, analysis_end)
)
my_runs_sql <-
    DBI::dbGetQuery(con, query) |> as_tibble()
print(isTRUE(all.equal(my_runs, my_runs_sql)))
cat("Running activities collected:", nrow(my_runs), "\n")
DBI::dbDisconnect(con)
