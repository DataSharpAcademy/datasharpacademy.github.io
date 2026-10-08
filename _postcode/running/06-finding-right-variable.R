# Download your own Garmin database and adapt the working directory so the database can be found from it.
# Chapter 6: Finding the right variable
# R >= 4.1 is required. Install the packages listed below before running.
# The expected database is _inputs/DBs/garmin_activities.db, produced by GarminDB.
# Results use your own activities; the notebook's values require its original data.

# ---- Ready the tools ----
# If needed, install once:
# install.packages(c("DBI", "RSQLite", "dbplyr", "dplyr", "fs", "ggplot2", "ghibli", "stringr", "tidyr", "readr"))
library(DBI)
library(dbplyr)
library(dplyr)
library(fs)
library(ggplot2)
library(stringr)
library(tidyr)
library(readr)

# ---- Locate the headquarters ----
# Chapter 5's default project headquarters.
setwd(
    path(path_home(), "DataSharp", "enter-the-mind", "running")
)

# ---- Describe the project ----
dir_inputs  <- path("_inputs")
dir_outputs <- path("_outputs")
dir_scripts <- path("_scripts")
dir_out_figures  <- path(dir_outputs, "figs")
dir_out_datasets <- path(dir_outputs, "data")
dir_create(c(dir_outputs, dir_scripts, dir_out_figures, dir_out_datasets))

# ---- Load the shared notebook plot design ----
file_running_design <- path(dir_scripts, "running_design.R")
if (!file_exists(file_running_design)) {
    stop(
        "Missing shared plot design: ", file_running_design,
        ". Download running_design.R and put it in the _scripts folder."
    )
}
source(file_running_design)
ggplot2::theme_set(theme_running())

file_database <- path(dir_inputs, "DBs", "garmin_activities.db")
if (!file.exists(file_database)) {
    stop("Garmin database not found: ", file_database,
         ". Adapt setwd() above or file_database to match your download.")
}

# ---- Display and save figures ----
save_running_plot <- function(plot, filename, width = 8, height = 5) {
    print(plot)
    ggplot2::ggsave(
        filename = path(dir_out_figures, filename),
        plot = plot, width = width, height = height, units = "in", dpi = 150
    )
}

# ---- Programme and publication snapshot ----
programme_start <- "2026-06-29"
# Exclusive end: the last run in the published table is 13 August.
analysis_end <- "2026-08-14"
# The programme's recovery weeks; adapt these for your training plan.
deload_weeks <- c(4, 7)

# ---- Open the database and reproduce the analysis ----
con <- DBI::dbConnect(
    RSQLite::SQLite(),
    dbname = file_database,
    flags = RSQLite::SQLITE_RO
)

# Close the read-only connection even if an analysis step fails.
# ---- Collect the runs ----
runs <- tbl(con, "activities") |>
    filter(sport == "running", start_time >= !!programme_start,
           start_time < !!analysis_end) |>
    collect()
if (nrow(runs) == 0L) stop("No runs in the selected programme dates.")
cat("Completed runs:", nrow(runs), "\n")

# ---- Engineer run features ----
runs <-
    runs |>
        arrange(start_time) |>
        mutate(
            run_id = row_number(),
            date = as.Date(start_time),
            training_week = as.integer(date - min(date)) %/% 7 + 1,
            session_type = case_when(
                str_detect(name, "Time Trial") ~ "Time trial",
                str_detect(name, "Hills")      ~ "Hills",
                str_detect(name, "Tempo")      ~ "Tempo",
                str_detect(name, "Long Run")   ~ "Long run",
                TRUE                           ~ "Short & Slow"
            ),
            deload = if_else(
                training_week %in% deload_weeks,
                "Deload",
                "Regular"),
            avg_pace = 60 / avg_speed
        )


print(
    runs |>
        select(
            run_id,
            date,
            training_week,
            session_type,
            deload,
            distance,
            avg_pace
        )
)

# ---- Average pace over time ----
plot_average_pace_over_time <-
runs |>
    ggplot() +
        aes(
            x = date, y = avg_pace,
            colour = session_type, shape = deload
        ) +
        geom_line(aes(group = 1), colour = "grey75") +
        geom_point() +
        scale_y_reverse() +
        labs(
            x = NULL,
            y = "Average pace (min/km)"
        )
