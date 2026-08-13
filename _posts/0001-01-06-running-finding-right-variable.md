---
layout: default
title: "Finding the right variable"
date: 2026-08-18 ## Change the date to release data

notebook: running
chapter: 6

project: Running

summary: >
  My Garmin database contains hundreds of variables. But the one I needed
  to answer a simple question was still not among them.

status: published ## Turn to published when published
sitemap: true ## Turn to true when published

image: /images/notebooks/running/main.png


keywords:
  - R
  - exploratory data analysis
  - feature engineering
  - data visualisation
  - running


linkedin:
github:
---

<div class="investigation-progress">

    <p class="investigation-progress-title">
        Running notebook: Investigation progress
    </p>

    <ul>
        <li>Getting hold of the data with a tool found on GitHub</li>
        <li>Understanding relational databases and how to load your data</li>
        <li>Structuring your workflow</li>
    </ul>

</div>

After weeks of teasing, this is finally it: we are about to start
analysing the data.

And no, I did not add five preliminary chapters just to keep you
waiting. Real data projects often take time before the first graph
appears. We needed to find the data, understand how they were stored,
bring them into R, and build a reproducible workspace.

We now have solid foundations. And hundreds of variables waiting for us.

That sounds like plenty. But having lots of variables does not mean
having the right one. The database contains what Garmin was designed to
record, not necessarily what I need to answer my question.

# A question I wasn’t planning to ask

I originally expected this first exploration to be about progress. Am I
running faster? Is my fitness improving?

But another question has become more pressing. Over the past week, I
have felt increasingly tired. I am still reaching the targets set by the
programme, but my energy on the days that follow sessions is lower than
I would expect. And yet, I don’t think my pace targets have increased
significantly.

So my first question for the data is not whether I am becoming faster.
It is: **Have I been doing too much, too quickly?**

> Sleep, nutrition, and work have been fairly constant. I therefore
> start by looking at the training, while keeping in mind that it may
> not be the only explanation.

The question is simple enough. Translating it into data is harder. Which
variable represents *doing too much*? Pace? Effort? Distance? Something
else?

This is where exploratory data analysis (“EDA”) begins. Rather than
plotting every available column and hoping for a pattern, we need to
find a variable that actually addresses the question.

# A reproducible start

As discussed in
<a href="{{ '/running-a-place-for-everything/' | relative_url }}" target="_blank" rel="noopener noreferrer">the
last chapter (A place for everything)</a>, I begin every analysis by
defining its environment. I am showing the setup again for consistency,
but I won’t re-explain the details.

``` r
# ---- Ready the tools ----
library(dbplyr)
library(dplyr)
library(fs)
library(ggplot2)
library(stringr)
library(tidyr)


# ---- Locate the headquarters ----
setwd(
    path(path_home(), "DataSharp", "enter-the-mind", "running")
)


# ---- Describe the project ----
dir_inputs  <- path("_inputs")
dir_outputs <- path("_outputs")

dir_out_figures  <- path(dir_outputs, "figs")
dir_out_datasets <- path(dir_outputs, "data")

dir_create(c(dir_outputs, dir_out_figures, dir_out_datasets))


# ---- Open the database connection ----
con <- DBI::dbConnect(
    RSQLite::SQLite(),
    dbname = path(
        dir_inputs,
        "DBs",
        "garmin_activities.db"
    )
)
```

Before opening R, I also run the following command to update the
databases with my latest Garmin data:

``` bash
cd Programs/garmindb
uv run garmindb_cli.py --all --download --import --analyze --latest
```

Then I collect the runs completed since the programme began:

``` r
runs <-
    tbl(con, "activities") |>
        filter(
            sport == "running",
            start_time >= "2026-06-29"
        ) |>
        collect()
```

At the time of writing, I have completed 13 runs. Each data point has
been hard-earned, but these observations are still very few. I won’t be
proving anything today. Fortunately, I only need enough information to
make a small, reversible decision about next week’s training.

# Hundreds of variables, but not the right ones

Garmin knows when I ran, how far I went, how fast my heart was beating,
and much more. But it does not know how those runs fit into my training
programme.

This context matters. My programme contains two sessions per week:
usually one longer run and one more intense session, such as tempo
intervals or hill repeats. Some weeks are deliberately lighter to favour
recovery (“deload” weeks).

I therefore need to create a few variables before the data can begin to
answer my question:

- `date` extracts the calendar date from Garmin’s timestamp;
- `training_week` places each run within the programme;
- `session_type` separates long runs, tempo sessions, hill sessions, and
  the time trial;
- `deload` identifies the lighter recovery weeks;
- `avg_pace` converts speed in kilometres per hour into the more
  familiar minutes per kilometre.

