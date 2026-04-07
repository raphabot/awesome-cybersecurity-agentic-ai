#!/usr/bin/env bash
set -euo pipefail

README="README.md"
EXIT_CODE=0

SECTIONS=(
  "MCP Servers"
  "Research"
  "Tools"
  "Frameworks"
  "Datasets"
  "Learning Resources/Podcast"
  "Communities"
)

extract_sort_key() {
  local line="$1"
  local key
  key=$(echo "$line" | sed -E 's/^- \[([^]]+)\]\(.*/\1/')
  key=$(echo "$key" | tr -d '`')
  echo "$key"
}

to_lower() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

for section in "${SECTIONS[@]}"; do
  entries=()
  keys=()

  while IFS= read -r line; do
    entries+=("$line")
    keys+=("$(extract_sort_key "$line")")
  done < <(awk -v sec="## ${section}" '
    $0 == sec { found=1; next }
    found && /^## / { exit }
    found && /^- \[/ { print }
  ' "$README")

  count=${#entries[@]}

  if (( count <= 1 )); then
    echo "* ${section}: ${count} entry/entries (ok)"
    continue
  fi

  section_ok=true
  for (( i=1; i<count; i++ )); do
    prev_lower=$(to_lower "${keys[$((i-1))]}")
    curr_lower=$(to_lower "${keys[$i]}")

    first_sorted=$(printf '%s\n%s\n' "$prev_lower" "$curr_lower" | LC_ALL=C sort | head -1)
    if [[ "$first_sorted" != "$prev_lower" ]]; then
      section_ok=false
      EXIT_CODE=1

      # Find correct insertion point among other entries
      before=""
      after=""
      for (( j=0; j<count; j++ )); do
        if (( j == i )); then continue; fi
        other_lower=$(to_lower "${keys[$j]}")
        first=$(printf '%s\n%s\n' "$other_lower" "$curr_lower" | LC_ALL=C sort | head -1)
        if [[ "$first" == "$other_lower" && "$other_lower" != "$curr_lower" ]]; then
          before="${keys[$j]}"
        elif [[ -z "$after" && "$first" == "$curr_lower" && "$other_lower" != "$curr_lower" ]]; then
          after="${keys[$j]}"
        fi
      done

      echo "X ${section}: \"${keys[$i]}\" is out of alphabetical order."
      if [[ -n "$before" && -n "$after" ]]; then
        echo "  -> It should be placed between \"${before}\" and \"${after}\"."
      elif [[ -z "$before" ]]; then
        echo "  -> It should be the first entry in this section (before \"${after}\")."
      else
        echo "  -> It should be the last entry in this section (after \"${before}\")."
      fi
      echo ""
    fi
  done

  if $section_ok; then
    echo "* ${section}: ${count} entries (ok)"
  fi
done

if (( EXIT_CODE == 0 )); then
  echo ""
  echo "All sections are in alphabetical order."
else
  echo ""
  echo "ERROR: Some sections have entries out of alphabetical order."
  echo "Please reorder the entries as indicated above."
fi

exit $EXIT_CODE
