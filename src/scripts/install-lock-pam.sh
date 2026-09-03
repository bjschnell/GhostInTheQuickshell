#!/bin/bash
#
# Configures PAM for the Quickshell lock screen. Needs root to write
# /etc/pam.d — run it directly, it will call sudo itself if needed.
#
# Ported from Omarchy 4's bin/omarchy-apply-lock (MIT, Copyright David
# Heinemeier Hansson).
#
# LockService.qml watches /etc/pam.d/ghost-lock-password and refuses to lock
# until it exists, so a half-configured system cannot strand you behind a lock
# screen that can never authenticate.

set -e

target_user=${SUDO_USER:-$USER}

as_root() {
    if (( EUID == 0 )); then
        "$@"
    else
        sudo "$@"
    fi
}

echo "Configuring lock screen password authentication..."

# pam_faillock rate-limits brute force at the lock screen; without it a lock
# screen will accept guesses as fast as they can be typed.
as_root tee /etc/pam.d/ghost-lock-password >/dev/null <<'PAM'
#%PAM-1.0
auth       required                    pam_faillock.so preauth silent deny=10 unlock_time=120
-auth      [success=2 default=ignore]  pam_systemd_home.so
auth       [success=1 default=bad]     pam_unix.so try_first_pass nullok
auth       [default=die]               pam_faillock.so authfail deny=10 unlock_time=120
auth       optional                    pam_permit.so
auth       required                    pam_env.so
auth       required                    pam_faillock.so authsucc
account    include                     system-local-login
PAM

if command -v fprintd-list >/dev/null 2>&1 \
   && fprintd-list "$target_user" 2>/dev/null | grep -qi finger; then
    echo "Configuring lock screen fingerprint authentication..."
    as_root tee /etc/pam.d/ghost-lock-fingerprint >/dev/null <<'PAM'
#%PAM-1.0
auth       required                    pam_fprintd.so
account    include                     system-local-login
PAM
else
    as_root rm -f /etc/pam.d/ghost-lock-fingerprint
fi

echo "Lock screen authentication configured."