``` r
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
                TRUE                           ~ "Recovery"
            ),
            deload = if_else(
                training_week %in% c(4, 7),
                "Deload",
                "Regular"),
            avg_pace = 60 / avg_speed
        )

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
```

    ## # A tibble: 13 × 7
    ##    run_id date       training_week session_type deload  distance avg_pace
    ##     <int> <date>             <dbl> <chr>        <chr>      <dbl>    <dbl>
    ##  1      1 2026-06-29             1 Long run     Regular     7.52     6.35
    ##  2      2 2026-07-02             1 Hills        Regular     6.39     6.22
    ##  3      3 2026-07-06             2 Long run     Regular     7.01     6.02
    ##  4      4 2026-07-09             2 Tempo        Regular     6.16     5.87
    ##  5      5 2026-07-13             3 Long run     Regular     9.09     5.72
    ##  6      6 2026-07-17             3 Hills        Regular     7.65     6.44
    ##  7      7 2026-07-20             4 Long run     Deload      6.01     7.03
    ##  8      8 2026-07-23             4 Time trial   Deload      5.55     5.52
    ##  9      9 2026-07-28             5 Long run     Regular    10.0      5.54
    ## 10     10 2026-07-31             5 Tempo        Regular     6.63     5.61
    ## 11     11 2026-08-03             6 Long run     Regular    11.0      5.80
    ## 12     12 2026-08-06             6 Hills        Regular     9.35     6.49
    ## 13     13 2026-08-11             7 Recovery     Deload      6.49     7.44

This is `feature engineering` in its simplest form: translating my
knowledge of the project into variables the computer can use. Some
variables add context that Garmin does not have, while others transform
existing measurements into more useful units, such as pace instead of
speed.

Feature engineering is not merely cleaning before the analysis begins.
It determines which questions the data can answer.

> Do not let the available columns dictate your questions. If the
> variable you need is missing, build it.

# First candidate: average pace

My first candidate is average pace. If the recent sessions were too
demanding, perhaps I had simply been running too fast for my current
level.

``` r
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
```

<figure>
<img src="/images/notebooks/running/average-pace-over-time-1.png"
alt="Average pace across the first weeks of the programme. Lower values represent faster runs." />
<figcaption aria-hidden="true">Average pace across the first weeks of
the programme. Lower values represent faster runs.</figcaption>
</figure>

Pace improved quickly during the opening weeks before settling somewhere
around 5’30 to 5’50 per kilometre.

Four apparently slow runs stand out. Two were hill sessions, which
included hard uphill repetitions followed by walking recovery. Their
average pace makes them look easy when they were anything but. The other
two are runs from recovery weeks, which are meant to be slow.

> An unusual observation is not necessarily an error. Understand where
> it comes from before deciding what to do with it.

This is useful, although it is not the answer I was looking for. There
is no recent increase in average pace. If anything, I have slowed down
slightly. That makes average pace a poor explanation for the fatigue.

But average pace is also an imperfect representation of a run. The same
average can describe a steady effort, intervals, or short sprints
separated by walking. Before discarding pace entirely, I want to see
what the average is hiding.

## Is the average the right summary?

So far, I have used the `activities` table, which contains one summary
for each recorded activity. Another table, `activity_records`, contains
the measurements used to create those summaries.

This table cannot be filtered by `sport == "running"` as before because
that column is not included there, but `activity_id` connects it to my
runs. An `inner_join()` retains only the records belonging to both
tables.

``` r
runs_detailed <-
    runs |>
        inner_join(
            tbl(con, "activity_records") |>
                collect(),
            by = "activity_id"
        ) |>
        filter(speed > 0) |>
        mutate(pace = 60 / speed) |>
        arrange(date, record)
```

Each row now represents one measurement recorded during a run. I removed
records where speed equals zero because pace is undefined when there is
no movement.

``` r
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
```

<figure>
<img src="/images/notebooks/running/pace-distributions-by-run-1.png"
alt="Pace distributions within each run. White diamonds show the average pace." />
<figcaption aria-hidden="true">Pace distributions within each run. White
diamonds show the average pace.</figcaption>
</figure>

Each violin represents the distribution of pace measurements within one
run: the wider it is, the more time I spent running around that pace.
The white diamond is the average shown in the previous graph. I limited
the visible range to 3–12 min/km so that brief stops do not flatten the
useful part of the distributions.

> The warm-up and cool-down included at the beginning and end of each
> session add some noise to these plots. We will deal with them in a
> future chapter, but since they are fairly similar across sessions,
> they do not change the message here.

Now the structure of each run becomes visible. Long runs have a fairly
narrow distribution, while hill sessions contain several distinct paces:
short uphill efforts, recovery running, and some walking.

The graph explains why average pace can misrepresent some sessions. But
it does not explain why I am tired. Lesson learned: I do not need *more
data*; I need a *better variable* for the question.

# Second candidate: Garmin’s effort metrics

If pace cannot represent how demanding these sessions were, perhaps
Garmin’s ready-made effort metrics can.

