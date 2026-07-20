---
layout: default
title: "From SQLite to R"
date: 2026-01-01 ## Change the date to release data

notebook: running
chapter: 4

project: Running

summary: >
  Abstract

status: ongoing ## Turn to published when published
sitemap: false ## Turn to true when published

image: /images/notebooks/running/main.png


keywords:
  -


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


How do I actually retrieve the information I need?

This chapter does not answer questions. It nrings the final building block needed before we can do that.

# Introduction

The database now makes sense, but it is far too large to analyse as it is.

and there are too many different activities stored together.

We need a way to retrieve only the observations relevant to our project.

# doing everything in R

## connecting to db

Explain that the connection is just a doorway.

## looking around
```R
dbListTables()
```

```R
glimpse(tbl(con, "activities"))
```
## Lazy evaluation

```R
activities <-
    tbl(con, "activities")
```
    doesn't retrieve anything

```R
    collect()
```

# Showcase some data extractions



# When dbplyr isn’t enough

Show how data can be extracted using SQL directly.


# Wrap-up

This is it. We now have everything we need to start investigating our data.
