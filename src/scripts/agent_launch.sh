#!/bin/bash
# Launch an AI agent inside herdr, then bring its window to the front.
#
# Usage:
#   agent_launch.sh <label> --kind <claude|codex|...> [prompt]  # herdr-recognized agent
#   agent_launch.sh <label> --cmd  "<shell command>"            # plain command in a pane (e.g. ssh)
#
# In --kind mode, an optional 4th argument is submitted as the agent's first
# prompt right after it starts (via `herdr agent prompt`). Omit it to launch
# an empty session. If the agent isn't immediately ready (e.g. a first-run
# trust/theme prompt), wait for it to settle before prompting — herdr
# rejects a prompt sent to a blocked agent.
#
# Called (detached) from src/services/AgentLauncher.qml.

set -uo pipefail

label="$1"
mode="$2"
target="$3"
prompt="${4:-}"

resp=$(herdr workspace create --label "$label" --focus) || exit 1
pane_id=$(jq -r '.result.root_pane.pane_id' <<<"$resp")
ws_id=$(jq -r '.result.workspace.workspace_id' <<<"$resp")

[ -n "$pane_id" ] && [ "$pane_id" != "null" ] || exit 1
[ -n "$ws_id" ]   && [ "$ws_id"   != "null" ] || exit 1

herdr workspace focus "$ws_id" &>/dev/null
# Raising the ghostty window itself at the Hyprland level is not wired up yet —
# this box's Hyprland build routes dispatch through a custom Lua bridge (see
# ShellState.qml's configProvider) whose dispatcher for window focus/raise by
# class isn't known yet. Switch to it manually for now.

if [ "$mode" = "--kind" ]; then
    agent_name="${target}-$(date +%s%N | tail -c 7)"
    if ! herdr agent start "$agent_name" --kind "$target" --pane "$pane_id" &>/dev/null; then
        herdr agent wait "$agent_name" --until idle --timeout 120000 &>/dev/null || exit 1
    fi
    if [ -n "$prompt" ]; then
        herdr agent prompt "$agent_name" "$prompt" &>/dev/null
    fi
else
    herdr pane run "$pane_id" "$target" &>/dev/null
fi