save_running_plot(plot_average_pace_over_time, "average-pace-over-time-1.png", width = 8, height = 5)

# ---- Collect detailed run records ----
runs_detailed <-
    runs |>
        inner_join(
            tbl(con, "activity_records") |>
                semi_join(
                    tbl(con, "activities") |>
                        filter(sport == "running", start_time >= !!programme_start,
                               start_time < !!analysis_end) |>
                        select(activity_id),
                    by = "activity_id"
                ) |>
                collect(),
            by = "activity_id"
        ) |>
        filter(speed > 0) |>
        mutate(pace = 60 / speed) |>
        arrange(date, record)

# ---- Pace distributions by run ----
plot_pace_distributions_by_run <-
runs_detailed |>
    ggplot() +
        aes(
            y = date, x = pace,
            group = activity_id, fill = session_type
        ) +
        geom_violin(width = 5.4, alpha = 0.65) +
        geom_point(
            data = runs,
            aes(y = date, x = avg_pace),
            inherit.aes = FALSE,
            shape = 23,
            size = 3,
            fill = "white"
        ) +
        scale_x_reverse() +
        coord_cartesian(xlim = c(12, 3)) +
        labs(
            y = NULL,
            x = "Pace (min/km)",
            fill = "Session type"
        )
save_running_plot(plot_pace_distributions_by_run, "pace-distributions-by-run-1.png", width = 8, height = 10)

# ---- Training load over time ----
plot_training_load_over_time <-
runs |>
    ggplot(
        aes(
            x = date,
            y = training_load,
            colour = session_type,
            shape = deload
        )
    ) +
        geom_line(aes(group = 1), colour = "grey75") +
        geom_point() +
        labs(
            x = NULL,
            y = "Training load"
        )
save_running_plot(plot_training_load_over_time, "training-load-over-time-1.png", width = 8, height = 5)

# ---- Training effect over time ----
plot_training_effect_over_time <-
runs |>
    ggplot(
        aes(
            x = date,
            y = training_effect,
            colour = session_type,
            shape = deload
        )
    ) +
        geom_line(aes(group = 1), colour = "grey75") +
        geom_point() +
        labs(
            x = NULL,
            y = "Training effect",
            colour = "Session type",
            shape = "Deload week"
        )
save_running_plot(plot_training_effect_over_time, "training-effect-over-time-1.png", width = 8, height = 5)

# ---- Summarise training weeks ----
weekly_runs <-
    runs |>
        group_by(training_week, deload) |>
        summarise(
            n_runs = n(),
            total_distance = sum(distance),
            total_training_load = sum(training_load),
            avg_training_effect = mean(training_effect),
            .groups = "drop"
        ) |>
        arrange(training_week) |>
        mutate(
            distance_change =
                100 * (total_distance / lag(total_distance) - 1)
        )


print(
    weekly_runs |>
        select(
            training_week,
            total_training_load,
            avg_training_effect,
            total_distance,
            distance_change
        )
)

# ---- Weekly running distance ----
plot_weekly_running_distance <-
weekly_runs |>
    ggplot() +
        aes(
            x = training_week, y = total_distance,
            fill = deload
        ) +
        geom_col() +
        geom_text(
            aes(label = round(total_distance, 1)),
            vjust = -0.5
        ) +
        scale_x_continuous(breaks = weekly_runs$training_week) +
        expand_limits(y = 22) +
        labs(
            x = "Training week",
            y = "Total distance (km)"
        )
save_running_plot(plot_weekly_running_distance, "weekly-running-distance-1.png", width = 8, height = 5)

# ---- Values discussed in the post ----
print(weekly_runs |> filter(training_week %in% c(5, 6)) |>
          transmute(training_week, distance_change_percent = round(distance_change)))
saveRDS(runs, path(dir_out_datasets, "running-activities.rds"))
saveRDS(runs_detailed, path(dir_out_datasets, "running-records.rds"))
readr::write_csv(weekly_runs, path(dir_out_datasets, "running-weekly-summary.csv"))
DBI::dbDisconnect(con)
