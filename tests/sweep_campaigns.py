"""Compare bot traits with paired campaign seeds; never edits balance or profiles.

Example: python3 tests/sweep_campaigns.py --godot /path/to/godot --out /tmp/trials
Each process owns a disposable profile. All experiments use production GDScript.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import os
from pathlib import Path
import re
import subprocess

ERRORS = re.compile(r"SCRIPT ERROR:|ERROR:|FAIL:|leaked at exit|resources still in use")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--variants", default="builder,storm,siege,artillery,hybrid,investor,architect")
    parser.add_argument("--seeds", default="721,109")
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--cap", type=int, default=80)
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--assert-targets", action="store_true", help="Require 10 attempts, first defeat 8–12 and reaching wave 50 by attempt 10")
    args = parser.parse_args()
    project = Path(__file__).resolve().parent.parent
    args.out.mkdir(parents=True, exist_ok=True)
    environment = os.environ.copy()
    if os.name != "nt":
        for variable, name in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")):
            directory = args.out / name
            directory.mkdir(exist_ok=True)
            environment[variable] = str(directory.resolve())

    def experiment(variant, seed):
        stem = f"{variant}-{seed}"
        report = (args.out / f"{stem}.json").resolve()
        command = [args.godot, "--headless", "--path", str(project), "--log-file", str((args.out / f"{stem}-engine.log").resolve()), "--script", "res://tests/run_progression_campaign.gd", "--", f"--variant={variant}", f"--seed={seed}", f"--runs={args.runs}", f"--cap={args.cap}", f"--report={report}", f"--label={args.out.name}"]
        if args.assert_targets:
            command.append("--assert-targets")
        result = subprocess.run(command, cwd=project, env=environment, capture_output=True, text=True, timeout=2400)
        output = result.stdout + result.stderr
        (args.out / f"{stem}.log").write_text(output)
        if result.returncode or ERRORS.search(output) or not report.exists():
            raise RuntimeError(f"{stem} failed; inspect {args.out / (stem + '.log')}")
        data = json.loads(report.read_text())
        if not data["engine"].startswith("4.7.2-stable"):
            raise RuntimeError(f"{stem}: expected Godot 4.7.2 Stable")
        if data["failed"] or len(data["results"]) != args.runs:
            raise RuntimeError(f"{stem}: incomplete or failed campaign")
        rows = data["results"]
        summary = {"variant": variant, "seed": seed, "waves": [r["last_wave"] for r in rows], "outcomes": [r["outcome"] for r in rows], "cleared": sum(r["cleared"] for r in rows), "first_wave_50_attempt": next((r["attempt"] for r in rows if r["last_wave"] >= 50), None), "elapsed_seconds": sum(r["elapsed_seconds"] for r in rows), "report": report.name}
        print(json.dumps(summary), flush=True)
        return summary

    summaries = []
    with ThreadPoolExecutor(max_workers=args.jobs) as executor:
        futures = [executor.submit(experiment, variant, int(seed)) for variant in args.variants.split(",") for seed in args.seeds.split(",")]
        for future in as_completed(futures):
            summaries.append(future.result())
    summaries.sort(key=lambda row: (row["variant"], row["seed"]))
    ranking = []
    for variant in args.variants.split(","):
        rows = [r for r in summaries if r["variant"] == variant]
        ranking.append({"variant": variant, "mean_last_run_wave": sum(r["waves"][-1] for r in rows) / len(rows), "mean_cleared": sum(r["cleared"] for r in rows) / len(rows)})
    ranking.sort(key=lambda r: (r["mean_last_run_wave"], r["mean_cleared"]), reverse=True)
    (args.out / "summary.json").write_text(json.dumps({"experiments": summaries, "ranking": ranking}, indent=2) + "\n")
    print("RANKING: " + json.dumps(ranking), flush=True)


if __name__ == "__main__":
    main()
