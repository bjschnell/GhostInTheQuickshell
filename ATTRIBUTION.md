# Attribution

Ghost is MIT licensed. Portions of it are derived from other MIT-licensed
projects, whose copyright notices are reproduced below as that license requires.

## Omarchy

<https://github.com/basecamp/omarchy> — Copyright (c) David Heinemeier Hansson

Omarchy 4 replaced hyprlock and hypridle with Quickshell, and Ghost's lock
screen and lock-before-suspend pipeline are ported from that work. Derived
files, each of which also carries an attribution note in its own header:

| Ghost | Omarchy |
| --- | --- |
| `src/services/system/LockService.qml` | `shell/plugins/lock/Service.qml` |
| `src/windows/LockView.qml` | `shell/plugins/lock/LockView.qml` |
| `src/scripts/session-locked.sh` | `bin/omarchy-hyprland-session-locked` |
| `src/scripts/sleep-lock.sh` | `bin/omarchy-system-sleep-lock` |
| `src/scripts/sleep-monitor.sh` | `bin/omarchy-system-sleep-monitor` |
| `src/scripts/install-lock-pam.sh` | `bin/omarchy-apply-lock` |
| `src/config/logind-inhibit-delay.conf` | `etc/systemd/logind.conf.d/20-inhibit-delay.conf` |
| `src/services/system/PolkitService.qml` | `shell/plugins/polkit/PolkitAgent.qml`, `PolkitModel.js` |
| `src/windows/PolkitDialog.qml` | `shell/plugins/polkit/PolkitAgent.qml` |

`src/services/system/IdleService.qml` is *not* ported from Omarchy. Their idle
service chains a single `IdleMonitor` to manual timers because launching their
terminal screensaver generates input the compositor reports as activity. Ghost
has no screensaver, so it uses one monitor per stage, which is both simpler and
closer to how hypridle's listener blocks behaved.

### MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
