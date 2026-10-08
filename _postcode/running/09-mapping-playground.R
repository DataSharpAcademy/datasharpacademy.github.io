# Download your own Garmin database and adapt the working directory so the database can be found from it.
# Chapter 9: Mapping My Playground
# R >= 4.1 is required. Install the packages listed below before running.
# The expected database is _inputs/DBs/garmin_activities.db, produced by GarminDB.
# Results use your own activities; the notebook's values require its original data.

# ---- Ready the tools ----
# If needed, install once:
# install.packages(c("DBI", "RSQLite", "dbplyr", "dplyr", "fs", "ggplot2", "ghibli", "sf", "MASS", "plot3D", "viridisLite", "maptiles", "terra", "rnaturalearth", "rnaturalearthdata", "readr"))
library(DBI)
library(dbplyr)
library(dplyr)
library(fs)
library(ggplot2)
library(sf)
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

# ---- Programme and map settings ----
programme_start <- "2026-06-29"
# The published maps were rendered with data through 2 October:
# 16,206 local GPS records from 24 runs, plus the South African run.
analysis_end <- "2026-10-03" # Exclusive end; adapt for your own programme.
south_africa_activity_id <- 24169121176 # Kruger Running, 30 August 2026
# Replace this ID with your own distant route. If absent, the two local maps
# still run; the satellite panels require a matching recorded activity.
# For local maps, keep activities in one geographic area in de_gps below.
# Satellite backgrounds need internet access on their first download.

# ---- Read GPS records ----
con <- DBI::dbConnect(
    RSQLite::SQLite(),
    dbname = file_database,
    flags = RSQLite::SQLITE_RO
)

# Close the read-only connection even if an analysis step fails.
running_activities <- tbl(con, "activities") |>
    filter(sport == "running", start_time >= !!programme_start,
           start_time < !!analysis_end)

gps <- tbl(con, "activity_records") |>
    semi_join(running_activities, by = "activity_id") |>
    select(
        activity_id, record,
        position_long, position_lat
    ) |>
    collect()
DBI::dbDisconnect(con)

# ---- Clean coordinates and separate the distant run ----
gps <- gps |>
    tidyr::drop_na(position_long, position_lat) |>
    arrange(activity_id, record)

# Keep the South African run separate for its own map.
sa_gps <- gps |> filter(activity_id == south_africa_activity_id)
de_gps <- gps |> filter(activity_id != south_africa_activity_id)
if (nrow(de_gps) < 2L) stop("Local mapping needs at least two valid GPS records.")

# ---- Project coordinates into metres ----
map_centre <- c(
    lon = median(de_gps$position_long),
    lat = median(de_gps$position_lat)
)
cell_size_m <- 30
bandwidth_m <- 10

local_crs <- sprintf(
    "+proj=aeqd +lon_0=%.8f +lat_0=%.8f +datum=WGS84 +units=m +no_defs",
    map_centre[["lon"]], map_centre[["lat"]]
)
xy <- de_gps |>
    st_as_sf(coords = c("position_long", "position_lat"), crs = 4326) |>
    st_transform(local_crs) |>
    st_coordinates()

# Add the projected coordinates so we can work in metres.
de_gps <- de_gps |>
    mutate(
        x_m = xy[, "X"],
        y_m = xy[, "Y"],
        grid_x = as.integer(floor(x_m / cell_size_m)),
        grid_y = as.integer(floor(y_m / cell_size_m))
    )
map_points <- de_gps |>
    mutate(x_km = x_m / 1000, y_km = y_m / 1000)

# Leave a margin around the recorded routes.
x_limits <- range(map_points$x_km) + c(-1, 1) * 3 * bandwidth_m / 1000
y_limits <- range(map_points$y_km) + c(-1, 1) * 3 * bandwidth_m / 1000
map_theme <- theme_running() +
    theme(legend.title = element_text(), panel.grid.minor = element_blank())

# ---- GPS records represented in the maps ----
cat("Local GPS records:", nrow(map_points), "from",
    n_distinct(map_points$activity_id), "runs\n")

