# Download your own Garmin database and adapt the working directory so the database can be found from it.
# Chapter 7: Extracting the signal from the background
# R >= 4.1 is required. Install the packages listed below before running.
# The expected database is _inputs/DBs/garmin_activities.db, produced by GarminDB.
# Results use your own activities; the notebook's values require its original data.

# ---- Ready the tools ----
# If needed, install once:
# install.packages(c("DBI", "RSQLite", "dbplyr", "dplyr", "fs", "ggplot2", "ghibli", "hms", "tidyr"))
library(DBI)
library(dbplyr)
library(dplyr)
library(fs)
library(ggplot2)
library(hms)
library(tidyr)

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

# ---- Programme, snapshot and classification rule ----
programme_start <- "2026-06-29"
# Exclusive end: all 19 runs and 303 laps through 30 August in the post.
analysis_end <- "2026-08-31"
# Activity-level exceptions from the notebook. Replace these IDs with your own
# continuous easy runs, which have no separate warm-up/work/cool-down blocks.
zone_2_activity_ids <- c(
    23419618478, 23666794029, 23964251201, 24124614928, 24169121176
)
file_labelled_laps <- path(dir_out_datasets, "running-laps-labelled.rds")

maximum_warm_up_laps      <- 4
maximum_warm_up_dist      <- 2.5
maximum_cool_down_laps    <- 3
maximum_cool_down_dist    <- 1.5
warm_up_pace_threshold    <- 5

warm_up_low_zone_share_threshold   <- 0.95
cool_down_low_zone_share_threshold <- 0.50

# ---- Open the database and reproduce the classification ----
con <- DBI::dbConnect(
    RSQLite::SQLite(),
    dbname = file_database,
    flags = RSQLite::SQLITE_RO
)

# Close the read-only connection even if an analysis step fails.
# ---- Load the laps and locate their boundaries ----
runs_db <-
    tbl(con, "activities") |>
        filter(
            sport == "running",
            start_time >= !!programme_start,
            start_time < !!analysis_end
        ) |>
        select(
            activity_id,
            activity_name = name,
            activity_start_time = start_time
        )

laps <-
    tbl(con, "activity_laps") |>
        inner_join(runs_db, by = "activity_id") |>
        collect() |>
        mutate(
            activity_date = as.Date(activity_start_time),
            activity_label = paste(activity_date, activity_name)
        ) |>
        group_by(activity_id) |>
        arrange(lap, .by_group = TRUE) |>
        mutate(
            distance_from_start = cumsum(distance),
            distance_from_end   = rev(cumsum(rev(distance)))
        ) |>
        ungroup()
if (nrow(laps) == 0L) stop("No running laps in the selected programme dates.")
cat("Laps:", nrow(laps), "from", n_distinct(laps$activity_id), "runs\n")

# ---- Calculate duration, pace and heart-rate shares ----
time_to_seconds <- function(x) {
    as.numeric(hms::as_hms(x))
}

laps <-
    laps |>
        mutate(
            lap_duration_seconds = time_to_seconds(moving_time),
            zone_1_seconds = time_to_seconds(hrz_1_time),
            zone_2_seconds = time_to_seconds(hrz_2_time),
            zone_3_seconds = time_to_seconds(hrz_3_time),
            zone_4_seconds = time_to_seconds(hrz_4_time),
            zone_5_seconds = time_to_seconds(hrz_5_time),
            tot_zone1_5_seconds = rowSums(
                pick(zone_1_seconds:zone_5_seconds),
                na.rm = TRUE
            ),
            zone_0_seconds = pmax(
                lap_duration_seconds - tot_zone1_5_seconds,
                0
            ),
            low_zone_share = if_else(
                lap_duration_seconds > 0,
                (zone_0_seconds + zone_1_seconds + zone_2_seconds) / lap_duration_seconds,
                NA_real_
            ),
            pace = if_else(
                !is.na(distance) & distance > 0,
                time_to_seconds(moving_time) / 60 / distance,
                NA_real_
            )
        )


print(
    laps |>
        select(
            activity_id,
            lap,
            distance_from_start,
            distance_from_end,
            low_zone_share,
            pace
        )
)

# ---- Correct rounding in the zone shares ----
laps <- laps |>
        mutate(low_zone_share = if_else(low_zone_share <= 0, 0, low_zone_share)) |>
        mutate(low_zone_share = if_else(low_zone_share >= 1, 1, low_zone_share))

# ---- Classify the laps ----
warm_up_laps <-
    laps |>
        filter(distance_from_start <= maximum_warm_up_dist) |>
            transmute(
                activity_id,
                lap,
                is_within_warm_up_distance = TRUE
            )

cool_down_laps <-
    laps |>
        filter(distance_from_end <= maximum_cool_down_dist) |>
            transmute(
                activity_id,
                lap,
                is_within_cool_down_distance = TRUE
            )

