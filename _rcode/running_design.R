# Visual identity for the running notebook

running_palette <-
    ghibli::ghibli_palette("YesterdayMedium") |>
        as.character() |>
        (\(colours) colours[c(7, 5, 3, 6, 4, 1)])()

theme_running <- function(base_size = 11, base_family = "") {
    panel_colour <- "#FAFAF7"

    ggplot2::theme_bw(
        base_size = base_size,
        base_family = base_family
    ) +
        ggplot2::theme(
            geom = ggplot2::element_geom(pointsize = 6),
            palette.colour.discrete = running_palette,
            palette.fill.discrete = running_palette,
            panel.background = ggplot2::element_rect(
                fill = panel_colour,
                colour = NA
            ),
            plot.background = ggplot2::element_rect(
                fill = "white",
                colour = NA
            ),
            legend.background = ggplot2::element_rect(
                fill = "white",
                colour = NA
            ),
            legend.key = ggplot2::element_rect(
                fill = "white",
                colour = NA
            ),
            panel.grid.major = ggplot2::element_line(
                colour = "#D8D2C6",
                linewidth = 0.35
            ),
            panel.grid.minor = ggplot2::element_blank(),
            panel.border = ggplot2::element_rect(
                colour = "#282828",
                fill = NA,
                linewidth = 0.6
            ),
            axis.text = ggplot2::element_text(colour = "#282828"),
            axis.title = ggplot2::element_text(colour = "#282828"),
            plot.title = ggplot2::element_text(
                colour = "#202020",
                face = "bold"
            ),
            legend.position = "bottom",
            legend.title = ggplot2::element_blank()
        )
}

ggplot2::theme_set(theme_running())
