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

# Scatterplot symbols with solid or dashed contours. geom_point() does not
# support linetype, so draw the notebook's circle and triangle as grid polygons.
running_point_grob <- function(x, y, shape, size, colour, alpha, linetype) {
    angles <- switch(
        as.character(shape),
        "16" = seq(0, 2 * pi, length.out = 73)[-73],
        "19" = seq(0, 2 * pi, length.out = 73)[-73],
        "17" = pi / 2 + (0:2) * 2 * pi / 3,
        stop("Running point contours support circles (16/19) and triangles (17).")
    )

    grid::polygonGrob(
        x = grid::unit(x, "native") + grid::unit(cos(angles) * size / 2, "mm"),
        y = grid::unit(y, "native") + grid::unit(sin(angles) * size / 2, "mm"),
        gp = grid::gpar(
            fill = scales::alpha(colour, alpha),
            col = scales::alpha("#282828", alpha),
            lty = linetype,
            lwd = 0.3 * 72.27 / 25.4,
            linejoin = "round"
        )
    )
}

GeomRunningPoint <- ggplot2::ggproto(
    "GeomRunningPoint", ggplot2::GeomPoint,
    default_aes = utils::modifyList(
        ggplot2::GeomPoint$default_aes,
        ggplot2::aes(linetype = "solid")
    ),
    draw_panel = function(data, panel_params, coord, na.rm = FALSE) {
        coords <- coord$transform(data, panel_params)
        symbols <- lapply(seq_len(nrow(coords)), function(i) {
            running_point_grob(
                coords$x[i], coords$y[i], coords$shape[i], coords$size[i],
                coords$colour[i], coords$alpha[i], coords$linetype[i]
            )
        })
        grid::gTree(children = do.call(grid::gList, symbols))
    },
    draw_key = function(data, params, size) {
        running_point_grob(
            0.5, 0.5, data$shape, data$size,
            data$colour, data$alpha, data$linetype
        )
    }
)

geom_running_point <- function(mapping = NULL, data = NULL, ...,
                               show.legend = NA, inherit.aes = TRUE) {
    ggplot2::layer(
        geom = GeomRunningPoint,
        mapping = mapping,
        data = data,
        stat = "identity",
        position = "identity",
        show.legend = show.legend,
        inherit.aes = inherit.aes,
        params = list(na.rm = FALSE, ...)
    )
}
