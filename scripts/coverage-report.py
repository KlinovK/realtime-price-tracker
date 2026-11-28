#!/usr/bin/env python3
"""Validate xccov's production report and render line-count-weighted coverage."""

import argparse
import json
import math
import subprocess
import sys
from collections import defaultdict
from pathlib import Path


PRODUCTION_TARGET = "RealTimePriceTracker.app"
UNREPORTED = {
    "AppLayer/AppAction.swift",
    "CoreLayer/Networking/WebSocket/StreamConfiguration.swift",
    "CoreLayer/Reducer.swift",
    "DesignSystem/Themes/ThemeBackground.swift",
    "DomainLayer/BinanceSocketResponse.swift",
    "DomainLayer/BinanceTicker24h.swift",
    "DomainLayer/BinanceTickerResponse.swift",
    "FeatureLayer/AssetDetailsFeature/AssetDetailsAction.swift",
    "FeatureLayer/MarketFeature/MarketsAction.swift",
    "FeatureLayer/TopAssetsFeature/TopAssetsAction.swift",
}


def fail(message):
    raise ValueError(message)


def counts(item, label):
    covered, total = item.get("coveredLines"), item.get("executableLines")
    if type(covered) is not int or type(total) is not int or not 0 <= covered <= total:
        fail(f"Invalid line counts for {label}")
    ratio = item.get("lineCoverage")
    expected = covered / total if total else 0
    if type(ratio) not in (int, float) or not math.isfinite(ratio) or abs(ratio - expected) > 1e-6:
        fail(f"Invalid line ratio for {label}")
    return covered, total


def percent(covered, total):
    return round(100 * covered / total, 2) if total else None


def component(path):
    parts = Path(path).parts
    if parts[0] == "FeatureLayer" and len(parts) > 2:
        return "/".join(parts[:2])
    if parts[0] == "CoreLayer":
        if len(parts) > 2 and parts[1] in ("Networking", "Persistence"):
            return "/".join(parts[:2])
        return "CoreLayer/Other"
    return parts[0]


def coverage(report, source_root, allowed_unreported):
    if not isinstance(report, dict) or not isinstance(report.get("targets"), list):
        fail("Missing xccov targets")
    if any(not isinstance(t, dict) or not isinstance(t.get("name"), str) for t in report["targets"]):
        fail("Invalid xccov target entry")
    matches = [t for t in report["targets"] if isinstance(t, dict) and t.get("name") == PRODUCTION_TARGET]
    if len(matches) != 1:
        fail(f"Expected exactly one {PRODUCTION_TARGET} coverage target")
    target = matches[0]
    if not isinstance(target.get("files"), list) or not target["files"]:
        fail("Missing production file coverage data")
    root = source_root.resolve()
    expected = {str(p.relative_to(root)) for p in root.rglob("*.swift")}
    if not expected:
        fail("No production Swift source files found")
    if not allowed_unreported <= expected:
        fail("Unreported-file inventory references absent source files")
    files = {}
    groups = defaultdict(lambda: [0, 0])
    for entry in target["files"]:
        if not isinstance(entry, dict) or not isinstance(entry.get("path"), str):
            fail("Invalid production file entry")
        try:
            path = str(Path(entry["path"]).resolve().relative_to(root))
        except ValueError:
            fail(f"Production target contains source outside project: {entry['path']}")
        if path not in expected or path in files:
            fail(f"Unexpected or duplicate production file: {path}")
        covered, total = counts(entry, path)
        files[path] = {"coveredLines": covered, "executableLines": total, "lineCoveragePercent": percent(covered, total)}
        group = groups[component(path)]
        group[0] += covered
        group[1] += total
    missing = expected - files.keys()
    if missing != allowed_unreported:
        fail(f"Unreviewed missing production coverage data: {sorted(missing ^ allowed_unreported)}")
    covered, total = counts(target, PRODUCTION_TARGET)
    if (covered, total) != (sum(f["coveredLines"] for f in files.values()), sum(f["executableLines"] for f in files.values())):
        fail("Production target totals disagree with file totals")
    if total == 0:
        fail("Production target has zero executable lines")
    return {
        "productionTarget": PRODUCTION_TARGET,
        "overall": {"coveredLines": covered, "executableLines": total, "lineCoveragePercent": percent(covered, total)},
        "components": {k: {"coveredLines": v[0], "executableLines": v[1], "lineCoveragePercent": percent(*v)} for k, v in sorted(groups.items())},
        "files": dict(sorted(files.items())),
        "unreportedProductionFiles": sorted(missing),
        "excludedTargets": sorted(t.get("name", "<unnamed>") for t in report["targets"] if t is not target),
    }


