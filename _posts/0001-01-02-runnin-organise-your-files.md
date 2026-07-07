---
layout: default
title: "Organising your data"
date: 2026-07-14

notebook: running
chapter: 2

project: Project name

summary: >
  Choosing the right data is the first challenge of any real data project.

idea: >
  The data you collect determine the questions you can answer.

status: published

image: /images/notebooks/running/404.png

linkedin:
github:
---



### Use virtual environments to run Python scripts

Latest

```bash
uv run garmindb_cli.py --all --download --import --analyze --latest
```

Here we go, let's download our data.

<img
    class="post-image"
    src="{{ '/images/notebooks/running/garminDB-download.png' | relative_url }}"
    alt="Garmin dashboard">
