"""
Cost bar chart restricted to documented eval runs.

Two modes, pick per your workflow:

  MODE A (tracker):   read token volume from the ya-cursor-tracker CSV, but ONLY for
                      conversation_ids that appear in your eval/runs/ metrics.csv files.
                      Automated, tool-call-slice estimate.

  MODE B (metrics):   read the cost straight from each run's metrics.csv `token_cost`
                      column (e.g. Cursor context-report totals human entered).
                      More complete per-run number, no tracker needed.

Usage:
  python graph/cost_from_runs.py --runs-root eval/runs --mode metrics
  python graph/cost_from_runs.py --runs-root eval/runs --mode tracker --tracker interactions.csv
"""
import argparse, glob, os
import pandas as pd
import matplotlib.pyplot as plt


def load_run_metrics(runs_root):
    """Collect every run's metrics.csv row(s) under eval/runs/**/metrics.csv."""
    rows = []
    for path in glob.glob(os.path.join(runs_root, "**", "metrics.csv"), recursive=True):
        try:
            df = pd.read_csv(path)
        except Exception as e:
            print(f"skip {path}: {e}")
            continue
        # drop example/blank rows
        df = df[df.get("conversation_id").notna()] if "conversation_id" in df else df
        df = df[~df.get("run_id", pd.Series(dtype=str)).astype(str).str.contains("EXAMPLE", na=False)]
        df["_source_file"] = path
        rows.append(df)
    if not rows:
        raise SystemExit(f"No usable metrics.csv rows under {runs_root}")
    return pd.concat(rows, ignore_index=True)


def mode_metrics(runs, args):
    """Cost comes straight from the token_cost column you filled per run."""
    d = runs.copy()
    d["token_cost"] = pd.to_numeric(d.get("token_cost"), errors="coerce")
    d = d[d["token_cost"].notna()]
    if d.empty:
        raise SystemExit("No numeric token_cost values in your metrics.csv files. "
                         "Fill token_cost (e.g. Cursor context-report total) first.")
    return d.groupby("model").agg(
        runs=("run_id", "count"),
        mean_tokens=("token_cost", "mean"),
        min_tokens=("token_cost", "min"),
        max_tokens=("token_cost", "max"),
    ).sort_values("mean_tokens", ascending=False)


def mode_tracker(runs, args):
    """Cost comes from the tracker CSV, filtered to your documented conversation_ids."""
    ids = set(runs["conversation_id"].dropna().astype(str))
    if not ids:
        raise SystemExit("No conversation_ids documented in your metrics.csv files.")
    tr = pd.read_csv(args.tracker)
    tr["tool_call_tokens_est"] = pd.to_numeric(tr.get("tool_call_tokens_est"), errors="coerce").fillna(0)
    tr = tr[tr["conversation_id"].astype(str).isin(ids)]
    if tr.empty:
        raise SystemExit("None of your documented conversation_ids were found in the tracker CSV.")
    # per-conversation sum, then attach the model from your run metrics
    per_convo = tr.groupby("conversation_id")["tool_call_tokens_est"].sum().reset_index()
    id_to_model = runs.dropna(subset=["conversation_id"]).set_index(
        runs["conversation_id"].astype(str))["model"].to_dict()
    per_convo["model"] = per_convo["conversation_id"].astype(str).map(id_to_model)
    per_convo = per_convo.dropna(subset=["model"])
    return per_convo.groupby("model").agg(
        runs=("conversation_id", "nunique"),
        mean_tokens=("tool_call_tokens_est", "mean"),
        min_tokens=("tool_call_tokens_est", "min"),
        max_tokens=("tool_call_tokens_est", "max"),
    ).sort_values("mean_tokens", ascending=False)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs-root", default="eval/runs")
    ap.add_argument("--mode", choices=["metrics", "tracker"], default="metrics")
    ap.add_argument("--tracker", default="interactions.csv")
    args = ap.parse_args()

    runs = load_run_metrics(args.runs_root)
    print(f"Loaded {len(runs)} documented run row(s) across "
          f"{runs['model'].nunique()} model(s).")

    by_model = (mode_metrics if args.mode == "metrics" else mode_tracker)(runs, args)
    label = "Cursor context-report tokens" if args.mode == "metrics" else "tool_call_tokens_est"
    print(f"\nPer-model cost ({args.mode} mode, {label}):")
    print(by_model[["runs", "mean_tokens", "min_tokens", "max_tokens"]].to_string())

    means = by_model["mean_tokens"]
    lower = (means - by_model["min_tokens"]).clip(lower=0)
    upper = (by_model["max_tokens"] - means).clip(lower=0)

    fig, ax = plt.subplots(figsize=(8, 5))
    means.plot(kind="bar", ax=ax, color="#4C72B0", edgecolor="black",
               yerr=[lower.values, upper.values], capsize=5,
               error_kw={"ecolor": "#333", "elinewidth": 1.2})
    ax.set_ylabel(f"Mean {label} per run")
    ax.set_xlabel("Model")
    ax.set_title(f"Cost per task by model ({args.mode} mode; bars = min/max)")
    ax.tick_params(axis="x", rotation=30)
    for i, v in enumerate(means):
        ax.text(i, by_model["max_tokens"].iloc[i], f"{v:,.0f}", ha="center", va="bottom", fontsize=9)
    plt.tight_layout()
    plt.savefig("cost_by_model.png", dpi=150)
    by_model.to_csv("cost_by_model_summary.csv")
    print("\nSaved cost_by_model.png and cost_by_model_summary.csv")


if __name__ == "__main__":
    main()