#! /usr/bin/env bash

# sources the files in bash/*.bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for f in "$SCRIPT_DIR"/bash/*.bash; do
  [[ -f "$f" ]] && source "$f"
done
