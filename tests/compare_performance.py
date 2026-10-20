"""Run the identical late-wave fixture in two existing checkouts, sequentially.

No checkout changes; Godot imports must already be ready in both directories.
Example: python tests/compare_performance.py --godot /path/to/godot \
    --baseline /tmp/baseline --candidate . --out /tmp/performance --waves 5,60,110
Add --rendered with a working DISPLAY to include rendering in frame timings.
The benchmark script is copied into a temporary project-local path in baseline,
then removed. Neither game's normal profile is used. Results are stress fixtures,
not balance/survival runs or a promise of desktop FPS.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ERRORS = re.compile(r"SCRIPT ERROR:|ERROR:|FAIL:|leaked at exit|resources still in use")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--baseline", required=True, type=Path)
    parser.add_argument("--candidate", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--waves", default="5,60,110")
    parser.add_argument("--frames", type=int, default=240)
    parser.add_argument("--rendered", action="store_true")
    parser.add_argument("--no-preview", action="store_true")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    harness = (Path(__file__).parent / "benchmark_late_wave.gd").read_bytes()
    baseline = args.baseline.resolve()
    candidate = args.candidate.resolve()
    if baseline == candidate:
        parser.error("Use separate existing checkouts for baseline and candidate")
    comparisons = []
    with tempfile.TemporaryDirectory(prefix="td-performance-") as scratch:
        environment = os.environ.copy()
        for variable, name in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")):
            directory = Path(scratch) / name
            directory.mkdir()
            environment[variable] = str(directory)
        environment.setdefault("LIBGL_ALWAYS_SOFTWARE", "1")
        for wave in map(int, args.waves.split(",")):
            pair = {}
            for label, project in (("before", baseline), ("after", candidate)):
                # Unique filename avoids overwriting a tracked benchmark in either checkout.
                script = project / "tests" / f"_performance_{os.getpid()}.gd"
                report = (args.out / f"{label}-{wave}.json").resolve()
                log = args.out / f"{label}-{wave}.log"
                command = [args.godot, "--path", str(project), "--audio-driver", "Dummy", "--max-fps", "0"]
                if not args.rendered:
                    command += ["--headless"]
                else:
                    command += ["--rendering-method", "gl_compatibility", "--disable-vsync"]
                command += ["--script", f"res://tests/{script.name}", "--", f"--wave={wave}", f"--frames={args.frames}", f"--out={report}"]
                if args.no_preview:
                    command += ["--no-preview"]
                print(f"Running {label} wave {wave} ({'rendered' if args.rendered else 'headless'})", flush=True)
                try:
                    script.write_bytes(harness)
                    result = subprocess.run(command, cwd=project, env=environment, capture_output=True, text=True, timeout=600)
                    log.write_text(result.stdout + result.stderr)
                    if result.returncode or ERRORS.search(result.stdout + result.stderr):
                        raise RuntimeError(f"Benchmark failed: {log}")
                    pair[label] = json.loads(report.read_text())
                finally:
                    script.unlink(missing_ok=True)
                    script.with_suffix(".gd.uid").unlink(missing_ok=True)
            same = pair["before"]["combat_sha256"] == pair["after"]["combat_sha256"]
            row = {"wave": wave, "combat_identical": same, "before": pair["before"]["timing_ms"], "after": pair["after"]["timing_ms"]}
            comparisons.append(row)
            (args.out / "comparison.json").write_text(json.dumps(comparisons, indent=2) + "\n")
            if not same:
                raise RuntimeError(f"Wave {wave} combat digest differs; investigate before accepting optimization")
            print(f"Wave {wave}: identical combat; mean frame {row['before']['frame']['mean']:.2f} -> {row['after']['frame']['mean']:.2f} ms", flush=True)


if __name__ == "__main__":
    main()
