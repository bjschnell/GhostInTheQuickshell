#!/bin/bash
#
# Holds a logind delay inhibitor and locks the session when suspend is announced.
#
# Ported from Omarchy 4's bin/omarchy-system-sleep-monitor (MIT, Copyright David
# Heinemeier Hansson).
#
# Quickshell has no general D-Bus client API, so logind's PrepareForSleep signal
# is read with dbus-monitor. `systemd-inhibit --mode=delay` is what buys the time
# to lock at all: without it logind suspends the moment it decides to, and the
# lock races the freeze.

GHOST_PATH="${GHOST_PATH:-$HOME/.local/src/Ghost}"

consume_sleep_events() {
    local line sleep_lock
    sleep_lock="$GHOST_PATH/src/scripts/sleep-lock.sh"

    while IFS= read -r line; do
        if [[ $line == *"boolean true"* ]]; then
            bash "$sleep_lock"
            return 0
        fi
    done
}

monitor_sleep_events() {
    local monitor_fd monitor_pid status

    coproc SLEEP_EVENTS {
        exec dbus-monitor --system \
            "type='signal',sender='org.freedesktop.login1',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'"
    }
    monitor_fd=${SLEEP_EVENTS[0]}
    monitor_pid=$SLEEP_EVENTS_PID

    cleanup_monitor() {
        kill "$monitor_pid" 2>/dev/null || true
        wait "$monitor_pid" 2>/dev/null || true
    }
    trap cleanup_monitor EXIT

    consume_sleep_events <&"$monitor_fd"
    status=$?
    cleanup_monitor
    trap - EXIT

    return "$status"
}

case ${1:-} in
    --consume)
        consume_sleep_events
        exit 0
        ;;
    --inhibited)
        monitor_sleep_events
        exit 0
        ;;
esac

exec systemd-inhibit \
    --what=sleep \
    --mode=delay \
    --who=Ghost \
    --why="Lock screen before suspend" \
    bash "$GHOST_PATH/src/scripts/sleep-monitor.sh" --inhibited