laps_labelled <-
    laps |>
        left_join(
            warm_up_laps,
            by = c("activity_id", "lap")
        ) |>
        left_join(
            cool_down_laps ,
            by = c("activity_id", "lap")
        ) |>
        group_by(activity_id) |>
        arrange(lap, .by_group = TRUE) |>
        mutate(
            lap_position = row_number(),
            laps_from_end = n() - row_number() + 1L,
            is_within_warm_up_distance = replace_na(
                is_within_warm_up_distance,
                FALSE
            ),
            is_within_cool_down_distance = replace_na(
                is_within_cool_down_distance,
                FALSE
            ),
            is_slow_enough_for_warm_up = replace_na(
                pace >= warm_up_pace_threshold,
                FALSE
            ),
            is_warm_up_candidate = replace_na(
                is_within_warm_up_distance &
                    is_slow_enough_for_warm_up &
                    low_zone_share >= warm_up_low_zone_share_threshold,
                FALSE
            ),
            is_cool_down_candidate = replace_na(
                is_within_cool_down_distance &
                    low_zone_share >= cool_down_low_zone_share_threshold,
                FALSE
            ),
            is_warm_up =
                lap_position <= maximum_warm_up_laps &
                cumall(is_warm_up_candidate),
            is_cool_down =
                laps_from_end <= maximum_cool_down_laps &
                rev(cumall(rev(is_cool_down_candidate))),
            segment_role = case_when(
                activity_id %in% zone_2_activity_ids ~ "zone_2",
                is_warm_up   ~ "warm_up",
                is_cool_down ~ "cool_down",
                TRUE         ~ "work"
            )
        ) |>
        ungroup()

# ---- Lookup tables ----
print(
    warm_up_laps |>
        transmute(
            activity_id,
            lap,
            is_within_warm_up_distance = TRUE
        )
)

# ---- Continuity examples from the post ----
is_warm_up_candidate <- c(TRUE, TRUE, FALSE, TRUE)
print(is_warm_up_candidate)
print(cumall(is_warm_up_candidate)) # TRUE TRUE FALSE FALSE
is_cool_down_candidate <- c(TRUE, FALSE, TRUE, TRUE)
print(rev(cumall(rev(is_cool_down_candidate))))
# The actual activity-level candidate flags remain in laps_labelled.

# ---- Inspect classified laps ----
plot_inspect_classified_laps <-
laps_labelled |>
    ggplot(
        aes(
            x = lap_position,
            y = distance,
            fill = segment_role
        )
    ) +
        geom_col() +
        facet_wrap(vars(activity_label), ncol = 3, scales = "free_x") +
        coord_cartesian(ylim = c(0, 1)) +
        labs(
            x = "Lap within activity",
            y = "Distance (km)",
            fill = "Classification"
        )
save_running_plot(plot_inspect_classified_laps, "inspect-classified-laps-1.png", width = 8, height = 10)

# ---- Inspect classified laps2 ----
plot_inspect_classified_laps2 <-
laps_labelled |>
    ggplot(
        aes(
            x = lap_position,
            y = low_zone_share,
            fill = segment_role
        )
    ) +
        geom_col() +
        facet_wrap(vars(activity_label), ncol = 3, scales = "free_x") +
        scale_y_continuous(
            limits = c(0, 1),
            labels = scales::label_percent()
        ) +
        labs(
            x = "Lap within activity",
            y = "Low-zone share",
            fill = "Classification"
        )
save_running_plot(plot_inspect_classified_laps2, "inspect-classified-laps2-1.png", width = 8, height = 10)

# ---- Inspect the later laps ----
print(
    laps_labelled |> select(start_time, lap, low_zone_share, segment_role) |> filter(start_time>="2026-08-17")#
)

# ---- Inspect classified laps3 ----
plot_inspect_classified_laps3 <-
laps_labelled |>
    ggplot(
        aes(
            x = lap_position,
            y = pace,
            fill = segment_role
        )
    ) +
        geom_col() +
        facet_wrap(vars(activity_label), ncol = 3, scales = "free_x") +
        scale_y_continuous(
            limits = c(0, 12)
        ) +
        labs(
            x = "Lap within activity",
            y = "Pace (min/km)",
            fill = "Classification"
        )
save_running_plot(plot_inspect_classified_laps3, "inspect-classified-laps3-1.png", width = 8, height = 10)

# ---- Save the classification and summarise its scope ----
saveRDS(laps_labelled, file_labelled_laps)
print(laps_labelled |> count(segment_role))
print(laps_labelled |> distinct(activity_id, segment_role) |> count(segment_role))
# Exact agreement with intended boundaries needs manual review of the plots;
# GarminDB contains no independent ground-truth labels for this rule.
DBI::dbDisconnect(con)
