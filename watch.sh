#!/usr/bin/env nix-shell
#! nix-shell -i bash -p entr
# shellcheck shell=bash

export PORT=8080
export TODO_TXT_PATH=test-todos.txt
git ls-files | entr -ccr -s "nim r src/main.nim"
