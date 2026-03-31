#!/bin/bash
set -e

REPO="https://github.com/kamil/dzialaj-mi-tam"
DIR="${TMPDIR:-/tmp}/dzialaj-mi-tam"

if command -v git &>/dev/null; then
  rm -rf "$DIR"
  git clone --depth 1 "$REPO" "$DIR" 2>/dev/null
else
  echo "git is required"
  exit 1
fi

python3 "$DIR/patch.py"
