# Changelog

Voice Notes, versioned by [SemVer](https://semver.org/). Released through a private beta listing
so far. `just package-beta voice-notes` regenerates the beta listing's What's New
(`store/whats-new.txt`) from the released history below, so keep entries short and plain ASCII.

## [0.1.0] - 2026-11-02
- First beta: START records a note (Ogg Opus, 16 kHz mono), START or BACK stops it.
- Notes upload in pieces to the server in the settings, through the phone or over the watch's
  LTE, and stay on the watch until the server confirms the whole note.
- Waiting notes retry in the background every 15 minutes and after each activity.
- MENU: upload now, or delete the notes still waiting.
