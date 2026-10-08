# Running notebook R scripts

The published chapters include one shell script and nine R scripts. Chapters 1
and 3 cover data collection and relational databases without a companion script.

Each script below runs independently: download the script you want, install its
listed packages, and run it from beginning to end. Preparation and plotting
helpers are included; no other script, R Markdown file, or saved R session is
needed.

| Chapter | Script | Default data period | Purpose |
| --- | --- | --- | --- |
| 2 · GitHub: Terra Incognita | `02-github-terra-incognita.sh` | Not applicable | Set up GarminDB and download or update activities. |
| 4 · From SQLite to R | `04-extracting-data-dbplyr.R` | 29 June–27 July 2026 | Inspect database tables, query activities lazily, and compare dbplyr with SQL. |
| 5 · A place for everything | `05-a-place-for-everything.R` | Not applicable | Create the project folders and script structure template. |
| 6 · Finding the right variable | `06-finding-right-variable.R` | 29 June–13 August 2026 | Build run features, weekly summaries, and five figures. |
| 7 · Extracting the signal from its background | `07-extracting-signal-from-background.R` | 29 June–30 August 2026 | Classify laps, inspect continuity, and save labelled laps. |
| 8 · The five miles I never ran | `08-five-miles-i-never-ran.R` | 29 June–11 September 2026 | Prepare workouts, scale distances, fit trends, and make forecasts. |
| 9 · Mapping My Playground | `09-mapping-playground.R` | 29 June–2 October 2026 | Map GPS density, entry counts, towers, and satellite routes. |


## Set up your data

Download your own data with GarminDB as described in the notebook's opening
chapters. These scripts expect its SQLite database, rather than a FIT or GPX file.
Each script defaults to the Chapter 5 project headquarters. Change this one
block if your project lives elsewhere:

```r
setwd(
    path(path_home(), "DataSharp", "enter-the-mind", "running")
)
```

The expected input layout is:

```text
your/running/project/
└── _inputs/
    └── DBs/
        └── garmin_activities.db
```

The scripts use `fs::path()` for all project paths. `file_database` remains
relative to the working directory, so it does not need to change when only the
project headquarters changes.
The scripts open the database in read-only mode. Figures and derived data are
saved in `_outputs/figs` and `_outputs/data` under your working directory.
Running a script again replaces its generated outputs.

Use R 4.1 or later. Each script includes a commented `install.packages()` command
listing its dependencies. The plotting theme in chapters 6–9 requires ggplot2
4.0 or later; the lap preparation in chapters 7–8 requires dplyr 1.1 or later.
Package installation is a separate setup step.

## Match the posts or use your own programme

The periods in the table use inclusive dates. They preserve the data used in the
posts: chapter 6 has fourteen activities, chapter 7 has nineteen activities and
303 laps, and chapter 9 has 24 runs and 16,206 local GPS records. Chapter 4's
database-wide counts also stop on 27 July 2026.

Your own Garmin history will produce your own results. Adapt the programme dates,
recovery weeks, session-name matching, and easy-run activity IDs to your training
plan. Chapter 8 retains the post's fixed forecast dates of 16 September and
28 November 2026; change those dates for a new forecast. The rule thresholds and
model formulas remain those illustrated in the posts.

Chapter 5's script is intentionally data-agnostic. It creates the recommended
project folders and marks where to add packages, input paths, outputs, analysis,
and any connection cleanup for a specific project.

Chapter 9 uses the original South African activity ID. Set
`south_africa_activity_id` to your own distant run to draw satellite panels; when
that activity is absent, the local maps still run and the script explains the
missing panel. Keep the activities in `de_gps` within one geographic area for the
local maps. The satellite section needs internet access and caches Esri World
Imagery tiles in `_outputs/running-tiles`. For a route outside South Africa,
also adapt the country outline, overview bounds, and labels in that section.


## Plot design

`running_design.R` is the sole shared helper. Before running chapters 6–9,
download it into your project's `_scripts` folder; those scripts create the
folder and stop with that instruction if the helper is absent. Every other
executable file in this folder is the numbered script for a specific chapter and
contains its own preparation and function definitions.
