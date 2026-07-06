#!/usr/bin/env python3
"""Validate the Connect IQ Store text against the Store's hard constraints.

Checked (both fail the build when violated):
  1. Description  — the body of store-assets/listing.md below the paste marker.
  2. What's New   — the WHOLE released history of CHANGELOG.md (everything from the
                    first released "## [x.y.z]" heading to the end), because the Store
                    field carries the rolling history and old entries stay in it.

Rules: at most 4000 characters each (the Store rejects longer text only after the
CAPTCHA, losing your edits); no '<' or '>' anywhere (the Store rejects the whole
text); and plain printable ASCII only - non-ASCII characters (bullets, em-dashes,
smart quotes, invisible whitespace) make the dashboard fail the submission with the
misleading "trouble communicating with our servers" error. A warning is printed above
3600 characters so the next release still has room.

Run directly or via `just validate-store-text`; `just package` runs it automatically.
"""
import re
import sys

LIMIT = 4000
WARN = 3600
MARKER = "<!-- STORE DESCRIPTION BELOW — paste everything after this line -->\n"

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


# 1. Store description
listing = open("store-assets/listing.md", encoding="utf-8").read()
if MARKER not in listing:
    failures.append("store-assets/listing.md: paste marker not found")
else:
    check("description (listing.md body)", listing.split(MARKER, 1)[1])

# 2. What's New rolling history
changelog = open("CHANGELOG.md", encoding="utf-8").read()
m = re.search(r"^## \[\d", changelog, flags=re.M)
if not m:
    failures.append("CHANGELOG.md: no released section found")
else:
    check("what's new (released changelog history)", changelog[m.start():])

if failures:
    print("\nSTORE TEXT VALIDATION FAILED:")
    for f in failures:
        print(" -", f)
    sys.exit(1)
print("store text ok")
