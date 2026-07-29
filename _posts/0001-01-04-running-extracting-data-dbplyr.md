---
layout: default
title: "From SQLite to R"
date: 2026-07-28 ## Change the date to release data

notebook: running
chapter: 4

project: Running

summary: >
  Learn how to connect R to a SQLite database, explore its tables, and
  extract data with dbplyr (without writing SQL).

status: published ## Turn to published when published
sitemap: true ## Turn to true when published

image: /images/notebooks/running/main.png


keywords:
  - R
  - dbplyr
  - SQL
  - SQLite
  - relational database
  - data extraction


linkedin:
github:
---

<div class="investigation-progress">

    <p class="investigation-progress-title">
        Running notebook: Investigation progress
    </p>

    <ul>
        <li>Getting hold of the data</li>
        <li>Using a tool discovered on GitHub</li>
        <li>Understanding how data are structured</li>
    </ul>

</div>

In the previous chapter, we explored how GarminDB organises our data
across a collection of connected tables. We now understand the
structure, but we still haven’t looked at a single observation.

Today, we finally look at the data—from the comfort of our R console.

In this chapter, I will show you how to connect to the SQLite databases
produced by GarminDB, explore what they contain, and extract only the
observations we need. This is the last building block before we can
start analysing the running data themselves.

# Meet the `dbplyr` R package

Relational databases are excellent at storing data and protecting their
integrity. They are equally good at returning precisely the data you
want.

Traditionally, communicating with a relational database meant learning
`SQL`. The language is still very much in use, but tools now exist that
can save you from having to write it yourself.

For R users who are familiar with the `tidyverse` but do not speak
`SQL`, the package `dbplyr` is a real game-changer.

<figure class="post-figure post-figure-small">

<img
        class="post-image"
        src="{{ '/images/notebooks/running/dbplyr-logo.png' | relative_url }}"
        alt="dbplyr package logo">

<figcaption class="post-caption">

Visit the
<a href="https://dbplyr.tidyverse.org/articles/dbplyr.html">dbplyr
webpage</a> to learn more about its multiple features.
</figcaption>

</figure>

You can think of `dbplyr` as a translation layer between you and the
database. You write familiar R code, and `dbplyr` converts it into `SQL`
behind the scenes.

For someone like me, who had to learn SQL to interact with databases
from the terminal and from Python or R, that still feels slightly mad.
But it works, and I strongly encourage you to use it.

Let’s see how.

> To be clear, I am not saying that learning SQL is useless. There are
> still situations where knowing some SQL will save you. But—as much as
> it hurts my old soul to admit it—you no longer need it for most
> day-to-day data extraction.

# Connecting R to the database

## Setting the scene

We will begin by creating a setup that can be reused throughout the rest
of this notebook.

A reliable analysis starts by deciding where you will work and which
tools you will need. Once that foundation is in place, everything that
follows becomes easier to reproduce.

I like to think of loading packages as bringing tools to a workbench.
Installing a package is like buying a tool and storing it on a shelf:
you own it, but it is not yet in your hands. Calling `library(package)`
takes it off the shelf and makes it ready to use.

``` r
library(dbplyr)
library(dplyr)
library(fs)
library(DBI)
```

Here, I am loading four packages:

- `dbplyr`: translates our R code into SQL;
- `dplyr`: provides the familiar tools we will use to manipulate the
  data;
- `fs`: makes file and folder paths easier to manage;
- `DBI`: provides the tools R needs to communicate with a database.

With the tools in your hands, the next step is to choose where to drop
them.

In R, the working directory is the folder from which relative paths are
resolved. Setting it explicitly means that every path in the analysis
starts from the same known location.

> Each project should have its own working directory.

Here I’m choosing to use my notebook root folder as working directory.
Everything we’ll use or create during this journey will be in that
folder.

``` r
setwd(
    path(path_home(), "DataSharp", "enter-the-mind", "running")
)
```

The `path()` function comes from `fs` and builds a path from a sequence
of folder names. This means we do not need to worry about whether our
operating system expects forward slashes or backslashes: `fs` handles
that detail for us. You only need to remember your computer folder
organisation.

