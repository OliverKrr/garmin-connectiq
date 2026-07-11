#!/usr/bin/env python3
"""Validate the Connect IQ Store text and refresh the copy-paste files.

Sources and paste files:
  1. Description       — store-assets/description.txt IS the paste file (pure content,
                         select all + copy + paste into the dashboard); used by BOTH listings.
  2. What's New (Beta) — CHANGELOG.md is the source; this script REGENERATES
                         store-assets/whats-new.txt from its whole released history
                         (everything from the first "## [x.y.z]" heading down), because
                         the Store field carries the rolling history. Paste into the Beta listing.
  3. What's New (Public) — store-assets/whats-new-public.txt IS an authored paste file (like the
                         description): one folded entry per public milestone. NOT generated — edit
                         it by hand at each public release. Paste into the Public listing.

Checked for both (violations fail the build):
  - at most 4000 characters (the Store validates only after the CAPTCHA, losing edits),
  - no '<' or '>' (the Store rejects the whole text),
  - plain printable ASCII only — non-ASCII (bullets, em-dashes, smart quotes,
    invisibles) makes the dashboard fail with the misleading "trouble communicating
    with our servers" error.
A warning is printed above 3600 characters so the next release still has room.

Run directly or via `just validate-store-text`; `just package` / `just publish-assist`
run it automatically.
"""
import re
import sys

LIMIT = 4000
WARN = 3600

failures = []


def check(name: str, text: str) -> None:
    n = len(text)
    status = "ok"
    if n > LIMIT:
        status = f"OVER LIMIT ({LIMIT})"
        failures.append(f"{name}: {n} chars exceeds the {LIMIT}-char Store limit")
    elif n > WARN:
        status = f"warning: within {LIMIT - n} chars of the limit"
    print(f"{name}: {n}/{LIMIT} chars — {status}")
    bad = sorted(set(re.findall(r"[<>]", text)))
    if bad:
        failures.append(f"{name}: contains forbidden character(s) {' '.join(bad)} — the Store rejects the whole text")
    for lineno, line in enumerate(text.split("\n"), 1):
        for col, ch in enumerate(line, 1):
            if ord(ch) > 126 or ord(ch) < 32:
                failures.append(
                    f"{name}: non-ASCII U+{ord(ch):04X} {ch!r} at line {lineno} col {col} — "
                    "the dashboard rejects these with a misleading 'trouble communicating with our servers' error"
                )


# 1. Description: the paste file itself (used by both listings).
check("description (store-assets/description.txt)", open("store-assets/description.txt", encoding="utf-8").read())

# 2. What's New (Public): authored paste file, checked as-is (not regenerated).
check("what's new / public (store-assets/whats-new-public.txt)", open("store-assets/whats-new-public.txt", encoding="utf-8").read())

# 3. What's New (Beta): regenerate the paste file from the changelog's released history.
changelog = open("CHANGELOG.md", encoding="utf-8").read()
m = re.search(r"^## \[\d", changelog, flags=re.M)
if not m:
    failures.append("CHANGELOG.md: no released section found")
else:
    history = changelog[m.start():]
    # Store-ready: "## [0.6.0] - 2026-07-06" markdown headings would render literally,
    # so turn them into the "Version 0.6.0 - 2026-07-06" convention of top listings.
    history = re.sub(r"^## \[([^\]]+)\] - ", r"Version \1 - ", history, flags=re.M)
    with open("store-assets/whats-new.txt", "w", encoding="utf-8") as f:
        f.write(history)
    print("store-assets/whats-new.txt regenerated from CHANGELOG.md")
    check("what's new / beta (store-assets/whats-new.txt)", history)

if failures:
    print("\nSTORE TEXT VALIDATION FAILED:")
    for f in failures:
        print(" -", f)
    sys.exit(1)
print("store text ok")
