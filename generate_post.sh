#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./generate_post.sh [OPTIONS] NOTEBOOK CHAPTER
  ./generate_post.sh [OPTIONS] NOTEBOOK
  ./generate_post.sh [OPTIONS] CHAPTER
  ./generate_post.sh [OPTIONS]

Selection:
  running 4       Chapter 4 from the running notebook
  running         Every chapter from the running notebook
  4               Chapter 4 from every notebook
  (no selection)  Every chapter from every notebook

Options:
  --rebuild  Rebuild the full selection without the bulk confirmation
  --shutup   Suppress informational output (confirmation queries remain)
  -h, --help Show this help

Examples:
  ./generate_post.sh running 4
  ./generate_post.sh running
  ./generate_post.sh 4 --rebuild
  ./generate_post.sh --rebuild --shutup

The date, status, and sitemap are read from each RMD's YAML front matter.
EOF
}

say() {
  if [[ "$shutup" == false ]]; then
    printf "$@"
  fi
}

confirm() {
  local prompt=$1
  local response

  printf '%s [y/n] ' "$prompt"
  if ! IFS= read -r response; then
    printf '\nNo confirmation received; nothing was generated.\n' >&2
    return 1
  fi

  case "$response" in
    y|Y|yes|YES|Yes)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

front_matter_value() {
  local key=$1
  local file=$2

  awk -v key="$key" '
    NR == 1 && $0 == "---" {
      in_front_matter = 1
      next
    }

    in_front_matter && $0 == "---" {
      exit
    }

    in_front_matter {
      line = $0
      pattern = "^[[:space:]]*" key "[[:space:]]*:"

      if (line ~ pattern) {
        sub(pattern "[[:space:]]*", "", line)
        sub(/[[:space:]]*#.*/, "", line)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        gsub(/^["'\'']|["'\'']$/, "", line)
        print line
        exit
      }
    }
  ' "$file"
}

positionals=()
rebuild=false
shutup=false

for argument in "$@"; do
  case "$argument" in
    -h|--help)
      usage
      exit 0
      ;;
    --rebuild)
      rebuild=true
      ;;
    --shutup)
      shutup=true
      ;;
    -*)
      printf 'Unknown option: %s\n\n' "$argument" >&2
      usage >&2
      exit 1
      ;;
    *)
      positionals+=("$argument")
      ;;
  esac
done