# ---- Draw and save the density map ----
density_floor <- 1e-3
density_map <- ggplot(map_points, aes(x_km, y_km)) +
    stat_density_2d(
        aes(fill = after_stat(pmax(ndensity, density_floor))),
        geom = "raster", contour = FALSE, n = 500,
        # MASS::kde2d divides h by four internally.
        h = rep(4 * bandwidth_m / 1000, 2)
    ) +
    scale_fill_viridis_c(
        option = "inferno", limits = c(density_floor, 1), transform = "log10",
        breaks = c(0.001, 0.01, 0.1, 1),
        labels = c("≤0.001", "0.01", "0.1", "1"),
        guide = guide_colourbar(barwidth = grid::unit(65, "mm"))
    ) +
    scale_x_continuous(limits = x_limits, expand = c(0, 0)) +
    scale_y_continuous(limits = y_limits, expand = c(0, 0)) +
    coord_equal() +
    labs(
        title = "Where my kilometres accumulate",
        x = "East of map centre (km)", y = "North of map centre (km)",
        fill = "Relative density\n"
    ) + map_theme
save_running_plot(density_map, "maps-density-1.png", height = 6)

# ---- Count entries into each grid cell ----
visits <-
    de_gps |>
        group_by(activity_id) |>
        arrange(record, .by_group = TRUE) |>
        mutate(
            new_visit = row_number() == 1L |
                grid_x != lag(grid_x) | grid_y != lag(grid_y)
        ) |>
        ungroup() |>
        filter(new_visit)

cell_counts <- visits |>
    count(grid_x, grid_y, name = "entries")

print(
    cell_counts |> arrange(desc(entries))
)

# ---- Prepare the grid matrix ----
# hist3D expects rows along x and columns along y, including empty cells.
entry_grid <- cell_counts |>
    tidyr::complete(
        grid_x = seq(min(grid_x), max(grid_x)),
        grid_y = seq(min(grid_y), max(grid_y)),
        fill = list(entries = 0)
    ) |>
    tidyr::pivot_wider(
        names_from = grid_y,
        values_from = entries,
        names_sort = TRUE
    ) |>
    arrange(grid_x)

x_centres_km <- (entry_grid$grid_x + 0.5) * cell_size_m / 1000
y_centres_km <- (as.numeric(names(entry_grid)[-1]) + 0.5) * cell_size_m / 1000

entry_matrix <- entry_grid |>
    select(-grid_x) |>
    as.matrix()

# ---- Save base graphics ----
save_base_plot <- function(filename, draw, width = 8, height = 7) {
    grDevices::png(path(dir_out_figures, filename),
                   width = width, height = height, units = "in", res = 150)
    on.exit(grDevices::dev.off(), add = TRUE)
    draw()
}

# ---- Draw and save the entry towers ----
draw_entry_towers <- function() {
    # Equal horizontal axis spans keep the ground-plane grid square.
    horizontal_span <- max(diff(range(x_centres_km)), diff(range(y_centres_km))) +
        cell_size_m / 1000
    plot3D::hist3D(
        x = x_centres_km, y = y_centres_km,
        z = replace(entry_matrix, entry_matrix == 0, NA_real_), # Hide empty cells.
        colvar = entry_matrix, col = viridisLite::viridis(100),
        clim = c(0, max(entry_matrix)), zlim = c(0, max(entry_matrix)), zmin = 0,
        xlim = mean(range(x_centres_km)) + c(-0.5, 0.5) * horizontal_span,
        ylim = mean(range(y_centres_km)) + c(-0.5, 0.5) * horizontal_span,
        space = 0.15, border = NA, shade = 0,
        theta = -60, phi = 25, expand = 0.65,
        ticktype = "detailed", bty = "b2",
        xlab = "East (km)", ylab = "North (km)", zlab = "Entries",
        clab = "Entries", main = "My most familiar ground",
        colkey = list(length = 0.5, width = 0.6, cex.axis = 0.8, cex.clab = 0.9)
    )
}
save_base_plot("maps-entry-towers-1.png", draw_entry_towers)
if (interactive()) draw_entry_towers()
readr::write_csv(cell_counts, path(dir_out_datasets, "running-map-cell-entries.csv"))

