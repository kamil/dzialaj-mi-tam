#!/bin/bash
set -e

BASE="https://raw.githubusercontent.com/kamil/dzialaj-mi-tam/master"
DIR="${TMPDIR:-/tmp}/dzialaj-mi-tam"

mkdir -p "$DIR/verbs"

curl -fsSL "$BASE/patch.rb" -o "$DIR/patch.rb"
for pack in pl skrzypas cursed chef corporate gym; do
  curl -fsSL "$BASE/verbs/${pack}.json" -o "$DIR/verbs/${pack}.json"
done

/usr/bin/ruby "$DIR/patch.rb" "$@"
