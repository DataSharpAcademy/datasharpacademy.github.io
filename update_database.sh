#!/usr/bin/env bash

set -euo pipefail

garmindb_dir="${HOME:?HOME is not set}/Programs/garmindb"

(
  cd "$garmindb_dir"
  uv run garmindb_cli.py --all --download --import --analyze --latest
)
