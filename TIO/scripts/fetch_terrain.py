#!/usr/bin/env python3
"""Fetch real-world elevation data and write it as a drone-CPP instance JSON.

Uses the free Open-Topo-Data public API (ASTER GDEM, ~30m resolution,
near-global coverage, no API key: https://www.opentopodata.org/). Grid
layout matches go-ga/cmd/dronega/main.go so solver parameters stay
unchanged: 40x30 cells, 25m cell size, AGL flight mode.
"""
import argparse
import json
import math
import os
import re
import sys
import time
import urllib.error
import urllib.request

# Windows consoles (incl. IntelliJ's run tool window on some setups) default
# to a legacy codepage that mangles non-ASCII chars like "°" on input/
# output; force UTF-8 so DMS coordinates typed interactively parse correctly.
for _stream in (sys.stdin, sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8")

GRID_WIDTH = 40
GRID_HEIGHT = 30
CELL_SIZE_M = 25.0
BATCH_SIZE = 100
DATASET = "aster30m"
API_URL = f"https://api.opentopodata.org/v1/{DATASET}"

SITES = [
    {
        "slug": "real_canyon",
        "name": "Grand Canyon - Yavapai Point, AZ, USA",
        "lat": 36.0702,
        "lon": -112.1258,
    },
    {
        "slug": "real_silesia",
        "name": "Silesian Upland - near Gliwice, Poland",
        "lat": 50.013917,
        "lon": 18.386611,
    },
]


DMS_RE = re.compile(
    r"""^\s*(\d+)\s*[°:]\s*(\d+)\s*['’]\s*([\d.]+)\s*["”]?\s*([NSEW])\s*$""",
    re.IGNORECASE,
)


def parse_dms_token(token):
    """Parses a single Google-Maps-style DMS token, e.g. 50°00'50.1\"N."""
    m = DMS_RE.match(token)
    if not m:
        raise ValueError(f"not a valid DMS coordinate: {token!r}")
    degrees, minutes, seconds, hemi = m.groups()
    value = float(degrees) + float(minutes) / 60.0 + float(seconds) / 3600.0
    if hemi.upper() in ("S", "W"):
        value = -value
    return value, hemi.upper()


def parse_latlon(coord_str):
    """Parses a Google-Maps-style coordinate pair, e.g.
    50°00'50.1"N 18°23'11.8"E (order-independent: N/S vs E/W is inferred
    from the hemisphere letter, not position)."""
    tokens = coord_str.split()
    if len(tokens) != 2:
        raise ValueError(f"expected two DMS tokens (lat lon), got: {coord_str!r}")
    v1, h1 = parse_dms_token(tokens[0])
    v2, h2 = parse_dms_token(tokens[1])
    pair = {h1: v1, h2: v2}
    lat = pair.get("N", pair.get("S"))
    lon = pair.get("E", pair.get("W"))
    if lat is None or lon is None:
        raise ValueError(f"coordinate pair must have one N/S and one E/W token: {coord_str!r}")
    return lat, lon


def grid_to_latlon(x, y, lat0, lon0):
    meters_per_deg_lat = 111320.0
    meters_per_deg_lon = 111320.0 * math.cos(math.radians(lat0))

    x_m = x * CELL_SIZE_M - (GRID_WIDTH * CELL_SIZE_M) / 2.0 + CELL_SIZE_M / 2.0
    y_m = y * CELL_SIZE_M - (GRID_HEIGHT * CELL_SIZE_M) / 2.0 + CELL_SIZE_M / 2.0

    lat = lat0 + y_m / meters_per_deg_lat
    lon = lon0 + x_m / meters_per_deg_lon
    return lat, lon


def fetch_elevations(points):
    """points: list of (lat, lon). Returns list of elevations (meters), same order."""
    elevations = [None] * len(points)
    for start in range(0, len(points), BATCH_SIZE):
        batch = points[start:start + BATCH_SIZE]
        locations = "|".join(f"{lat:.6f},{lon:.6f}" for lat, lon in batch)
        body = json.dumps({"locations": locations}).encode("utf-8")
        req = urllib.request.Request(
            API_URL, data=body, headers={"Content-Type": "application/json"}, method="POST"
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                payload = json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            raise RuntimeError(
                f"Open-Topo-Data request failed ({e.code}): {e.read().decode('utf-8', 'replace')}"
            ) from e
        if payload.get("status") != "OK":
            raise RuntimeError(f"Open-Topo-Data returned status={payload.get('status')}: {payload}")
        for i, result in enumerate(payload["results"]):
            elev = result.get("elevation")
            if elev is None:
                raise RuntimeError(f"missing elevation for point {batch[i]}")
            elevations[start + i] = float(elev)
        time.sleep(1.0)  # public API rate limit: 1 request/sec
    return elevations


def pick_takeoff_cell(terrain):
    """Flattest interior cell (min local height stddev over a 3x3 neighborhood)."""
    def h(x, y):
        return terrain[y * GRID_WIDTH + x]

    best = None
    best_score = float("inf")
    for y in range(1, GRID_HEIGHT - 1):
        for x in range(1, GRID_WIDTH - 1):
            vals = [h(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)]
            mean = sum(vals) / len(vals)
            variance = sum((v - mean) ** 2 for v in vals) / len(vals)
            if variance < best_score:
                best_score = variance
                best = (x, y)
    return best


def build_instance(site, terrain, takeoff_xy):
    return {
        "name": site["name"],
        "grid": {"cell_size_m": CELL_SIZE_M, "width": GRID_WIDTH, "height": GRID_HEIGHT},
        "terrain": terrain,
        "excluded_cells": [],
        "flight": {
            "mode": "agl",
            "agl_target_m": 60,
            "amsl_m": 0,
            "min_clearance_m": 10,
            "legal_max_agl_m": 120,
            "drone_max_rel_takeoff_m": 120,
            "speed_mps": 8,
        },
        "camera": {"hfov_deg": 70, "aspect": "4:3", "overlap_front": 0.7, "overlap_side": 0.6},
        "battery": {"usable_flight_s": 1200, "swap_time_s": 120},
        "takeoff": {
            "mode": "fixed",
            "candidates": [{"label": "base", "x": takeoff_xy[0], "y": takeoff_xy[1]}],
        },
    }


def upsert_registry(data_dir, slug, type_, label, lat=None, lon=None, source=None):
    """Adds or replaces (by slug) an entry in the shared data/instances.json
    manifest, which the Go/Rust/Julia pipelines read to decide which
    instance files to process."""
    path = os.path.join(data_dir, "instances.json")
    if os.path.isfile(path):
        with open(path, "r", encoding="utf-8") as f:
            registry = json.load(f)
    else:
        registry = {"instances": []}

    entry = {"slug": slug, "type": type_, "label": label}
    if lat is not None:
        entry["lat"] = lat
    if lon is not None:
        entry["lon"] = lon
    if source is not None:
        entry["source"] = source

    registry["instances"] = [e for e in registry["instances"] if e["slug"] != slug]
    registry["instances"].append(entry)

    with open(path, "w", encoding="utf-8") as f:
        json.dump(registry, f, indent=2)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Fetch real-world elevation data and write a drone-CPP instance JSON. "
        "With no arguments, prompts interactively for a coordinate. "
        "Pass --defaults to (re)fetch the two built-in sites instead."
    )
    parser.add_argument(
        "--coord",
        help="Coordinate pair in Google-Maps DMS format, e.g. "
        '"50°00\'50.1\\"N 18°23\'11.8\\"E" (order-independent). '
        "Mutually exclusive with --lat/--lon.",
    )
    parser.add_argument("--lat", type=float, help="Decimal latitude (alternative to --coord).")
    parser.add_argument("--lon", type=float, help="Decimal longitude (alternative to --coord).")
    parser.add_argument("--slug", help="Output file slug, e.g. 'real_mysite' -> data/real_mysite.json.")
    parser.add_argument("--name", help="Human-readable site name stored in the instance JSON.")
    parser.add_argument(
        "--defaults", action="store_true",
        help="(Re)fetch the two built-in sites (real_canyon, real_silesia) instead of prompting.",
    )
    return parser.parse_args()


def prompt_for_site():
    """Interactively asks for a coordinate (e.g. pasted straight from Google
    Maps) plus a slug/name, used when the script is run with no arguments —
    this is the path driven by the IntelliJ run configuration, where the
    coordinate is typed into the run console's stdin."""
    coord = input('Coordinate (Google Maps format, e.g. 50°00\'50.1"N 18°23\'11.8"E): ').strip()
    lat, lon = parse_latlon(coord)
    slug = input("Slug (filename, e.g. real_mysite): ").strip()
    if not slug:
        raise SystemExit("slug is required")
    name = input("Name [default: slug] (optional): ").strip() or slug
    return {"slug": slug, "name": name, "lat": lat, "lon": lon}


def main():
    data_dir = os.path.join(os.path.dirname(__file__), "..", "data")
    os.makedirs(data_dir, exist_ok=True)

    args = parse_args()
    if args.defaults:
        sites = SITES
    elif args.coord or args.lat is not None or args.lon is not None or args.slug:
        if args.coord:
            lat, lon = parse_latlon(args.coord)
        elif args.lat is not None and args.lon is not None:
            lat, lon = args.lat, args.lon
        else:
            raise SystemExit("pass either --coord or both --lat and --lon")
        if not args.slug:
            raise SystemExit("--slug is required when fetching a custom site")
        sites = [{"slug": args.slug, "name": args.name or args.slug, "lat": lat, "lon": lon}]
    else:
        sites = [prompt_for_site()]

    for site in sites:
        print(f"[{site['slug']}] fetching {GRID_WIDTH * GRID_HEIGHT} elevation points around "
              f"({site['lat']}, {site['lon']}) from {DATASET}...")
        points = [
            grid_to_latlon(x, y, site["lat"], site["lon"])
            for y in range(GRID_HEIGHT)
            for x in range(GRID_WIDTH)
        ]
        terrain = fetch_elevations(points)
        min_h, max_h = min(terrain), max(terrain)
        print(f"[{site['slug']}] elevation range: {min_h:.1f}m - {max_h:.1f}m "
              f"(relief {max_h - min_h:.1f}m)")

        takeoff_xy = pick_takeoff_cell(terrain)
        print(f"[{site['slug']}] takeoff candidate (flattest interior cell): {takeoff_xy}")

        inst = build_instance(site, terrain, takeoff_xy)
        path = os.path.join(data_dir, f"{site['slug']}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(inst, f, indent=2)
        print(f"[{site['slug']}] wrote {path}")

        upsert_registry(
            data_dir, site["slug"], "real", site["name"],
            lat=site["lat"], lon=site["lon"], source=DATASET,
        )
    print(f"updated {os.path.join(data_dir, 'instances.json')}")


if __name__ == "__main__":
    main()
