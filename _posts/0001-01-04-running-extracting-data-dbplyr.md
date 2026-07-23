---
layout: default
title: "From SQLite to R"
date: 2026-01-01 ## Change the date to release data

notebook: running
chapter: 4

project: Running

summary: >
  Learn how to connect R to a SQLite database, explore its tables, and
  extract data with dbplyr (without writing SQL).

status: ongoing ## Turn to published when published
sitemap: false ## Turn to true when published

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
