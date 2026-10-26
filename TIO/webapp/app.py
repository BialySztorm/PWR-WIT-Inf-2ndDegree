"""Flask app for interactively viewing drone-coverage routes and existing
task 1-3 plots. Serves raw JSON to the client; all rendering (2D/3D terrain,
route overlay, step animation) happens in the browser via Plotly.js."""
import json
from pathlib import Path

from flask import Flask, abort, jsonify, render_template, send_from_directory

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
ROUTES_DIR = BASE_DIR / "results" / "routes"
PLOTS_DIR = BASE_DIR / "plots"

app = Flask(__name__)


def instance_names():
    registry = json.loads((DATA_DIR / "instances.json").read_text())
    return sorted(e["slug"] for e in registry.get("instances", []))


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/instances")
def api_instances():
    return jsonify(instance_names())


@app.route("/api/instance/<name>")
def api_instance(name):
    path = DATA_DIR / f"{name}.json"
    if not path.is_file():
        abort(404)
    return jsonify(json.loads(path.read_text()))


@app.route("/api/routes/<name>")
def api_routes_list(name):
    methods = sorted(
        p.stem[len(name) + 1:]
        for p in ROUTES_DIR.glob(f"{name}_*.json")
    )
    return jsonify(methods)


@app.route("/api/route/<name>/<method>")
def api_route(name, method):
    path = ROUTES_DIR / f"{name}_{method}.json"
    if not path.is_file():
        abort(404)
    return jsonify(json.loads(path.read_text()))


@app.route("/api/plots/<path:filename>")
def api_plots(filename):
    return send_from_directory(PLOTS_DIR, filename)


@app.route("/api/plots-for/<name>")
def api_plots_for(name):
    """List whichever plot PNGs exist for an instance, discovered by
    glob (like api_routes_list) instead of a hardcoded whitelist, so new
    plot kinds/instances show up automatically."""
    found = []
    for subdir in ("task1-go", "task2-rust", "task3-julia"):
        for p in sorted((PLOTS_DIR / subdir).glob(f"*_{name}.png")):
            found.append(f"{subdir}/{p.name}")
    return jsonify(found)


if __name__ == "__main__":
    app.run(debug=True)
