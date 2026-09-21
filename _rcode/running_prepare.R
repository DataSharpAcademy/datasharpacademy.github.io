# Core data preparation from running notebook chapters 6 and 7.
#
# Source this file before continuing an analysis. It creates:
#   runs          - activities with programme features and average pace;
#   runs_detailed - moving records with activity features and record pace;
#   laps          - laps with distance, duration, heart-rate and pace features;
#   laps_labelled - all laps, classification flags and final segment_role.
# It also saves running-laps-labelled.rds in the project's _outputs/data.
# Plots, printed inspections and exploratory weekly summaries are omitted.
#
# From an RMD configured like the notebook chapters:
# source(file.path(knitr::opts_knit$get("base.dir"), "_rcode", "running_prepare.R"))
#
# Paths can be overridden before sourcing with options(running.project_dir = ...,
# running.output_dir = ...). The working directory is left unchanged.
# Refresh the Garmin database separately before running this script.

# ---- Ready the tools ----
library(dbplyr)
library(dplyr)
library(fs)
library(ggplot2)
library(hms)
library(stringr)
library(tidyr)

# ---- Locate the data ----
project_dir <- getOption(
    "running.project_dir",
    path(path_home(), "DataSharp", "enter-the-mind", "running")
)
dir_inputs <- path(project_dir, "_inputs")
dir_out_datasets <- getOption(
    "running.output_dir",
    path(project_dir, "_outputs", "data")
)
file_database <- path(dir_inputs, "DBs", "garmin_activities.db")
file_labelled_laps <- path(dir_out_datasets, "running-laps-labelled.rds")

# ---- Define the programme and classification rule ----
# No publication cutoff: include every available run since the programme began.
programme_start <- "2026-06-29"
analysis_end    <- "2026-09-12"
deload_weeks <- c(4, 7, 9)

# Activity-level exceptions from chapter 7; update as new easy runs are reviewed.
zone_2_activity_ids <- c(
    23419618478, 23666794029, 23964251201, 24124614928, 24169121176
)

# Distances are in kilometres; pace is in minutes per kilometre.
maximum_warm_up_laps      <- 4
maximum_warm_up_dist      <- 2.5
maximum_cool_down_laps    <- 3
maximum_cool_down_dist    <- 1.5
warm_up_pace_threshold    <- 5
warm_up_low_zone_share_threshold   <- 0.95
cool_down_low_zone_share_threshold <- 0.50

# ---- Extract the programme's activities, records and laps ----
# Read-only mode also prevents silently creating a database at a wrong path.
con <- DBI::dbConnect(
    RSQLite::SQLite(),
    dbname = file_database,
    flags = RSQLite::SQLITE_RO
)

# Close the connection even if a query fails. All processing below is in memory.
tryCatch({
    runs_db <-
        tbl(con, "activities") |>
            filter(
                sport == "running",
                start_time >= !!programme_start,
                start_time <= analysis_end
            )

    runs <- collect(runs_db)

    # Filter in SQLite before collecting, rather than loading unrelated records.
    records <-
        tbl(con, "activity_records") |>
            semi_join(
                runs_db |> select(activity_id),
                by = "activity_id"
            ) |>
            collect()

    laps <-
        tbl(con, "activity_laps") |>
            inner_join(
                runs_db |>
                    select(
                        activity_id,
                        activity_name = name,
                        activity_start_time = start_time
                    ),
                by = "activity_id"
            ) |>
            collect()
}, finally = {
    DBI::dbDisconnect(con)
})
rm(con, runs_db)

# ---- Chapter 6: engineer the run features ----
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

# ---- Chapter 6: attach activity features to the moving records ----
runs_detailed <-
    runs |>
        inner_join(records, by = "activity_id") |>
        filter(speed > 0) |>
        mutate(pace = 60 / speed) |>
        arrange(date, record)
rm(records)

# ---- Chapter 7: locate each lap within its activity ----
laps <-
    laps |>
        mutate(
            activity_date = as.Date(activity_start_time),
            activity_label = paste(activity_date, activity_name)
        ) |>
        group_by(activity_id) |>
        arrange(lap, .by_group = TRUE) |>
        mutate(
            distance_from_start = cumsum(distance),
            distance_from_end = rev(cumsum(rev(distance)))
        ) |>
        ungroup()

# ---- Chapter 7: derive lap duration, heart-rate shares and pace ----
# As in chapter 7, the positive unreported time is interpreted as Zone 0.
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

# Retain chapter 7's rounding correction, including its hidden RMD chunk.
laps <-
    laps |>
        mutate(low_zone_share = pmin(pmax(low_zone_share, 0), 1))

# ---- Chapter 7: classify continuous warm-up and cool-down boundaries ----
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

# ---- Save the chapter 7 restart point ----
dir_create(dir_out_datasets)
saveRDS(laps_labelled, file_labelled_laps)
