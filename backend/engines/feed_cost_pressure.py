"""
Feed Cost Pressure — AgriESG
=============================
A second, faster-moving supply pressure component, derived from AHDB UK feed
ingredient prices rather than annual balance sheets.

WHAT THIS MEASURES
------------------
Protein feed cost is the binding input cost in UK pig production. When it
moves, producers adjust breeding and retention, and that works through to the
slaughter market at the speed the animals grow. So a change in protein feed
price today carries information about farm-gate pig price several months out.

VALIDATION (see docs/feed_lead_lag.md for the full working)
-----------------------------------------------------------
Tested on AHDB UK feed ingredient prices (weekly, Jan 2015 to Jul 2026) against
AHDB GB deadweight pig price, SPP EU spec (weekly, 2014 to 2026).

  Method: 13-week log changes, non-overlapping quarterly observations, so the
  reported significance is not inflated by window overlap.

  Soyameal, Brazilian 48% (imported)   peak r = +0.38 to +0.41 at 20-26 wks, p < 0.02
  Rapemeal 34% (UK-crushed)            peak r = +0.384 at 20 wks, p = 0.019
  Pelleted wheat feed (UK)             r = +0.136, p = 0.475  (not significant)

  Rapemeal matching soyameal shows the relationship is not an artefact of
  import costs or sterling. Wheat feed failing is the specificity check:
  protein feed is the constrained input, energy feed is not, and only the
  constrained one carries signal.

  Reverse-causality placebo passes: pig price does not lead feed price.

  The peak is a broad plateau across roughly five to six months, not a point
  estimate. It moves between 20 and 26 weeks depending on gap-filling choices,
  so it is reported as a range everywhere it is surfaced.

SCOPE — READ THIS BEFORE EXTENDING
-----------------------------------
This is validated for PORK ONLY.

It is not applied to poultry, beef, dairy or eggs. Those have different
production cycles: broilers reach slaughter in about six weeks, beef cattle
take roughly two years. The lag that holds for pigs has no reason to hold for
them, and asserting it without testing would be extrapolation dressed as
evidence. Each species needs its own backtest against its own AHDB price
series before it is added here.

KNOWN LIMITATIONS
-----------------
  r = 0.38 explains about 15% of variance. A real signal, not a strong one.
  Tested against farm-gate deadweight price, not retail shelf price. The
    farm-gate to retail link is untested.
  Rapemeal quotes stop on 16 Jan 2026, so the live signal runs on soyameal
    alone. Rapemeal remains the historical corroboration, not a live input.
"""

from __future__ import annotations

import math
import os
from typing import Optional

import pandas as pd

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Only categories with a completed backtest appear here. Adding a key without
# a corresponding validation entry is not a configuration change, it is an
# unevidenced claim.
VALIDATED_CATEGORIES = {"pork"}

# Horizon reported to users, as a range because the correlation peak is a
# plateau rather than a point.
LEAD_HORIZON_WEEKS = (20, 26)

# The change window the backtest was run on. Changing this invalidates the
# reported correlations.
CHANGE_WINDOW_WEEKS = 13

# Empirical distribution of 13-week log changes in soyameal, Jan 2015 to
# Jul 2026, n = 571. Used to convert a raw change into a percentile so the
# output is comparable with the balance-sheet pressure scores, which are also
# 0-1. Refresh these when the underlying series is extended.
SOYAMEAL_CHANGE_QUANTILES = {
    0.05: -0.1525,
    0.25: -0.0692,
    0.50: -0.0122,
    0.75: +0.0573,
    0.95: +0.1909,
}

VALIDATION = {
    "series_used": "AHDB UK feed ingredient prices, Soyameal Brazilian 48% ex-store Liverpool",
    "target_series": "AHDB GB deadweight pig price, SPP EU spec",
    "period": "2015-01 to 2026-07",
    "method": "13-week log changes, non-overlapping quarterly observations",
    "peak_correlation": 0.38,
    "p_value": 0.012,
    "n_observations": 43,
    "corroborating_series": "Rapemeal 34% (UK-crushed), r = 0.384, p = 0.019",
    "specificity_check": "Pelleted wheat feed, r = 0.136, p = 0.475 (not significant)",
    "measures": "farm-gate deadweight price, not retail",
}


# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------

def _percentile_from_quantiles(value: float, quantiles: dict[float, float]) -> float:
    """
    Position a value in an empirical distribution by linear interpolation
    between stored quantiles. Cheaper than shipping the full series and
    accurate enough for a 0-1 pressure score.
    """
    points = sorted(quantiles.items(), key=lambda kv: kv[1])
    if value <= points[0][1]:
        return points[0][0]
    if value >= points[-1][1]:
        return points[-1][0]
    for (q_lo, v_lo), (q_hi, v_hi) in zip(points, points[1:]):
        if v_lo <= value <= v_hi:
            if v_hi == v_lo:
                return q_hi
            frac = (value - v_lo) / (v_hi - v_lo)
            return q_lo + frac * (q_hi - q_lo)
    return 0.5


