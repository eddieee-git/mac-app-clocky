# Changelog

Details for each version are in [docs/releases](docs/releases) and [GitHub Releases](https://github.com/eddieee-git/mac-app-clocky/releases). 한국어: [CHANGELOG.md](CHANGELOG.md)

## 0.3.2 (2026-11-20)

- Keeps your Mac from sleeping on its own while a timer runs and from 10 minutes before an alarm or event (can be turned off in Settings)
- Missed alerts: alarms, timers, and events that couldn't ring because the Mac was asleep or Clocky was quit appear in the clock window and the menu bar menu
- Warning when something will ring soon and your Mac's sound is off
- Past dates show as "yesterday"

## 0.3.1 (2026-11-19)

- Install new versions automatically is now on by default: Clocky downloads, replaces itself, and relaunches while you're not using it (it waits while something is ringing)
- **Check for Updates…** and **Install Version X…** install right away without asking
- A window appears only when an update can't be installed from inside the app (once per version for automatic checks)

## 0.3.0 (2026-11-15)

- Updates install from inside the app and relaunch: **Install and Relaunch**, like the other apps, and **Install new versions automatically** in Settings (off by default). Automatic installs wait while something is ringing or will ring within 2 minutes
- No more App Sandbox: settings, alarms, calendars, and sound files move to the usual places the first time the new version opens (the sandbox folder stays)
- Coming from 0.2.x, replace Clocky by dragging it from the dmg one last time

## 0.2.3 (2026-11-15)

- Updates use the updater shared by all five apps: automatic checks (on by default), **Check Now** in Settings, and **Get New Version…** in the menu bar menu
- The downloaded dmg is verified by signature and SHA-256, then opened from Downloads (as before)
- Finds the latest version from the releases page even when GitHub's rate limit is hit
- About tab in Settings: version, GitHub, changelog, problem reports, and other apps
- Settings… and the update item sit together in the menu bar menu
- Friendlier tone in Korean messages

## 0.2.2 (2026-11-13)

- Signed updates: a new version is downloaded only when the developer's Ed25519 signature matches. The version is signed too, so an old file can't pass as a new one
- Asks you to move Clocky to Applications when opened straight from the dmg
- Offers to move the downloaded dmg to the Trash the first time a new version opens
- iCal downloads stop early when a file is too large and use ETag to fetch only changes
- Clearer wording about update checks and privacy
- Troubleshooting in the install guide, SECURITY.md and issue templates

## 0.2.1 (2026-11-12)

- Update checks: once a day Clocky looks for a new version, shows it in the menu bar menu and Settings, and on click downloads the dmg, checks its SHA-256 and opens it

## 0.2.0 (2026-11-10)

- First public release
- Clock window with flipping digit cards, multiple timers, multiple alarms (repeats, per-alarm sound)
- Flashing warning before ringing, sound that repeats until stopped, snooze, undo for deletes (⌘Z)
- Calendar alerts through the Mac Calendar app or an iCal address, alert timing, skip all-day and declined events
- Menu bar countdown, All Timers & Alarms window, Settings, window and global shortcuts
- Your own sound files, volume, custom timer buttons
- VoiceOver and Reduce Motion support; English and Korean
- App Sandbox and Hardened Runtime
