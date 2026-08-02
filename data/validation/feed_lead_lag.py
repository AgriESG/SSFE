"""
Feed cost to farm-gate price lead-lag backtest — AgriESG
=========================================================
Reproduces every figure quoted in feed_lead_lag.md.

Inputs (place alongside this script, or pass --data DIR):
    UK_feed_ingredient_prices.xlsx     AHDB, weekly, from 2015-01-30
    All_historic_pig_data.xlsx         AHDB, weekly GB SPP deadweight pig price
    Weekly_deadweight_cattle_prices.xlsx  AHDB, weekly GB deadweight cattle

Run:
    python feed_lead_lag.py --data ../live --pig-data ../validation

Method note
-----------
Correlations are computed on 13-week log changes. Overlapping windows are
strongly autocorrelated and inflate apparent significance, so every reported
r and p uses NON-OVERLAPPING quarterly observations: the aligned series is
thinned to every 13th week AFTER alignment, not before. Thinning before
alignment silently drops most of the sample.
"""

import argparse
import warnings
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats

warnings.filterwarnings("ignore")

CHANGE_WEEKS = 13
FFILL_LIMIT = 3

SOYAMEAL = "Soyameal, Brazilian (48%) Ex-Store Liverpool £/tonne"
RAPEMEAL = "Rapemeal (34%) Ex-Mill Erith £/tonne"
WHEATFEED = "Pelleted Wheat Feed Ex-Mill Midlands and Southern Mills £/tonne"


# ---------------------------------------------------------------------------
# Loaders
# ---------------------------------------------------------------------------

def load_feed(path: Path) -> pd.DataFrame:
    """AHDB feed ingredient prices. Header sits on row 5, data from row 6."""
    raw = pd.read_excel(path, sheet_name="UK feed ingredient prices ", header=None)
    header = [str(x).replace("\n", " ").strip() for x in raw.iloc[5]]
    d = raw.iloc[6:].copy()
    d.columns = header
    d = d.loc[:, [c for c in d.columns if c != "nan"]].dropna(subset=["Date"])
    d["Date"] = pd.to_datetime(d["Date"])
    for c in d.columns:
        if c not in ("Date", "Delivery month"):
            d[c] = pd.to_numeric(d[c], errors="coerce")
    return d


def nearest_delivery(feed: pd.DataFrame, column: str) -> pd.Series:
    """
    Each quote date carries three delivery months. The nearest is the closest
    thing to a spot price, so that is the level used throughout.
    """
    out = []
    for dt, g in feed.groupby("Date"):
        vals = g[column].dropna().tolist()
        if vals:
            out.append((dt, vals[0]))
    return pd.Series(dict(out)).sort_index()


def load_pig(path: Path) -> pd.Series:
    """
    GB SPP deadweight pig price, EU spec, p/kg.
    data_wkly columns: 2 = week ending, 3 = throughput, 4 = EU spec price.
    Column 3 is head count, not price — an easy and costly mix-up.
    """
    raw = pd.read_excel(path, sheet_name="data_wkly", header=None)
    d = raw.iloc[5:][[2, 4]].copy()
    d.columns = ["week_ending", "price"]
    d["week_ending"] = pd.to_datetime(d["week_ending"], errors="coerce")
    d["price"] = pd.to_numeric(d["price"], errors="coerce")
    d = d.dropna()
    return d.set_index("week_ending")["price"].sort_index()


def load_cattle(path: Path, sheet: str, region: str = "England and Wales") -> pd.Series:
    """GB deadweight cattle, p/kg. Header on row 6, data from row 7, cols 1/3/4."""
    raw = pd.read_excel(path, sheet_name=sheet, header=None)
    d = raw.iloc[7:][[1, 3, 4]].copy()
    d.columns = ["week_ending", "region", "price"]
    d["week_ending"] = pd.to_datetime(d["week_ending"], errors="coerce")
    d["price"] = pd.to_numeric(d["price"], errors="coerce")
    d = d.dropna(subset=["week_ending", "price"])
    d = d[d.region == region]
    return d.set_index("week_ending")["price"].sort_index()


# ---------------------------------------------------------------------------
# Analysis
# ---------------------------------------------------------------------------

def log_change(series: pd.Series) -> pd.Series:
    weekly = series.resample("W-SAT").last().ffill(limit=FFILL_LIMIT)
    return np.log(weekly).diff(CHANGE_WEEKS)


