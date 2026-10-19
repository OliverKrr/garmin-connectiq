# /// script
# dependencies = ["fitdecode"]
# ///
"""Print the developer fields of an activity FIT: their descriptions, a summary of each record
field, and the developer values of every lap and session.

It shows what a data field's FitContributor fields wrote, e.g. into the activity `just record`
saves as bin/vm/<app>-activity.fit. With --expect bin/vm/<app>-fit_contributions.json (written by
every build) it also fails unless each field the app declares there was written at least once.

  uv run --script tools/fit_fields.py bin/vm/run-cockpit-activity.fit \
      --expect bin/vm/run-cockpit-fit_contributions.json

Exits 1 when the file holds no developer field or an expected one is missing or never written.
fitdecode rejects an unfinalized FIT (header data size 0), so a recording that never got past
Start fails here too.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import fitdecode


def dev_values(frame: fitdecode.FitDataMessage) -> dict[tuple[int, int], object]:
    return {
        (fd.field_def.dev_data_index, fd.def_num): fd.value
        for fd in frame.fields
        if getattr(fd.field_def, "is_dev", False)
    }


def fmt(v: object) -> str:
    return f"{v:.3f}" if isinstance(v, float) else str(v)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("fit", type=Path)
    ap.add_argument(
        "--expect", type=Path, help="the app's <app>-fit_contributions.json"
    )
    args = ap.parse_args()

    # keyed by (developer data index, field definition number), as the values are
    descs: dict[tuple[int, int], dict] = {}
    records: dict[tuple[int, int], list] = {}
    n_records = 0
    summaries: list[tuple[str, fitdecode.FitDataMessage]] = []
    with fitdecode.FitReader(args.fit) as fit:
        for frame in fit:
            if not isinstance(frame, fitdecode.FitDataMessage):
                continue
            if frame.name == "field_description":
                d = {f.name: f.value for f in frame.fields}
                descs[(d["developer_data_index"], d["field_definition_number"])] = d
            elif frame.name == "record":
                n_records += 1
                for key, v in dev_values(frame).items():
                    if v is not None:
                        records.setdefault(key, []).append(v)
            elif frame.name in ("lap", "session"):
                summaries.append((frame.name, frame))

    laps = sum(1 for kind, _ in summaries if kind == "lap")
    print(
        f"{args.fit}: {n_records} records, {laps} laps, {len(summaries) - laps} sessions"
    )
    if not descs:
        print("no developer fields")
        return 1

    def name(key: tuple[int, int]) -> str:
        return descs[key]["field_name"] if key in descs else f"dev{key[0]}:{key[1]}"

    width = max(len(name(k)) for k in descs)
    print("\ndeveloper fields (data index:number, name, units, type, message)")
    for key, d in sorted(descs.items()):
        print(
            f"  {key[0]}:{key[1]}  {d['field_name']:<{width}}  {d['units'] or '-':<4}"
            f"  {d['fit_base_type_id']:<8}  {d['native_mesg_num']}"
        )

    print("\nrecord fields (records with a value, min, mean, max)")
    for key in sorted(k for k, d in descs.items() if d["native_mesg_num"] == "record"):
        vals = [float(v) for v in records.get(key, [])]
        stats = (
            f"{min(vals):.3f}  {sum(vals) / len(vals):.3f}  {max(vals):.3f}"
            if vals
            else "never written"
        )
        print(f"  {name(key):<{width}}  {len(vals):>5}/{n_records}  {stats}")

    written = set(records)
    print("\nlaps and sessions")
    counts = {"lap": 0, "session": 0}
    for kind, frame in summaries:
        counts[kind] += 1
        vals = dev_values(frame)
        written |= {k for k, v in vals.items() if v is not None}
        fields = (
            "  ".join(f"{name(k)}={fmt(v)}" for k, v in sorted(vals.items())) or "-"
        )
        elapsed = frame.get_value("total_elapsed_time", fallback=None)
        dist = frame.get_value("total_distance", fallback=None)
        span = f"{elapsed or 0:7.1f} s {dist or 0:7.0f} m"
        print(f"  {kind} {counts[kind]:<2} {span}  {fields}")

    if args.expect is None:
        return 0
    declared = {f["id"] for f in json.loads(args.expect.read_text())["datafields"]}
    missing = sorted(
        i for i in declared if not any(k[1] == i and k in written for k in descs)
    )
    if missing:
        names = ", ".join(
            next((name(k) for k in descs if k[1] == i), f"#{i}") for i in missing
        )
        print(f"\nnever written: {names} (declared in {args.expect})")
        return 1
    print(f"\nall {len(declared)} fields declared in {args.expect.name} were written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