## Connecting to the database

Before opening the database, let’s confirm that `garmin_activities.db`
is where we expect it to be (in the DBs folder of my working directory).

``` r
unlist( dir_map( "DBs", identity ) )
```

    ## [1] "DBs/garmin.db"            "DBs/garmin_activities.db"
    ## [3] "DBs/garmin_monitoring.db" "DBs/garmin_summary.db"   
    ## [5] "DBs/summary.db"

Next, we tell R to use this file as a data source. This creates a
connection object, which you can think of as an open communication
channel between R and the database.

``` r
con <- DBI::dbConnect(              ## Open the connection
    RSQLite::SQLite(),              ## Specify the database type
    dbname = "DBs/garmin_activities.db" ## Point to the database file
)
```

## Looking around: What’s available?

With the connection open, we can ask which tables are available:

``` r
dbListTables(con)
```

    ##  [1] "_attributes"              "activities"              
    ##  [3] "activities_devices"       "activity_laps"           
    ##  [5] "activity_records"         "activity_splits"         
    ##  [7] "climbing_activities"      "climbing_activities_view"
    ##  [9] "cycle_activities"         "cycle_activities_view"   
    ## [11] "hiking_activities_view"   "paddle_activities"       
    ## [13] "paddle_activities_view"   "running_activities_view" 
    ## [15] "steps_activities"         "steps_activities_view"   
    ## [17] "walking_activities_view"

## The important bit: lazy tables

We know from the
<a href="{{ '/running-relational-databases/' | relative_url }}">previous
chapter</a> that all activities are stored in the `activities` table.
Let’s take a look.

``` r
activities <- tbl(con, "activities")
activities
```

    ## # A query:  ?? x 49
    ## # Database: sqlite 3.53.1 [/Users/palaeosaurus/DataSharp/enter-the-mind/running/DBs/garmin_activities.db]
    ##    activity_id name            description type  course_id  laps sport sub_sport
    ##    <chr>       <chr>           <chr>       <chr>     <int> <int> <chr> <chr>    
    ##  1 22223733558 Strength        <NA>        unca…        NA     1 fitn… strength…
    ##  2 23628587479 Greifswald - W… <NA>        unca…        NA    41 runn… generic  
    ##  3 21489468656 Strength        <NA>        unca…        NA     1 fitn… strength…
    ##  4 23626819683 Greifswald Roa… <NA>        unca…        NA     1 cycl… road     
    ##  5 22992560216 Strength        <NA>        unca…        NA     1 fitn… strength…
    ##  6 22135165222 Strength        <NA>        unca…        NA     1 fitn… strength…
    ##  7 21371279305 Strength        <NA>        unca…        NA     1 fitn… strength…
    ##  8 23431579646 Strength        <NA>        unca…        NA     1 fitn… strength…
    ##  9 23087120252 Greifswald Roa… <NA>        unca…        NA     1 cycl… road     
    ## 10 22626536747 Greifswald Roa… <NA>        unca…        NA     2 cycl… road     
    ## # ℹ more rows
    ## # ℹ 41 more variables: device_serial_number <int>, self_eval_feel <chr>,
    ## #   self_eval_effort <chr>, training_load <dbl>, training_effect <dbl>,
    ## #   anaerobic_training_effect <dbl>, start_time <chr>, stop_time <chr>,
    ## #   elapsed_time <chr>, moving_time <chr>, distance <dbl>, cycles <dbl>,
    ## #   avg_hr <int>, max_hr <int>, avg_rr <dbl>, max_rr <dbl>, calories <int>,
    ## #   avg_cadence <int>, max_cadence <int>, avg_speed <dbl>, max_speed <dbl>, …

This is where `dbplyr` becomes particularly powerful. The `tbl()`
function creates a reference to the database table rather than importing
the complete table into R. When we print `activities`, `dbplyr`
retrieves just enough information to show us its columns, data types,
and a preview of the rows.

This reference is known as a *lazy table*. R does not even know how many
rows the table contains:

``` r
activities |> nrow()
```

    ## [1] NA

The slightly strange result is a feature, not a bug. The database may
contain millions of rows, so `dbplyr` avoids doing work until we
actually ask for it.