def lead_lag(driver: pd.Series, target: pd.Series, lags) -> pd.DataFrame:
    """
    Correlate the driver's change at t against the target's change at t+lag,
    on non-overlapping quarterly observations.
    """
    x, y = log_change(driver), log_change(target)
    rows = []
    for lag in lags:
        m = pd.concat({"x": x, "y": y.shift(-lag)}, axis=1).dropna()
        m = m.iloc[::CHANGE_WEEKS]
        if len(m) < 8:
            continue
        r, p = stats.pearsonr(m.x, m.y)
        rows.append({"lag_weeks": lag, "months": round(lag / 4.33, 1),
                     "n": len(m), "r": round(r, 3), "p": round(p, 3),
                     "significant": p < 0.05})
    return pd.DataFrame(rows)


def placebo(driver: pd.Series, target: pd.Series, lags) -> pd.DataFrame:
    """Reverse the direction. A real lead should not run both ways."""
    return lead_lag(target, driver, lags)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=".", help="directory holding the AHDB files")
    args = ap.parse_args()
    d = Path(args.data)

    feed = load_feed(d / "UK_feed_ingredient_prices.xlsx")
    pig = load_pig(d / "All_historic_pig_data.xlsx")
    cattle_file = d / "Weekly_deadweight_cattle_prices.xlsx"

    soy = nearest_delivery(feed, SOYAMEAL)
    rape = nearest_delivery(feed, RAPEMEAL)
    wheat = nearest_delivery(feed, WHEATFEED)

    print("=" * 72)
    print("SERIES")
    for name, s in [("Soyameal (imported)", soy),
                    ("Rapemeal (UK-crushed)", rape),
                    ("Pelleted wheat feed (UK)", wheat),
                    ("GB pig, SPP EU spec", pig)]:
        print(f"  {name:26s} n={len(s):5d}  {s.index.min().date()} to {s.index.max().date()}")

    lags = [8, 13, 20, 26, 30, 36]
    print("\n" + "=" * 72)
    print("PRIMARY: protein feed cost -> GB deadweight pig price")
    for name, s in [("Soyameal", soy), ("Rapemeal", rape), ("Wheat feed", wheat)]:
        res = lead_lag(s, pig, lags)
        if res.empty:
            continue
        best = res.loc[res.r.abs().idxmax()]
        print(f"\n  {name}")
        print(res.to_string(index=False))
        print(f"  -> peak lag {int(best.lag_weeks)} wks, r={best.r:+.3f}, p={best.p:.3f}, n={int(best.n)}")

    print("\n" + "=" * 72)
    print("PLACEBO: does pig price lead feed price?")
    print(placebo(soy, pig, [8, 26]).to_string(index=False))

    print("\n" + "=" * 72)
    print("SPECIES CHECK: cattle (expected null, feed is a small cost share)")
    long_lags = [8, 13, 20, 26, 39, 52, 65, 78, 91, 104]
    for sheet, label in [("Steers regional series", "Steers"),
                         ("Cows regional series", "Cull cows (dairy herd)"),
                         ("Young bulls regional series", "Young bulls")]:
        target = load_cattle(cattle_file, sheet)
        res = lead_lag(soy, target, long_lags)
        if res.empty:
            continue
        best = res.loc[res.r.abs().idxmax()]
        verdict = "SIGNIFICANT" if best.significant else "not significant"
        print(f"  {label:24s} best lag {int(best.lag_weeks):3d} wks "
              f"({best.months:4.1f} mo)  r={best.r:+.3f}  p={best.p:.3f}  "
              f"n={int(best.n)}  -> {verdict}")

    print("\n" + "=" * 72)
    print("CURRENT READING")
    ch = log_change(soy).dropna()
    latest = ch.iloc[-1]
    pct = (ch < latest).mean()
    weekly = soy.resample("W-SAT").last().ffill(limit=FFILL_LIMIT)
    print(f"  latest quote {weekly.index[-1].date()}: £{weekly.iloc[-1]:.0f}/t")
    print(f"  13-week change: {np.exp(latest) - 1:+.1%}")
    print(f"  percentile vs 2015-2026 (n={len(ch)}): {pct:.3f}")
    print(f"  feed cost pressure (pork): {pct:.3f}   stability: {1 - pct:.3f}")


if __name__ == "__main__":
    main()
