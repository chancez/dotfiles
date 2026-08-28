#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 osipog
# https://github.com/OsiPog/kitty-tab-switcher/blob/main/kitty-tab-switcher

self_script=$(basename "$0")

echo "getting tabs"
# Get all tabs, including their ids and focused status. Tabs running the
# switcher are skipped: this run's own tab, plus any other switcher left open.
# Tabs keep the order kitty reports them in, so the number shown matches
# {sup.index} in the tab bar.
tab_info=$(kitty @ ls | jq -r --argjson self_window_id "${KITTY_WINDOW_ID:-0}" --arg self_script "$self_script" '[
    .[].tabs
    | to_entries[]
    | (.key + 1) as $number
    | .value
    | select(
        ([.windows[].id] | index($self_window_id) | not)
        and (any(.windows[].foreground_processes[].cmdline[]; endswith($self_script)) | not)
    )
    | (.windows | first) as $window
    | ($window | .foreground_processes | first | .cmdline | first | split("/") | last) as $program
    | {
        title: ([
            $program,
            .title,
            ($window | .last_reported_cmdline),
            ($window | .cwd)
        ] | join(" | ")),
        number: $number,
        id,
        is_focused,
        lines: $window | .lines,
        first_window_id: $window | .id,
    }
]')

# Use fzf to fuzzy search the tab titles. The tab id is carried in a hidden
# first field so only the tab number and title are displayed.
# shellcheck disable=SC2016
selected=$(
  echo "$tab_info" |
    jq -r ' .[] | [(.id | tostring), ((.number | tostring) + " | " + .title)] | @tsv' |
    fzf \
      --height=100% \
      --margin=0 \
      --padding=0 \
      --border=none \
      --list-border=rounded \
      --info=hidden \
      --layout=reverse \
      --cycle \
      --delimiter='\t' \
      --with-nth=2..
)

# If a tab was selected, focus on that tab using its ID
if [ -n "$selected" ]; then
  tab_id=$(echo "$selected" | cut -f1)
  kitty @ focus-tab --match id:"$tab_id"
else
  echo "No tab selected or operation cancelled."
fi