# ---- Draw the satellite panels when the distant route is available ----
if (nrow(sa_gps) >= 2L) {
    sa_route <-
        sa_gps |>
            arrange(record) |>
            st_as_sf(coords = c("position_long", "position_lat"), crs = 4326) |>
            st_transform(3857)

    sa_xy <- st_coordinates(sa_route)

    south_africa <- rnaturalearth::ne_countries(
        country = "South Africa", scale = 50, returnclass = "sf"
    ) |> st_transform(3857)

    # Country overview: include the coastline and a little surrounding space.
    overview_area <- st_as_sfc(st_bbox(
        c(xmin = 15, ymin = -36, xmax = 34, ymax = -21),
        crs = st_crs(4326)
    )) |> st_transform(3857)

    # Close-up: a square around the route, with room on every side.
    run_bbox <- st_bbox(sa_route)
    run_centre <- c(
        x = mean(run_bbox[c("xmin", "xmax")]),
        y = mean(run_bbox[c("ymin", "ymax")])
    )
    half_width <- max(
        run_bbox[["xmax"]] - run_bbox[["xmin"]],
        run_bbox[["ymax"]] - run_bbox[["ymin"]]
    ) * 0.65
    closeup_area <- st_as_sfc(st_bbox(
        c(
            xmin = run_centre[["x"]] - half_width,
            ymin = run_centre[["y"]] - half_width,
            xmax = run_centre[["x"]] + half_width,
            ymax = run_centre[["y"]] + half_width
        ),
        crs = st_crs(3857)
    ))

    imagery_provider <- "Esri.WorldImagery"
    # Cache downloaded tiles for subsequent runs.
    imagery_cache <- getOption("running.imagery_cache", path(dir_outputs, "running-tiles"))
    dir_create(imagery_cache)

    overview_tiles <- maptiles::get_tiles(
        overview_area, provider = imagery_provider, zoom = 6,
        crop = TRUE, project = FALSE, cachedir = imagery_cache
    )
    closeup_tiles <- maptiles::get_tiles(
        closeup_area, provider = imagery_provider, zoom = 17,
        crop = TRUE, project = FALSE, cachedir = imagery_cache
    )

    draw_satellite_panels <- function() {
        par(mfrow = c(1, 2), mar = c(0, 0, 2, 0), oma = c(3, 0, 0, 0))

        terra::plotRGB(overview_tiles, axes = FALSE, mar = c(0, 0, 2, 0))
        plot(st_geometry(south_africa), add = TRUE, border = "white", lwd = 1.2)
        points(run_centre[["x"]], run_centre[["y"]], pch = 21,
               bg = "#FFCC33", col = "#202020", cex = 1.6)
        text(run_centre[["x"]], run_centre[["y"]], labels = "Kruger",
             pos = 2, offset = 0.8, col = "white", font = 2)
        mtext("A. South Africa", cex=2, side = 3, line = 0.5, font = 2)

        terra::plotRGB(closeup_tiles, axes = FALSE, mar = c(0, 0, 2, 0))
        lines(sa_xy, col = "#202020", lwd = 4)
        lines(sa_xy, col = "#FFCC33", lwd = 2)
        points(sa_xy[c(1, nrow(sa_xy)), , drop = FALSE],
               pch = c(21, 24), bg = "white", col = "#202020", cex = 1.3)
        mtext("B. Kruger run · August 2026", cex=2, side = 3, line = 0.5, font = 2)

        imagery_credit <- paste(maptiles::get_credit(imagery_provider),
                                "Country outline: Natural Earth.")
        mtext(paste(strwrap(imagery_credit, width = 130), collapse = "\n"),
              side = 1, outer = TRUE, line = 0.6, cex = 0.65)
    }
    save_base_plot("maps-south-africa-1.png", draw_satellite_panels, width = 12, height = 6.5)
    if (interactive()) draw_satellite_panels()
} else {
    message("No GPS route for south_africa_activity_id = ", south_africa_activity_id,
            ". Set that ID to your own distant activity to draw the satellite panels.")
}
