---
layout: default
title: "Structure from the start"
date: 2026-01-01

notebook: running
chapter: 2

project: Running

summary: >
  Abstract

status: ongoing

keywords:
  -


linkedin:
github:
---



I could have spent several evenings writing code to extract and reorganise the Garmin files myself. But that's not the problem I’m interested in solving.



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
