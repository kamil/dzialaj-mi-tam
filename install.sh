#!/bin/bash
set -e

REPO="https://github.com/kamil/dzialaj-mi-tam"
DIR="${TMPDIR:-/tmp}/dzialaj-mi-tam"

rm -rf "$DIR"
if ! git clone --depth 1 "$REPO" "$DIR" 2>/dev/null; then
  echo "Failed to clone. Is git installed?"
  exit 1
fi

/usr/bin/ruby "$DIR/patch.rb" "$@"
