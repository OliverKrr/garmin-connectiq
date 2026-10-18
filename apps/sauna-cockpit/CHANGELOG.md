# Changelog

Sauna Cockpit, versioned by [SemVer](https://semver.org/). Released through a private beta
listing so far. `just package-beta sauna-cockpit` regenerates the beta listing's What's New
(`store/whats-new.txt`) from the released history below, so keep entries short and plain ASCII.

## [0.1.0] - 2026-10-18
- Watch app with alternating heat and cool-down phases (BACK switches, each phase a FIT lap),
  countdown with overtime, bezel progress ring, touch ignored.
- Live HR in zone colour with per-phase low / average / high, watch temperature, total time.
- Alerts: end of heat / cool-down, a watch-temperature pre-warning (default 42 C, cover the
  watch) and alert (default 44 C, leave), heart rate; vibrate, beep, screen light.
- Round tables with columns sized to their content: heat (time, avg / max HR, peak temperature,
  time above the effect HR, default 120 bpm) and rest (time, avg / min HR, 60 s HR recovery,
  temperature drop).
- HRV (RMSSD) per heat and rest phase from beat-to-beat intervals.
- Summary pages Heat / Rest / Recovery; Recovery shows Body Battery at start and end and stress
  before the session, and after it when recorded as Meditation.
- Record as setting: Other (default, calories counted) or Meditation (stress measured during the
  session, as Sauna Timer does).
- On-watch history of 50 sessions with 7- and 30-day totals; delete one or clear all.
- Saved as an activity named Sauna with developer fields for Garmin Connect; GPS stays off.
