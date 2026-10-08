# Download your own Garmin database and adapt the working directory so the database can be found from it.
# Chapter 8: The five miles I never ran
# R >= 4.1 is required. Install the packages listed below before running.
# The expected database is _inputs/DBs/garmin_activities.db, produced by GarminDB.
# Results use your own activities; the notebook's values require its original data.

# ---- Ready the tools ----
# If needed, install once:
# install.packages(c("DBI", "RSQLite", "dbplyr", "dplyr", "fs", "ggplot2", "ghibli", "hms", "stringr", "tidyr", "readr"))
library(DBI)
library(dbplyr)
library(dplyr)
library(fs)
library(ggplot2)
library(hms)
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
    if (!isTRUE(getOption("running.make_plots", TRUE))) {
        return(invisible(plot))
    }
    print(plot)
    ggplot2::ggsave(
        filename = path(dir_out_figures, filename),
        plot = plot, width = width, height = height, units = "in", dpi = 150
    )
}

# ---- Recollect chapters 6 and 7 from the database ----
file_labelled_laps <- path(dir_out_datasets, "running-laps-labelled.rds")
# ---- Define the programme and classification rule ----
# Publication snapshot: retain the original cutoff for the fourteen trimmed workouts.
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
DBI::dbDisconnect(con)
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
saveRDS(laps_labelled, file_labelled_laps)

# ---- Check the collected programme ----
if (nrow(runs) == 0L) stop("No runs in the selected programme dates.")

# ---- Five-mile settings ----
target_miles <- 5
target_km <- target_miles * 1.609344 # My data are in kilometres
riegel_exponent <- 1.06

# Start forecasting on the day after the latest recorded running activity.
forecast_origin <- max(runs$date, na.rm = TRUE) + 1
race_date <- as.Date("2026-11-28")
# Dates, deload_weeks, and zone_2_activity_ids above describe the original
# programme. Adapt them to analyse your own training.

# ---- Five mile workout boundaries ----
work_boundaries <-
    laps_labelled |>
        filter(segment_role == "work") |>
        group_by(activity_id) |>
        summarise(
            work_start = min(as.POSIXct(start_time, tz = "UTC")),
            work_stop = max(as.POSIXct(stop_time, tz = "UTC")),
            .groups = "drop"
        )

print(work_boundaries)

# ---- Five mile workout records ----
workout_records <-
    runs_detailed |>
        transmute(
            activity_id,
            timestamp = as.POSIXct(timestamp, tz = "UTC"),
            # The chapter 6 join kept activity distance as distance.x and
            # cumulative record distance as distance.y.
            distance = distance.y
        ) |>
        inner_join(work_boundaries, by = "activity_id") |>
        filter(
            timestamp >= work_start,
            timestamp <= work_stop,
            is.finite(distance)
        ) |>
        group_by(activity_id) |>
        arrange(timestamp, .by_group = TRUE) |>
        ungroup()

# ---- Five mile workout totals ----
workout_totals <-
    workout_records |>
        group_by(activity_id) |>
        summarise(
            source_distance_km = last(distance) - first(distance),
            source_time_seconds = as.numeric(
                difftime(last(timestamp), first(timestamp), units = "secs")
            ),
            .groups = "drop"
        )


print(
    workout_totals |>
        mutate(longer_than_5miles = source_distance_km >= target_km)
)
if (nrow(workout_totals) == 0L ||
    any(workout_totals$source_distance_km <= 0 | workout_totals$source_time_seconds <= 0)) {
    stop("Forecasting needs workouts with positive retained distance and duration.")
}
print(workout_totals |> summarise(
    workouts = n(), minimum_km = min(source_distance_km),
    maximum_km = max(source_distance_km), target_km = target_km
))

# ---- Calculate distance-scaling corrections ----
scaling_corrections <- tibble(
    distance_ratio = seq(1, 6, length.out = 200),
    `Fixed 10%` = 10,
    Riegel = 100 * (distance_ratio ^ (riegel_exponent - 1) - 1)
) |>
    pivot_longer(
        cols = c(`Fixed 10%`, Riegel),
        names_to = "method",
        values_to = "correction_percent"
    )

# ---- Distance scaling correction ----
plot_distance_scaling_correction <-
ggplot(scaling_corrections,
       aes(distance_ratio, correction_percent, colour = method,
           linetype = method)) +
    geom_line(linewidth = 1) +
    scale_x_continuous(breaks = 1:6) +
    scale_y_continuous(labels = function(x) paste0(x, "%")) +
    labs(
        x = "Distance ratio (target / recorded)",
        y = "Correction above constant pace",
        colour = NULL, linetype = NULL
    ) +
    theme_running()
save_running_plot(plot_distance_scaling_correction, "distance-scaling-correction-1.png", width = 8, height = 4)

# ---- Apply the two scenarios ----
five_mile_performances <-
    workout_totals |>
        left_join(
            runs |> select(activity_id, date, session_type, deload),
            by = "activity_id"
        ) |>
        mutate(
            distance_ratio = target_km / source_distance_km,
            constant_pace_seconds = source_time_seconds * distance_ratio,
            riegel_seconds = source_time_seconds * distance_ratio ^ riegel_exponent,
            constant_pace_minutes = constant_pace_seconds / 60 / target_km,
            riegel_minutes = riegel_seconds / 60 / target_km
        ) |>
        arrange(date)


print(
    five_mile_performances |>
        select(source_distance_km, distance_ratio, constant_pace_minutes, riegel_minutes)
)