These are engineered variables too. Garmin combines raw measurements
into convenient scores according to its own definition of effort. That
can be useful, but a variable does not become relevant to my question
simply because it is already available.

`training_load` estimates the physiological load created by each
activity. Here, the slow hill sessions no longer look easy. They sit
comfortably among the more demanding runs, while the deload sessions are
at the bottom.

``` r
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
```

<figure>
<img src="/images/notebooks/running/training-load-over-time-1.png"
alt="Training load tells a different story from average pace, particularly for hill sessions." />
<figcaption aria-hidden="true">Training load tells a different story
from average pace, particularly for hill sessions.</figcaption>
</figure>

I also looked at `training_effect`, which Garmin expresses on a scale
from 1 (a minor effect) to 5 (overreaching). The long runs from weeks 5
and 6 both sit above 4, so the data certainly agree that these were
challenging sessions.

``` r
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
```

<figure>
<img src="/images/notebooks/running/training-effect-over-time-1.png"
alt="Garmin’s training-effect score shows several demanding sessions, but no sudden break from one week to the next." />
<figcaption aria-hidden="true">Garmin’s training-effect score shows
several demanding sessions, but no sudden break from one week to the
next.</figcaption>
</figure>

These variables are closer to the idea of effort, but there is no clear
change. Week 3 was demanding too, and I handled it without unusual
fatigue.

Fatigue, however, can accumulate across several sessions. Perhaps I do
not need another variable from the database. Perhaps I need to engineer
one at the level of the training week.

# Engineering the variable I need

To represent accumulated training, I summarise the runs by week. This
changes the unit of observation: instead of one row per run, I want one
row per training week.

``` r
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

weekly_runs |>
    select(
        training_week,
        total_training_load,
        avg_training_effect,
        total_distance,
        distance_change
    )
```

    ## # A tibble: 7 × 5
    ##   training_week total_training_load avg_training_effect total_distance
    ##           <dbl>               <dbl>               <dbl>          <dbl>
    ## 1             1               259.                 3.6           13.9 
    ## 2             2               238.                 3.7           13.2 
    ## 3             3               306.                 3.85          16.7 
    ## 4             4               149.                 3.05          11.6 
    ## 5             5               265.                 3.85          16.7 
    ## 6             6               278.                 3.85          20.4 
    ## 7             7                86.8                3              6.49
    ## # ℹ 1 more variable: distance_change <dbl>

The `summarise()` step creates several weekly variables from the
individual runs. Training load and training effect do not stand out
compared with week 3. One thing does: training volume, represented here
by `total_distance`.

``` r
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
```

<figure>
<img src="/images/notebooks/running/weekly-running-distance-1.png"
alt="Total distance across completed training weeks. Weeks 4 and 7 were recovery weeks." />
<figcaption aria-hidden="true">Total distance across completed training
weeks. Weeks 4 and 7 were recovery weeks.</figcaption>
</figure>

Now we are onto something.

We already saw that the pace had not changed much, but the amount of
running at that pace had. One session was an 11-kilometre long run; the
other was a demanding hill workout covering more than 9 kilometres,
including twelve one-minute uphill efforts. Individually, neither looked
absurd. Together, they formed the largest week of the programme so far.

Week 6 was my first week above 20 kilometres. That is 22% more than week
5, immediately after a 44% increase following the deload week.

Weekly distance is the variable I had been looking for. It does not
measure fatigue directly, but it captures the recent increase in
training volume far better than any individual run could.

That gives me a plausible explanation for the fatigue I experienced over
the following days: my recent training volume may have increased faster
than I could recover from it.

# Enough information for a small decision

13 runs cannot establish that the increase in distance *caused* my
fatigue. But that is not quite the decision I need to make.

I feel tired, and the data show a sharp increase in running volume.
Reducing that volume for a week is a small, reversible response. I can
then see whether I feel better.

That is enough evidence for the decision at hand. I asked my running app
to reduce the mileage and turned week 7 into a recovery week. Regular
training will resume in week 8, hopefully with fresher legs.

# What’s next

The Garmin database contained hundreds of variables, yet the most useful
one was not among them. I had to combine distance, dates, and my
knowledge of the programme to create weekly running volume.

That is often what feature engineering is for: building the variables
that connect the available data to the question we actually want to
answer.

The running data are only an example. Every dataset reflects the system
that collected it, while our questions come from the problem we are
trying to solve. The two will not always align. Good EDA helps us
recognise that gap and decide what information is missing.

This exploration also exposed the next problem. Average pace cannot
meaningfully compare a long run, a tempo session, and hill repeats. All
of them also include a warm-up and cool-down. To study progress, I will
need to engineer another variable that better captures the training part
of each run.

Until then.

# By the way

Don’t forget to disconnect your database.

``` r
DBI::dbDisconnect(con)
```
