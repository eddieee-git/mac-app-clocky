# Changelog

Details for each version are in [docs/releases](docs/releases) and [GitHub Releases](https://github.com/eddieee-git/mac-app-clocky/releases). 한국어: [CHANGELOG.md](CHANGELOG.md)

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
