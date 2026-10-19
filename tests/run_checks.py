"""Run Godot checks with timeouts and fail on logged errors, even with exit 0.

Python standard library only. Example:
    python tests/run_checks.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64
"""

import argparse
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile


SUITES = (
    "test_pathfinding",
    "test_movement",
    "test_gameplay",
    "test_input_and_restart",
    "test_enemy_traits",
    "test_tower_management",
    "test_endless_stability",
    "test_progression",
    "test_tesla",
    "test_balance",
)
ERRORS = re.compile(r"SCRIPT ERROR:|ERROR:|FAIL:|leaked at exit|resources still in use")
COUNTS = re.compile(r"(\d+) checks, (\d+) failures")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="Godot 4.7.2 Stable executable")
    args = parser.parse_args()
    project = Path(__file__).resolve().parent.parent
    total = 0
    with tempfile.TemporaryDirectory(prefix="td-checks-") as scratch:
        environment = os.environ.copy()
        if os.name != "nt":
            for variable, directory in (
                ("XDG_DATA_HOME", "data"),
                ("XDG_CONFIG_HOME", "config"),
                ("XDG_CACHE_HOME", "cache"),
            ):
                path = Path(scratch) / directory
                path.mkdir()
                environment[variable] = str(path)

        commands = [
            ("version", ["--version"]),
            ("import", ["--headless", "--editor", "--path", str(project), "--quit"]),
            ("startup", ["--headless", "--path", str(project), "--quit-after", "180"]),
        ]
        commands.extend(
            (suite, ["--headless", "--path", str(project), "--script", f"res://tests/{suite}.gd"])
            for suite in SUITES
        )
        for name, options in commands:
            command = [args.godot, *options]
            print("$ " + shlex.join(command), flush=True)
            try:
                result = subprocess.run(
                    command, cwd=project, env=environment, capture_output=True,
                    text=True, encoding="utf-8", errors="replace", timeout=120,
                )
            except (OSError, subprocess.TimeoutExpired) as error:
                print(f"FAIL {name}: {error}", file=sys.stderr)
                return 1
            output = result.stdout + result.stderr
            counts = COUNTS.search(output)
            invalid = result.returncode != 0 or ERRORS.search(output)
            if name == "version":
                invalid = invalid or not re.search(r"\b4\.7\.2\.stable\.", output)
            if name in SUITES:
                invalid = invalid or counts is None or int(counts[1]) == 0 or int(counts[2]) != 0
            if invalid:
                print(output, file=sys.stderr)
                print(f"FAIL {name} (exit {result.returncode})", file=sys.stderr)
                return 1
            for line in output.splitlines():
                if COUNTS.search(line) or (line.startswith("Endless session:") or line.startswith("Balance bot:")) or name == "version":
                    print(line)
            if counts:
                total += int(counts[1])
            print(f"PASS {name} (exit 0; no logged errors)", flush=True)
    print(f"ALL PASSED: {total} checks across {len(SUITES)} suites; import/startup passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
