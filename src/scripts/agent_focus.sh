#!/bin/bash
# Bring an already-running agent's herdr workspace to the front.
# Called (detached) from src/services/AgentLauncher.qml.

ws_id="$1"

herdr workspace focus "$ws_id" &>/dev/null
# See agent_launch.sh — raising the ghostty window at the Hyprland level
# isn't wired up yet; switch to it manually for now.
