#!/bin/sh
printf '\033c\033]0;%s\a' Gravity
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Gravity.x86_64" "$@"
