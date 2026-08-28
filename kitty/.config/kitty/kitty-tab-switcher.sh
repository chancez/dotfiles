#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 osipog
# https://github.com/OsiPog/kitty-tab-switcher/blob/main/kitty-tab-switcher

echo "getting tabs"
# Get all tabs, including their ids and focused status
tab_info=$(kitty @ ls | jq -r '[
    .[].tabs[]
    | (.windows | first) as $window
    | ($window | .foreground_processes | first | .cmdline | first | split("/") | last) as $program
    | {
        title: ([
            $program,
            .title,
            ($window | .last_reported_cmdline),
            ($window | .cwd)
        ] | join(" | ")),
        id,
        is_focused,
        lines: $window | .lines,
        first_window_id: $window | .id,
    }
]
    | sort_by(.title)
    | reverse
    | sort_by(.is_focused)
    | reverse
')

# Use fzf to fuzzy search the tab titles
# shellcheck disable=SC2016
selected=$(
  echo "$tab_info" |
    jq -r ' .[] | (.id | tostring) + " | " + .title' |
    fzf \
      --height=100% \
      --margin=0 \
      --padding=0 \
      --border=none \
      --list-border=rounded \
      --info=hidden \
      --layout=reverse \
      --cycle
)

# If a tab was selected, focus on that tab using its ID
if [ -n "$selected" ]; then
  tab_id=$(echo "$selected" | awk '{print $1}')
  kitty @ focus-tab --match id:"$tab_id"
else
  echo "No tab selected or operation cancelled."
fi