We can still manipulate the lazy table as if it were an ordinary R
object, although the data are still inside the database. `dbplyr`
records each step, translates it into SQL, and waits. Only when we call
`collect()` does the query run and the result enter R’s memory.

``` r
collect(activities) |> nrow()
```

    ## [1] 214

See the difference? `collect()` is the function that pulls the data into
R. Until then, `activities` is only a connection to a table inside the
database.

# Extracting run activities from the database

My `garmin_activities.db` database contains my runs, but it also
contains cycling, strength training, yoga, and a few other activities
that I am not interested in today. Some of the runs also predate the
training programme, which began on 29 June.

We can isolate the relevant runs by treating `activities` like an
ordinary data frame and writing a standard `dplyr` pipeline. We just
need to remember to call `collect()` at the end:

``` r
my_runs <-
    activities |>
        filter(sport == "running", start_time >= "2026-06-29") |>
        collect()
my_runs
```

    ## # A tibble: 7 × 49
    ##   activity_id name             description type  course_id  laps sport sub_sport
    ##   <chr>       <chr>            <chr>       <chr>     <int> <int> <chr> <chr>    
    ## 1 23628587479 Greifswald - W3… <NA>        unca…        NA    41 runn… generic  
    ## 2 23500264729 Greifswald - W2… <NA>        unca…        NA     9 runn… generic  
    ## 3 23583391001 Greifswald - W3… <NA>        unca…        NA    11 runn… generic  
    ## 4 23537301780 Greifswald - W2… <NA>        unca…        NA    15 runn… generic  
    ## 5 23455199693 Greifswald - W1… <NA>        unca…        NA    30 runn… generic  
    ## 6 23419618478 Greifswald - W1… <NA>        unca…        NA     9 runn… generic  
    ## 7 23666794029 Greifswald - W4… <NA>        unca…        NA     7 runn… generic  
    ## # ℹ 41 more variables: device_serial_number <int>, self_eval_feel <chr>,
    ## #   self_eval_effort <chr>, training_load <dbl>, training_effect <dbl>,
    ## #   anaerobic_training_effect <dbl>, start_time <chr>, stop_time <chr>,
    ## #   elapsed_time <chr>, moving_time <chr>, distance <dbl>, cycles <dbl>,
    ## #   avg_hr <int>, max_hr <int>, avg_rr <dbl>, max_rr <dbl>, calories <int>,
    ## #   avg_cadence <int>, max_cadence <int>, avg_speed <dbl>, max_speed <dbl>,
    ## #   ascent <dbl>, descent <dbl>, max_temperature <dbl>, …

With that, I only collected 7 rows out of the 200+ activities the table
contains. This was super fast, and will be easily updated as the
database grows alongside my training programme.

# Side note: What if I wanted to do this using SQL?

Behind the scenes, `dbplyr` translates the pipeline above into an SQL
query. You don’t need to know it but I still want to show you a SQL
request.

The structure is actually quite similar to the pipeline, although SQL
relies on its own specific keywords instead of using functions. Let’s
unpack it briefly:

``` r
query <- paste(
    "SELECT * ", ## Select every column
    "FROM activities ", ## Choose the table
    "WHERE sport = 'running' ", ## First filter
        "AND start_time >= '2026-06-29'" ## Second filter
)
```

We can then use the same `con` object to send this query directly to the
database:

``` r
my_runs_sql <-
    DBI::dbGetQuery(con, query) |> as_tibble()
```

Is the result exactly the same?

``` r
isTRUE(all.equal(my_runs, my_runs_sql))
```

    ## [1] TRUE

Yes it is!

# Wrap-up

We now have a direct route from the SQLite database into R. We know how
to open a connection, inspect the available tables, work with them
without loading everything into memory, and extract only the runs that
belong to this project.

Keeping the complete data collection inside the SQLite database while
extracting only the observations needed for a particular analysis gives
us the best of both worlds. The database remains the single source of
truth, while R works with small, analysis-ready datasets.

The preparation is finally over. From the next chapter onwards, we can
start investigating what the running data actually tell us.