def feed_cost_pressure(
    price_now: float,
    price_13w_ago: float,
    category: str = "pork",
) -> Optional[dict]:
    """
    Convert a protein feed price change into a supply pressure score.

    Returns None for any category without a completed backtest, so an
    unvalidated category yields no signal rather than a plausible-looking
    number. Callers must handle None rather than defaulting to 0.5.

    Higher pressure means feed costs have risen sharply, which the backtest
    associates with firmer farm-gate prices roughly five to six months later.
    """
    if category not in VALIDATED_CATEGORIES:
        return None
    if not price_now or not price_13w_ago or price_13w_ago <= 0:
        return None

    log_change = math.log(price_now / price_13w_ago)
    pressure = _percentile_from_quantiles(log_change, SOYAMEAL_CHANGE_QUANTILES)

    return {
        "category": category,
        "pressure": round(pressure, 3),
        "stability": round(1.0 - pressure, 3),
        "pct_change_13w": round((math.exp(log_change) - 1) * 100, 1),
        "lead_horizon_weeks": list(LEAD_HORIZON_WEEKS),
        "basis": "protein feed cost, AHDB weekly",
        "validated_for": sorted(VALIDATED_CATEGORIES),
        "validation": VALIDATION,
    }


def describe_pressure(result: Optional[dict]) -> str:
    """
    One-line explanation for the UI. Says what was measured and over what
    horizon, without implying the balance-sheet component said it.
    """
    if result is None:
        return "No validated feed-cost signal for this category."
    lo, hi = result["lead_horizon_weeks"]
    direction = "risen" if result["pct_change_13w"] > 0 else "eased"
    return (
        f"UK protein feed costs have {direction} "
        f"{abs(result['pct_change_13w']):.1f}% over 13 weeks. "
        f"Historically this has led {result['category']} farm-gate prices "
        f"by {lo}-{hi} weeks."
    )


# ---------------------------------------------------------------------------
# Loader
#
# Reads the weekly AHDB feed ingredient file. Kept here rather than in
# services/data_loader.py so the whole component — data, method and validation
# record — sits in one file that can be reviewed as a unit.
# ---------------------------------------------------------------------------

SOYAMEAL_COLUMN = "Soyameal, Brazilian (48%) Ex-Store Liverpool £/tonne"

# main.py lives in backend/api/, this module in backend/engines/, and the data
# directory is backend/data/ — inside backend/ so Render's rootDir-scoped
# auto-deploy actually notices when it changes. Two levels up from this file.
_DEFAULT_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "data", "live", "UK_feed_ingredient_prices.xlsx",
)


def load_feed_series(path: Optional[str] = None) -> Optional[pd.Series]:
    """
    Nearest-delivery soyameal price per quote date.

    Each quote date carries three delivery months; the nearest is the closest
    thing to a spot price and is what the backtest used. Returns None on any
    failure so a missing or malformed file degrades the feed signal rather
    than taking down the endpoint.
    """
    target = path or _DEFAULT_PATH
    try:
        raw = pd.read_excel(target, sheet_name="UK feed ingredient prices ", header=None)
        header = [str(x).replace("\n", " ").strip() for x in raw.iloc[5]]
        d = raw.iloc[6:].copy()
        d.columns = header
        d = d.loc[:, [c for c in d.columns if c != "nan"]].dropna(subset=["Date"])
        d["Date"] = pd.to_datetime(d["Date"])
        d[SOYAMEAL_COLUMN] = pd.to_numeric(d[SOYAMEAL_COLUMN], errors="coerce")

        rows = []
        for dt, g in d.groupby("Date"):
            vals = g[SOYAMEAL_COLUMN].dropna().tolist()
            if vals:
                rows.append((dt, vals[0]))
        if not rows:
            return None
        return pd.Series(dict(rows)).sort_index()
    except Exception as exc:
        print(f"[WARNING] feed price series failed to load from {target}: {exc}")
        return None


def current_feed_pressure(
    series: Optional[pd.Series] = None,
    category: str = "pork",
) -> Optional[dict]:
    """
    Feed cost pressure from the latest quote against the level
    CHANGE_WINDOW_WEEKS earlier. Returns None if the series is missing, too
    short, or the category is not validated.
    """
    s = series if series is not None else load_feed_series()
    if s is None or len(s) < 2:
        return None

    weekly = s.resample("W-SAT").last().ffill(limit=3).dropna()
    if len(weekly) <= CHANGE_WINDOW_WEEKS:
        return None

    now = float(weekly.iloc[-1])
    then = float(weekly.iloc[-(CHANGE_WINDOW_WEEKS + 1)])
    result = feed_cost_pressure(now, then, category=category)
    if result is not None:
        result["price_now"] = round(now, 2)
        result["price_13w_ago"] = round(then, 2)
        result["as_of"] = weekly.index[-1].date().isoformat()
    return result