if (( ${#positionals[@]} > 2 )); then
  printf 'Too many positional arguments.\n\n' >&2
  usage >&2
  exit 1
fi

notebook=""
chapter=""

case ${#positionals[@]} in
  0)
    ;;
  1)
    if [[ "${positionals[0]}" =~ ^[0-9]+$ ]]; then
      chapter=${positionals[0]}
    else
      notebook=${positionals[0]}
    fi
    ;;
  2)
    notebook=${positionals[0]}
    chapter=${positionals[1]}
    ;;
esac

if [[ -n "$notebook" ]] &&
   [[ ! "$notebook" =~ ^[[:alnum:]][[:alnum:]_-]*$ ]]; then
  printf 'Invalid notebook name: %s\n' "$notebook" >&2
  exit 1
fi

if [[ -n "$chapter" ]] && [[ ! "$chapter" =~ ^[0-9]+$ ]]; then
  printf 'Chapter must be a non-negative integer: %s\n' "$chapter" >&2
  exit 1
fi

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
rmd_root="$script_dir/_RMDs"
posts_dir="$script_dir/_posts"

if [[ ! -d "$rmd_root" ]]; then
  printf 'RMD directory not found: %s\n' "$rmd_root" >&2
  exit 1
fi

if [[ -n "$notebook" ]] && [[ ! -d "$rmd_root/$notebook" ]]; then
  printf 'Notebook directory not found: %s\n' "$rmd_root/$notebook" >&2
  exit 1
fi

sources=()
source_notebooks=()
source_chapters=()
source_statuses=()
source_sitemaps=()
output_names=()

while IFS= read -r candidate; do
  candidate_notebook=$(basename "$(dirname "$candidate")")
  candidate_chapter=$(front_matter_value "chapter" "$candidate")

  if [[ ! "$candidate_chapter" =~ ^[0-9]+$ ]]; then
    printf 'Skipping RMD without a numeric chapter: %s\n' "$candidate" >&2
    continue
  fi

  if [[ -n "$notebook" ]] && [[ "$candidate_notebook" != "$notebook" ]]; then
    continue
  fi

  if [[ -n "$chapter" ]] &&
     (( 10#$candidate_chapter != 10#$chapter )); then
    continue
  fi

  for index in "${!sources[@]}"; do
    if [[ "${source_notebooks[$index]}" == "$candidate_notebook" ]] &&
       (( 10#${source_chapters[$index]} == 10#$candidate_chapter )); then
      printf 'Multiple RMDs declare notebook "%s", chapter %s:\n' \
        "$candidate_notebook" "$candidate_chapter" >&2
      printf '  %s\n  %s\n' "${sources[$index]}" "$candidate" >&2
      exit 1
    fi
  done

  candidate_name=$(basename "$candidate")
  candidate_output="${candidate_name%.*}.md"

  for index in "${!output_names[@]}"; do
    if [[ "${output_names[$index]}" == "$candidate_output" ]]; then
      printf 'Multiple RMDs would generate the same post filename:\n' >&2
      printf '  %s\n  %s\n' "${sources[$index]}" "$candidate" >&2
      exit 1
    fi
  done

  candidate_status=$(front_matter_value "status" "$candidate")
  candidate_status=$(printf '%s' "$candidate_status" | tr '[:upper:]' '[:lower:]')
  candidate_sitemap=$(front_matter_value "sitemap" "$candidate")
  candidate_sitemap=$(printf '%s' "$candidate_sitemap" | tr '[:upper:]' '[:lower:]')

  sources+=("$candidate")
  source_notebooks+=("$candidate_notebook")
  source_chapters+=("$candidate_chapter")
  source_statuses+=("$candidate_status")
  source_sitemaps+=("$candidate_sitemap")
  output_names+=("$candidate_output")
done < <(
  find "$rmd_root" -mindepth 2 -maxdepth 2 \
    -type f -iname '*.rmd' ! -name '.generate-post.*' -print |
    sort
)

if (( ${#sources[@]} == 0 )); then
  if [[ -n "$notebook" && -n "$chapter" ]]; then
    printf 'No RMD found for notebook "%s", chapter %s.\n' \
      "$notebook" "$chapter" >&2
  elif [[ -n "$notebook" ]]; then
    printf 'No RMD chapters found for notebook "%s".\n' "$notebook" >&2
  elif [[ -n "$chapter" ]]; then
    printf 'No RMD found for chapter %s in any notebook.\n' \
      "$chapter" >&2
  else
    printf 'No RMD chapters found under %s.\n' "$rmd_root" >&2
  fi
  exit 1
fi

bulk_rebuild=false
if [[ -z "$notebook" || -z "$chapter" ]]; then
  bulk_rebuild=true
fi

if [[ "$bulk_rebuild" == true ]]; then
  say 'The following %d chapter(s) will be rebuilt:\n' "${#sources[@]}"

  for index in "${!sources[@]}"; do
    say '  %s, chapter %s -> _posts/%s\n' \
      "${source_notebooks[$index]}" \
      "${source_chapters[$index]}" \
      "${output_names[$index]}"
  done

  if [[ "$rebuild" == false ]]; then
    if ! confirm "Rebuild these ${#sources[@]} chapter(s)?"; then
      say 'Cancelled; nothing was generated.\n'
      exit 0
    fi
  fi
fi

unpublished_count=0
for index in "${!sources[@]}"; do
  if [[ "${source_statuses[$index]}" != "published" ]]; then
    unpublished_count=$((unpublished_count + 1))
  fi
done

if (( unpublished_count > 0 )); then
  say 'The following selected chapter(s) are not published:\n'

  for index in "${!sources[@]}"; do
    if [[ "${source_statuses[$index]}" != "published" ]]; then
      display_status=${source_statuses[$index]:-"missing"}
      say '  %s, chapter %s (status: %s)\n' \
        "${source_notebooks[$index]}" \
        "${source_chapters[$index]}" \
        "$display_status"
    fi
  done

  if ! confirm "Build ${unpublished_count} unpublished chapter(s) anyway?"; then
    say 'Cancelled; nothing was generated.\n'
    exit 0
  fi
fi

temp_rmd=""

cleanup() {
  if [[ -n "$temp_rmd" ]]; then
    rm -f "$temp_rmd"
  fi
}
trap cleanup EXIT INT TERM

render_source() {
  local source_rmd=$1
  local output_name=$2
  local force_sitemap=$3
  local source_dir
  local temp_base

  source_dir=$(dirname "$source_rmd")
  temp_base=$(mktemp "$source_dir/.generate-post.XXXXXX")
  temp_rmd="${temp_base}.RMD"
  mv "$temp_base" "$temp_rmd"

  awk -v force_sitemap="$force_sitemap" '
    NR == 1 {
      if ($0 != "---") {
        print "The RMD does not begin with YAML front matter." > "/dev/stderr"
        exit 2
      }

      in_front_matter = 1
      print
      next
    }

    in_front_matter && $0 == "---" {
      if (force_sitemap == "true" && !sitemap_seen) {
        print "sitemap: true"
      }

      print
      in_front_matter = 0
      front_matter_complete = 1
      next
    }

    in_front_matter && $0 ~ /^[[:space:]]*sitemap[[:space:]]*:/ {
      if (force_sitemap == "true") {
        print "sitemap: true"
      } else {
        print
      }

      sitemap_seen = 1
      next
    }

    {
      print
    }

    END {
      if (!front_matter_complete) {
        print "The RMD has incomplete YAML front matter." > "/dev/stderr"
        exit 2
      }
    }
  ' "$source_rmd" > "$temp_rmd"

  if [[ "$shutup" == true ]]; then
    Rscript -e '
      args <- commandArgs(trailingOnly = TRUE)

      if (!requireNamespace("rmarkdown", quietly = TRUE)) {
        stop(
          "The rmarkdown package is required. ",
          "Install it with install.packages(\"rmarkdown\")."
        )
      }

      rmarkdown::render(
        input = args[[1]],
        output_format = rmarkdown::md_document(
          variant = "gfm",
          preserve_yaml = TRUE
        ),
        output_file = args[[2]],
        output_dir = args[[3]],
        envir = new.env(parent = globalenv()),
        clean = TRUE,
        quiet = TRUE
      )
    ' "$temp_rmd" "$output_name" "$posts_dir" > /dev/null
  else
    Rscript -e '
      args <- commandArgs(trailingOnly = TRUE)

      if (!requireNamespace("rmarkdown", quietly = TRUE)) {
        stop(
          "The rmarkdown package is required. ",
          "Install it with install.packages(\"rmarkdown\")."
        )
      }

      rmarkdown::render(
        input = args[[1]],
        output_format = rmarkdown::md_document(
          variant = "gfm",
          preserve_yaml = TRUE
        ),
        output_file = args[[2]],
        output_dir = args[[3]],
        envir = new.env(parent = globalenv()),
        clean = TRUE,
        quiet = FALSE
      )
    ' "$temp_rmd" "$output_name" "$posts_dir"
  fi

  rm -f "$temp_rmd"
  temp_rmd=""
}

mkdir -p "$posts_dir"

for index in "${!sources[@]}"; do
  force_sitemap=false

  if [[ "${source_statuses[$index]}" == "published" ]] &&
     [[ "${source_sitemaps[$index]}" != "true" ]]; then
    force_sitemap=true
  fi

  say '\n[%d/%d] %s, chapter %s\n' \
    "$((index + 1))" \
    "${#sources[@]}" \
    "${source_notebooks[$index]}" \
    "${source_chapters[$index]}"

  render_source \
    "${sources[$index]}" \
    "${output_names[$index]}" \
    "$force_sitemap"

  say 'Generated: %s\n' "$posts_dir/${output_names[$index]}"

  if [[ "$force_sitemap" == true ]]; then
    say '  Set sitemap: true in the generated Markdown because the chapter is published.\n'
  fi
done

say '\nFinished rebuilding %d chapter(s).\n' "${#sources[@]}"