# ---- Plot the five-mile projections ----
projection_points <-
    five_mile_performances |>
        pivot_longer(
            cols = c(riegel_minutes, constant_pace_minutes),
            names_to = "scenario",
            values_to = "projected_pace"
        ) |>
        mutate(
            scenario = factor(
                scenario,
                levels = c("riegel_minutes", "constant_pace_minutes"),
                labels = c("Conservative (Riegel)", "Optimistic (constant pace)")
            )
        ) |>
        # Draw the opaque symbol last when both scenarios coincide.
        arrange(desc(scenario))


projection_plot <-
    ggplot(
        projection_points,
        aes(
            x = date,
            y = projected_pace,
            colour = session_type,
            shape = deload,
            alpha = scenario
        )
    ) +
        geom_smooth(
            data = five_mile_performances,
            aes(x = date, y = riegel_minutes),
            inherit.aes = FALSE,
            method = "lm",
            formula = y ~ x,
            se = FALSE,
            colour = "grey40",
            linewidth = 0.8
        ) +
        geom_point(size = 6) +
        scale_shape_manual(values = c("Deload" = 16, "Regular" = 17)) +
        scale_alpha_manual(values = c(1, 0.5)) +
        scale_y_reverse() +
        scale_x_date(date_breaks = "2 weeks", date_labels = "%d %b") +
        labs(
            x = NULL,
            y = paste(target_miles, "mile projected pace (min/km)"),
            colour = "Session", shape = "Training week",
            alpha = "Scenario"
        ) +
        theme_running() +
        theme(legend.box = "vertical") +
        guides(
            colour = guide_legend(order = 1, nrow = 1,
                                 override.aes = list(shape = 16, alpha = 1)),
            shape = guide_legend(order = 2,
                                override.aes = list(alpha = 1)),
            alpha = guide_legend(order = 3)
        )

save_running_plot(projection_plot, "five-mile-projection-scatter-1.png", height = 6)

# ---- Fit the pace trends ----
forecast_runs <-
    five_mile_performances |>
        filter(session_type %in% c("Long run", "Tempo", "Time trial"))

if (nrow(forecast_runs) < 3L || n_distinct(forecast_runs$date) < 2L) {
    stop("The linear forecast needs at least three eligible workouts on distinct dates.")
}
pace_trend_model <- lm(riegel_minutes ~ date, data = forecast_runs)
pace_change_per_day <- unname(coef(pace_trend_model)["date"])
print(summary(pace_trend_model))

# Compare the same scenario before and after selecting session types.
all_session_model <- lm(riegel_minutes ~ date,
                        data = five_mile_performances)
all_session_slope <- unname(coef(all_session_model)["date"])
slope_interval <- confint(pace_trend_model, "date")
print(summary(all_session_model))

# ---- Forecast tomorrow and race day ----
# Retain the post's fixed 16 September forecast date for reproducibility.
# For a new forecast, replace it with forecast_origin.
forecast_dates <- tibble(
    occasion = c("Tomorrow", "Race day"),
    date = c(as.Date("2026-09-16"), race_date)
)

predictions_conf <- predict(
    pace_trend_model,
    newdata = forecast_dates,
    interval = "confidence",
    level = 0.95
)

print(predictions_conf)


predictions <- predict(
    pace_trend_model,
    newdata = forecast_dates,
    interval = "prediction",
    level = 0.95
)

print(predictions)

# ---- Convert pace to finish times ----
five_mile_forecasts <-
    bind_cols(forecast_dates, as_tibble(predictions)) |>
        mutate(
            finish_minutes = fit * target_km,
            lower_minutes = lwr * target_km,
            upper_minutes = upr * target_km,
            days_beyond_data = as.integer(date - max(forecast_runs$date))
        )

# ---- Display the forecast table ----
format_minutes <- function(minutes) {
    seconds <- as.integer(round(minutes * 60))
    sprintf("%d:%02d", seconds %/% 60L, seconds %% 60L)
}

forecast_table <- five_mile_forecasts |>
    transmute(
        Forecast = occasion,
        Date = format(date, "%d %b %Y"),
        `Pace (min/km)` = format_minutes(fit),
        `Five miles (min:sec)` = format_minutes(finish_minutes),
        `95% prediction range (min:sec)` = paste(
            format_minutes(lower_minutes),
            format_minutes(upper_minutes),
            sep = "–"
        )
    )
print(forecast_table)

# ---- Trend values discussed in the post ----
print(tibble(
    selected_workouts = nrow(forecast_runs),
    observed_days = as.integer(diff(range(forecast_runs$date))),
    all_session_slope = all_session_slope,
    selected_session_slope = pace_change_per_day,
    slope_lower_95 = slope_interval[1], slope_upper_95 = slope_interval[2],
    improvement_seconds_per_km_per_day = -pace_change_per_day * 60,
    improvement_seconds_per_km_per_week = -pace_change_per_day * 60 * 7,
    improvement_five_mile_seconds_per_week = -pace_change_per_day * 60 * 7 * target_km
))
readr::write_csv(five_mile_performances, path(dir_out_datasets, "five-mile-performances.csv"))
readr::write_csv(five_mile_forecasts, path(dir_out_datasets, "five-mile-forecasts.csv"))
readr::write_csv(forecast_table, path(dir_out_datasets, "five-mile-forecast-table.csv"))
saveRDS(pace_trend_model, path(dir_out_datasets, "five-mile-pace-trend.rds"))
