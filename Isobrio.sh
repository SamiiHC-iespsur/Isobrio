#!/bin/sh
printf '\033c\033]0;%s\a' Isobrio
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Isobrio.x86_64" "$@"