def check_thresholds(result, thresholds):
    if not isinstance(thresholds, dict) or set(thresholds) - {"overall", "components"}:
        fail("Invalid threshold configuration")
    components = thresholds.get("components", {})
    if not isinstance(components, dict):
        fail("Invalid component thresholds")
    checks = [("overall", result["overall"], thresholds["overall"])] if "overall" in thresholds else []
    for name, floor in components.items():
        if name not in result["components"]:
            fail(f"Required component coverage missing: {name}")
        checks.append((name, result["components"][name], floor))
    for name, data, floor in checks:
        if type(floor) not in (int, float) or not math.isfinite(floor) or not 0 <= floor <= 100:
            fail(f"Invalid threshold for {name}")
        if data["executableLines"] == 0:
            fail(f"Required component has zero executable lines: {name}")
        if data["coveredLines"] * 100 + 1e-9 < floor * data["executableLines"]:
            fail(f"Coverage below {name} threshold: {data['lineCoveragePercent']}% < {floor}%")


def markdown(result):
    overall = result["overall"]
    lines = ["### Project-owned Swift coverage", "", f"**{overall['coveredLines']}/{overall['executableLines']} executable lines ({overall['lineCoveragePercent']}%)** in `{PRODUCTION_TARGET}`.", "", "| Current component | Covered | Executable | Line coverage |", "| --- | ---: | ---: | ---: |"]
    for name, data in result["components"].items():
        lines.append(f"| {name} | {data['coveredLines']} | {data['executableLines']} | {data['lineCoveragePercent'] if data['lineCoveragePercent'] is not None else 'N/A'}% |".replace("N/A%", "N/A"))
    lines += ["", "| Production file | Covered | Executable | Line coverage |", "| --- | ---: | ---: | ---: |"]
    for name, data in result["files"].items():
        lines.append(f"| {name} | {data['coveredLines']} | {data['executableLines']} | {data['lineCoveragePercent'] if data['lineCoveragePercent'] is not None else 'N/A'}% |".replace("N/A%", "N/A"))
    uncovered = [name for name, data in result["files"].items() if data["executableLines"] and not data["coveredLines"]]
    lines += ["", f"Uncovered production files: {', '.join(uncovered) if uncovered else 'none'}.", f"Reviewed production files without xccov entries: {', '.join(result['unreportedProductionFiles']) if result['unreportedProductionFiles'] else 'none'}.", f"Excluded targets: {', '.join(result['excludedTargets']) if result['excludedTargets'] else 'none'}.", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--xcresult", type=Path)
    source.add_argument("--report-json", type=Path, help="Existing xccov JSON, useful for controlled fixtures")
    parser.add_argument("--source-root", type=Path, default=Path("RealTimePriceTracker/RealTimePriceTracker"))
    parser.add_argument("--allow-unreported", type=Path, help="JSON list of reviewed files without xccov entries")
    parser.add_argument("--thresholds", type=Path, help="Optional approved percentage floors; none are active by default")
    parser.add_argument("--json-out", type=Path)
    parser.add_argument("--markdown-out", type=Path)
    args = parser.parse_args()
    try:
        raw = subprocess.check_output(["xcrun", "xccov", "view", "--report", "--json", str(args.xcresult)], text=True) if args.xcresult else args.report_json.read_text()
        reviewed = json.loads(args.allow_unreported.read_text()) if args.allow_unreported else sorted(UNREPORTED)
        if not isinstance(reviewed, list) or not all(isinstance(x, str) for x in reviewed) or len(reviewed) != len(set(reviewed)):
            fail("Invalid unreported-file inventory")
        allow = set(reviewed)
        result = coverage(json.loads(raw), args.source_root, allow)
        if args.thresholds:
            check_thresholds(result, json.loads(args.thresholds.read_text()))
        human = markdown(result)
        if args.json_out:
            args.json_out.write_text(json.dumps(result, indent=2) + "\n")
        if args.markdown_out:
            args.markdown_out.write_text(human)
        print(human)
    except (ValueError, OSError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(f"Coverage report failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
