#!/usr/bin/env bash

set -euo pipefail

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
cd "$script_dir"

images=()
unused_images=()
case_mismatch_images=()
protected_images=()
source_files=()

if command -v rg >/dev/null 2>&1; then
  search_backend="rg"
else
  search_backend="grep"

  while IFS= read -r -d '' source_file; do
    source_files+=("$source_file")
  done < <(
    find "$script_dir" \
      \( \
        -path "$script_dir/.git" -o \
        -path "$script_dir/_site" -o \
        -path "$script_dir/.jekyll-cache" -o \
        -path "$script_dir/.sass-cache" -o \
        -path "$script_dir/.bundle" -o \
        -path "$script_dir/node_modules" -o \
        -path "$script_dir/vendor" \
      \) -prune -o \
      -type f \
      ! \( \
        -iname '*.avif' -o \
        -iname '*.bmp' -o \
        -iname '*.gif' -o \
        -iname '*.ico' -o \
        -iname '*.jpeg' -o \
        -iname '*.jpg' -o \
        -iname '*.png' -o \
        -iname '*.svg' -o \
        -iname '*.tif' -o \
        -iname '*.tiff' -o \
        -iname '*.webp' \
      \) \
      -print0
  )
fi

is_referenced() {
  local relative_path=$1
  local ignore_case=$2
  local case_option="--case-sensitive"

  if [[ "$search_backend" == "rg" ]]; then
    if [[ "$ignore_case" == true ]]; then
      case_option="--ignore-case"
    fi

    rg \
      --fixed-strings \
      --quiet \
      --hidden \
      "$case_option" \
      --glob '!.git/**' \
      --glob '!_site/**' \
      --glob '!.jekyll-cache/**' \
      --glob '!.sass-cache/**' \
      --glob '!.bundle/**' \
      --glob '!node_modules/**' \
      --glob '!vendor/**' \
      --glob '!*.avif' \
      --glob '!*.bmp' \
      --glob '!*.gif' \
      --glob '!*.ico' \
      --glob '!*.jpeg' \
      --glob '!*.jpg' \
      --glob '!*.png' \
      --glob '!*.svg' \
      --glob '!*.tif' \
      --glob '!*.tiff' \
      --glob '!*.webp' \
      -- \
      "$relative_path" \
      "$script_dir"
    return
  fi

  if (( ${#source_files[@]} == 0 )); then
    return 1
  fi

  if [[ "$ignore_case" == true ]]; then
    grep -I -F -i -q -- "$relative_path" "${source_files[@]}" 2>/dev/null
  else
    grep -I -F -q -- "$relative_path" "${source_files[@]}" 2>/dev/null
  fi
}

is_protected_image() {
  local relative_path=$1
  local filename
  filename=$(basename "$relative_path")

  case "$filename" in
    favicon.ico|favicon-*.png|favicon-*.svg|apple-touch-icon*|android-chrome-*)
      return 0
      ;;
  esac

  if [[ -f "$script_dir/README.md" ]] &&
     grep -I -F -i -q -- "$relative_path" "$script_dir/README.md" 2>/dev/null; then
    return 0
  fi

  return 1
}

while IFS= read -r -d '' image; do
  images+=("$image")
done < <(
  find "$script_dir" \
    \( \
      -path "$script_dir/.git" -o \
      -path "$script_dir/_site" -o \
      -path "$script_dir/.jekyll-cache" -o \
      -path "$script_dir/.sass-cache" -o \
      -path "$script_dir/.bundle" -o \
      -path "$script_dir/node_modules" -o \
      -path "$script_dir/vendor" \
    \) -prune -o \
    -type f \
    \( \
      -iname '*.avif' -o \
      -iname '*.bmp' -o \
      -iname '*.gif' -o \
      -iname '*.ico' -o \
      -iname '*.jpeg' -o \
      -iname '*.jpg' -o \
      -iname '*.png' -o \
      -iname '*.svg' -o \
      -iname '*.tif' -o \
      -iname '*.tiff' -o \
      -iname '*.webp' \
    \) \
    -print0
)

if (( ${#images[@]} == 0 )); then
  printf 'No image files were found.\n'
  exit 0
fi

for image in "${images[@]}"; do
  relative_path=${image#"$script_dir/"}

  if is_protected_image "$relative_path"; then
    protected_images+=("$image")
    continue
  fi

  if is_referenced "$relative_path" false; then
    continue
  fi

  if is_referenced "$relative_path" true; then
    case_mismatch_images+=("$image")
  else
    unused_images+=("$image")
  fi
done

printf 'Checked %d image file(s).\n' "${#images[@]}"
printf 'Protected %d favicon, app-icon, and README image(s).\n' \
  "${#protected_images[@]}"

if (( ${#case_mismatch_images[@]} > 0 )); then
  printf '\nWarning: %d image reference(s) differ in letter casing:\n' \
    "${#case_mismatch_images[@]}"

  for image in "${case_mismatch_images[@]}"; do
    printf '  %s\n' "${image#"$script_dir/"}"
  done

  printf 'These images were excluded from the deletion list. Fix their references before publishing on a case-sensitive host.\n'
fi

if (( ${#unused_images[@]} == 0 )); then
  printf '\n'
  printf 'No unused images were found.\n'
  exit 0
fi

printf '\nFound %d potentially unused image(s):\n' "${#unused_images[@]}"
for image in "${unused_images[@]}"; do
  printf '  %s\n' "${image#"$script_dir/"}"
done

printf '\nDelete these %d image(s)? [y/n] ' "${#unused_images[@]}"
if ! IFS= read -r response; then
  printf '\nNo confirmation received; nothing was deleted.\n' >&2
  exit 1
fi

case "$response" in
  y|Y|yes|YES|Yes)
    for image in "${unused_images[@]}"; do
      rm -f -- "$image"
      printf 'Deleted: %s\n' "${image#"$script_dir/"}"
    done

    printf 'Deleted %d unused image(s).\n' "${#unused_images[@]}"
    ;;
  *)
    printf 'Cancelled; nothing was deleted.\n'
    ;;
esac
