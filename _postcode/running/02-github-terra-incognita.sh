#!/usr/bin/env bash
# Chapter 2: GitHub: Terra Incognita

# cd path/to/my-analysis-folder # Replace with your folder path
uv venv

uv pip install garmindb

# Before downloading anything, open ~/.GarminDb/GarminConnectConfig.json and
# parameterise it with your own credentials, data dates, and project directory.
# Chapter 2 explains the settings and links to GarminDB's configuration template.

# When done, do the following:

cd Programs/garmindb
uv run garmindb_cli.py --all --download --import --analyze

# Subsequent updates:
# cd Programs/garmindb
# uv run garmindb_cli.py --all --download --import --analyze --latest
