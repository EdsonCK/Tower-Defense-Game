"""Create a CSV and standalone progression chart from measured campaign JSON.

Optional reporting tool; requires matplotlib. Does not simulate or alter results.
"""
import argparse
import csv
import json
import os
import tempfile
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reports", nargs="+", type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    campaigns = [json.loads(path.read_text()) for path in args.reports]
    columns = ["campaign_seed", "variant", "attempt", "run_seed", "outcome", "cleared", "last_wave", "diamonds_before", "diamonds_after", "skills_before", "skills_after", "sentinels", "teslas", "mortars", "ice", "cannons", "sim_minutes"]
    with (args.out / "campaigns.csv").open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, lineterminator="\n")
        writer.writeheader()
        for campaign in campaigns:
            for run in campaign["results"]:
                kinds = run["final_towers"]["by_kind"]
                writer.writerow(dict(zip(columns, [campaign["seed"], campaign["variant"], run["attempt"], run["seed"], run["outcome"], run["cleared"], run["last_wave"], run["diamonds_before"], run["diamonds_after"], len(run["skills_before"]), len(run["skills_after"]), *kinds, round(run["sim_seconds"] / 60, 2)])))
    with tempfile.TemporaryDirectory(prefix="td-plot-") as scratch:
        os.environ.setdefault("MPLCONFIGDIR", scratch)
        if os.name != "nt":
            os.environ.setdefault("XDG_CACHE_HOME", scratch)
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        fig, axes = plt.subplots(2, 1, figsize=(10, 7.5), sharex=True, gridspec_kw={"height_ratios": [2, 1]})
        for campaign in campaigns:
            rows = campaign["results"]
            x = [r["attempt"] for r in rows]
            line, = axes[0].plot(x, [r["last_wave"] for r in rows], marker="o", linewidth=1.8, label=f"Campaign seed {campaign['seed']}")
            for row in rows:
                if row["outcome"] == "cap":
                    axes[0].scatter([row["attempt"]], [row["last_wave"]], marker="^", s=100, facecolors="white", edgecolors=line.get_color(), zorder=4)
            axes[1].plot(x, [len(r["skills_after"]) for r in rows], marker="o", color=line.get_color(), linewidth=1.4)
        axes[0].axhline(50, color="#59616b", linestyle="--", linewidth=1.2, label="Wave-50 goal")
        axes[0].set_ylabel("Wave reached")
        axes[0].set_ylim(bottom=0)
        axes[0].legend(loc="lower right")
        axes[0].set_title("Natural progression with earned diamonds retained between runs", loc="left", fontsize=13, pad=12)
        axes[1].set_ylabel("Permanent nodes owned")
        axes[1].set_ylim(0, 42)
        axes[1].set_xlabel("Successive attempt")
        axes[1].set_xticks(range(1, 11))
        for ax in axes:
            ax.grid(alpha=0.2)
            ax.spines[["top", "right"]].set_visible(False)
        fig.text(0.1, 0.015, "Each campaign starts empty. Enemy seeds change by run. Hollow triangles indicate a configured wave cap, not defeat.", fontsize=8, color="#59616b")
        fig.tight_layout(rect=(0, 0.035, 1, 1))
        fig.savefig(args.out / "progression.png", dpi=170)
        fig.savefig(args.out / "progression.svg")
        plt.close(fig)
        # Matplotlib path attributes include trailing spaces; normalize text artifacts.
        svg = args.out / "progression.svg"
        svg.write_text("\n".join(line.rstrip() for line in svg.read_text().splitlines()) + "\n")



if __name__ == "__main__":
    main()
