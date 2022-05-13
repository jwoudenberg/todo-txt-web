#!/usr/bin/env nix-shell
#! nix-shell -i bash -p entr
# shellcheck shell=bash

cat <<EOT > test-todos.txt
x do laundry
wash dishes
EOT
export PORT=8080
export TODO_TXT_PATH=test-todos.txt
export TITLE='Test Todos'
git ls-files | entr -ccr -s "nim r src/main.nim"
