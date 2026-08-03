"""
AgriESG — FastAPI Backend
Food Optimisation Engine API
Version: 0.3.2

WHAT CHANGED FROM 0.3.1:
--------------------------
1. Supply category is now read from a curated supply_category column in
   Foods_Master instead of being derived from the coarse Category column.

   The old derivation routed every Protein row to poultry and every Staple,
   Fruit and Vegetable row to cereals. Because substitutions are
   role-preserving, both sides of a swap always resolved to the same category,
   supply stability had zero variance within any choice set, and its 0.15
   weight acted on a constant. The beef, pork and eggs series were also
   unreachable. Classification now lives next to the food it describes, where
   it can be reviewed.

2. Feed cost pressure added as a second, faster-moving component, from AHDB
   weekly feed ingredient prices. Validated for PORK ONLY — see
   data/validation/feed_lead_lag.md. Returns null for every other category
   rather than a plausible-looking default.

WHAT CHANGED FROM 0.3.0:
--------------------------
Rationale generation is now supply-aware.

  Previously the rationale sentence was built only from cost, nutrition
  and environment deltas. supply_stability was computed and returned in
  the response but never referenced in the text, so no individual
  recommendation ever attributed itself to the Supply Pressure Index
  even when the index had influenced the ranking.

  The generator now:
    - appends a supply clause when the substitute's category sits under
      genuinely less supply pressure than the original's, printing both
      figures so they can be reconciled against supply_stability in the
      same response
    - suppresses that clause when either category sits on the neutral
      0.500 default, which indicates no published free stock series
      rather than a measured mid-range reading
    - names trade-offs, since Pareto optimality means undominated rather
      than better on every objective
    - applies a consistent >= 2 pt threshold across all three score
      dimensions (nutrition previously used > 0, which surfaced
      "better nutrition (+1 pts)" on essentially flat swaps)

WHAT CHANGED FROM 0.2.0:
--------------------------
The /optimise-basket endpoint runs a three-stage pipeline:

  Stage 1 — Behavioural Realism Filter
  Removes substitution candidates that are behaviourally unrealistic
  based on taste, texture, flavour intensity, prep type, prep time,
  prep complexity, and meal context similarity.

  Stage 2 — Supply Pressure Index
  Attaches a supply stability score to each candidate derived from
  AHDB UK cereal balance sheet data. Captures upstream agricultural
  supply conditions that predict retail price movements 6-8 weeks ahead.

  Stage 3 — Pareto Optimisation Engine
  Filters candidates to the Pareto-efficient frontier across four
  objectives (cost, nutrition, environment, supply stability) and
  ranks by user preference alignment.

  This replaces the previous single-objective greedy selection.
  API response format is backward compatible — all existing fields
  are preserved, new fields are added alongside them.
"""

import math
import asyncio
import numpy as np
import pandas as pd
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional

from services.data_loader import load_food_data
from engines.supply_pressure import get_supply_pressure_index
from engines.pareto_optimiser import optimise_substitutions
from engines.behavioural_realism import filter_by_realism
from engines.feed_cost_pressure import (
    current_feed_pressure,
    describe_pressure,
    load_feed_series,
    VALIDATED_CATEGORIES as FEED_VALIDATED_CATEGORIES,
)
from api.metrics import RequestCounterMiddleware, router as metrics_router, _pipeline

# ---------------------------------------------------------------------------
# App setup
# ---------------------------------------------------------------------------

app = FastAPI(
    title="AgriESG Food Optimisation API",
    description="Multi-objective food basket optimisation: cost, nutrition, environment, supply stability.",
    version="0.3.2",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(RequestCounterMiddleware)
app.include_router(metrics_router)

# ---------------------------------------------------------------------------
# Role normalisation
# Collapses inconsistent Role column values into functional roles
# ---------------------------------------------------------------------------

ROLE_MAP = {
    "protein": "protein", "main protein": "protein", "protein / snack": "protein",
    "oily fish": "protein", "white fish": "protein",
    "carbohydrate": "carb", "breakfast base": "carb",
    "drink / base": "dairy", "milk substitute": "dairy_alt",
    "snack / base": "snack", "snack / spread": "snack", "snack": "snack",
    "tropical": "fruit", "berry": "fruit", "citrus": "fruit",
    "stone fruit": "fruit", "pome": "fruit", "melon": "fruit", "fresh": "fruit",
    "cruciferous": "vegetable", "leafy green": "vegetable", "root": "vegetable",
    "fruiting": "vegetable", "legume": "vegetable", "squash": "vegetable",
    "bulb": "vegetable", "fungi": "vegetable", "stalk": "vegetable", "spear": "vegetable",
    "drink": "drink",
}

# Swap realism scale from Ifeanyi's dataset
# 3 = high realism (natural swap most users would accept)
# 2 = medium realism (plausible for some users)
# 1 = low realism (stretch swap, unlikely for most users)
# Only swaps with realism >= MIN_SWAP_REALISM are used
MIN_SWAP_REALISM = 1

# ---------------------------------------------------------------------------
# Rationale generation thresholds
# ---------------------------------------------------------------------------

# Score movements smaller than this are rounding, not movement. Applied
# uniformly across env, cost and nutrition so no single dimension can claim
# a benefit at a magnitude the others would ignore.
SCORE_CLAIM_THRESHOLD = 2.0

# A supply stability gain must clear this before the rationale claims one.
SUPPLY_CLAIM_THRESHOLD = 0.05

# The Supply Pressure Index returns exactly 0.500 for commodities with no
# free stock series published in the AHDB balance sheets. That value marks
# absent data, not a measured neutral reading, and must never be presented
# as evidence of a supply benefit.
NEUTRAL_PRESSURE = 0.5
NEUTRAL_EPSILON = 1e-3

# Tolerance when reconciling a locally derived stability figure against the
# supply_stability value returned by the optimiser.
SUPPLY_RECONCILE_TOLERANCE = 0.02


def normalise_role(raw: str) -> str:
    return ROLE_MAP.get(str(raw).strip().lower(), "other")


# ---------------------------------------------------------------------------
# Food category mapping for supply pressure
#
# Read from the curated supply_category column in Foods_Master. Classification
# is a judgement about each food, so it lives in the dataset next to the food
# it describes rather than in a lookup table here, where it could not be
# reviewed alongside the data.
#
# Values in use: poultry, pork, beef, dairy, bread, cereals, eggs, unmapped.
# ---------------------------------------------------------------------------

UNMAPPED_SUPPLY_CATEGORY = "unmapped"


def get_supply_category(food_row: pd.Series) -> str:
    """
    Read a food's supply pressure category from the dataset.

    Falls back to unmapped when the column is absent or blank, so a food with
    no classification yields no supply signal rather than being silently
    assigned one.
    """
    val = food_row.get("supply_category")
    if val is None or (isinstance(val, float) and math.isnan(val)):
        return UNMAPPED_SUPPLY_CATEGORY
    text = str(val).strip()
    return text or UNMAPPED_SUPPLY_CATEGORY


# ---------------------------------------------------------------------------
# Dataset — loaded once at startup
# ---------------------------------------------------------------------------

_foods: pd.DataFrame = None
_subs: pd.DataFrame = None
_prices: pd.DataFrame = None
_score_bounds: dict = {}
_food_lookup: dict = {}
_supply_pressure: dict = {}
_feed_series = None


def get_data():
    global _foods, _subs, _prices, _score_bounds, _food_lookup, _supply_pressure, _feed_series

    if _foods is None:
        _foods, _subs, _prices = load_food_data()

        _foods["role_norm"] = _foods["Role"].apply(normalise_role)
        _foods["name_lower"] = _foods["Food_name"].str.strip().str.lower()

        # Best price per kg: Aldi -> ASDA -> Tesco
        _prices["best_price_per_kg"] = (
            _prices["aldi_price_per_kg"]
            .fillna(_prices["asda_price_per_kg"])
            .fillna(_prices["tesco_price_per_kg"])
            .fillna(0.0)
        )

        # Score normalisation bounds
        # Note: column is 'Carbon' in updated dataset (was 'Carbon_footprint')
        _score_bounds = {
            "carbon":  (_foods["Carbon"].min(),  _foods["Carbon"].max()),
            "water":   (_foods["Water"].min(),   _foods["Water"].max()),
            "land":    (_foods["Land"].min(),    _foods["Land"].max()),
            "protein": (_foods["Protein"].min(), _foods["Protein"].max()),
            "fibre":   (_foods["Fibre"].min(),   _foods["Fibre"].max()),
            "price":   (_prices["best_price_per_kg"].min(), _prices["best_price_per_kg"].max()),
        }

        # Build food lookup dict for realism filter
        # Keys are food_id, values are full food dicts including behavioural fields
        for _, row in _foods.iterrows():
            fid = str(row["food_id"])
            _food_lookup[fid] = {
                "food_id":          fid,
                "name":             str(row["Food_name"]),
                "role":             str(row["role_norm"]),
                "category":         str(row.get("Category", "")),
                "food_category":    get_supply_category(row),
                # Behavioural fields for realism filter
                "taste_profile":    row.get("taste_profile"),
                "texture_profile":  row.get("texture_profile"),
                "flavour_intensity": row.get("flavour_intensity"),
                "prep_type":        row.get("prep_type"),
                "prep_time_minutes": row.get("prep_time_minutes"),
                "prep_complexity":  row.get("prep_complexity"),
                "meal_context":     row.get("meal_context"),
            }

        # Load supply pressure index at startup
        # Cached for session — refreshed on restart
        try:
            _supply_pressure = get_supply_pressure_index()
        except Exception as e:
            print(f"[WARNING] Supply pressure index failed to load: {e}")
            _supply_pressure = {}

        # Weekly feed prices for the feed cost pressure component. Optional:
        # a missing file degrades that one signal rather than the endpoint.
        _feed_series = load_feed_series()
        if _feed_series is None:
            print("[WARNING] Feed price series unavailable, feed cost pressure disabled")

    return _foods, _subs, _prices


# ---------------------------------------------------------------------------
# JSON safety — replace NaN/Inf with 0.0
# ---------------------------------------------------------------------------

def sanitise(val):
    if isinstance(val, float) and (math.isnan(val) or math.isinf(val)):
        return 0.0
    return val


# ---------------------------------------------------------------------------
# Supply stability helpers
#
# Both the rationale generator and any future consumer need one shared
# definition of "how stable is this category", so it lives here rather than
# being derived inline at the call site.
# ---------------------------------------------------------------------------

def category_stability(category: Optional[str]) -> Optional[float]:
    """
    Stability of a food category, derived from its supply pressure.

    Returns None when the category is unknown, or when its pressure sits on
    the neutral 0.500 default. That default marks a commodity with no free
    stock series in the AHDB balance sheets, so it carries no information
    about supply conditions and must not be read as a mid-range measurement.
    """
    if not category:
        return None
    cat_pressure = _supply_pressure.get("food_category_pressure", {})
    p = cat_pressure.get(category)
    if p is None:
        return None
    try:
        p = float(p)
    except (TypeError, ValueError):
        return None
    if abs(p - NEUTRAL_PRESSURE) < NEUTRAL_EPSILON:
        return None
    return round(1.0 - p, 3)


def build_supply_clause(
    orig_category: Optional[str],
    sub_category: Optional[str],
    sub_stability: Optional[float],
) -> Optional[str]:
    """
    Build the supply clause for a rationale sentence, or None if no honest
    claim can be made.

    The clause is emitted only when all of the following hold:
      - both categories have real (non-default) pressure readings
      - the substitute's stability reconciles with the supply_stability
        value returned by the optimiser, so the two numbers a reader can
        see in the same API response agree with each other
      - the stability gain clears SUPPLY_CLAIM_THRESHOLD

    The reconciliation check exists because this function derives stability
    as 1 - pressure. If the optimiser ever derives it differently, printing
    a figure here that contradicts the response field would be worse than
    printing nothing, so the clause is suppressed instead.
    """
    if sub_stability is None:
        return None

    orig_stability = category_stability(orig_category)
    if orig_stability is None:
        return None

    expected = category_stability(sub_category)
    if expected is None:
        return None

    if abs(expected - float(sub_stability)) > SUPPLY_RECONCILE_TOLERANCE:
        return None

    gain = float(sub_stability) - orig_stability
    if gain < SUPPLY_CLAIM_THRESHOLD:
        return None

    return (
        f"steadier UK supply ({float(sub_stability):.2f} vs {orig_stability:.2f})"
    )


def build_rationale(
    env_d: float,
    cost_d: float,
    nut_d: float,
    supply_clause: Optional[str],
) -> str:
    """
    Compose the human-readable rationale.

    Benefits and trade-offs are both reported. A Pareto-optimal swap is
    undominated, not better on every objective, so a recommendation can
    legitimately give ground on one dimension. Stating that is what
    separates a recommendation from a sales pitch, and it is checkable
    against the delta fields in the same response.
    """
    parts = []
    if env_d >= SCORE_CLAIM_THRESHOLD:
        parts.append(f"lower environmental impact (-{env_d:.0f} pts)")
    if cost_d >= SCORE_CLAIM_THRESHOLD:
        parts.append(f"cheaper (-{cost_d:.0f} cost pts)")
    if nut_d >= SCORE_CLAIM_THRESHOLD:
        parts.append(f"better nutrition (+{nut_d:.0f} pts)")
    if supply_clause:
        parts.append(supply_clause)

    tradeoffs = []
    if env_d <= -SCORE_CLAIM_THRESHOLD:
        tradeoffs.append(f"higher carbon (+{abs(env_d):.0f} pts)")
    if cost_d <= -SCORE_CLAIM_THRESHOLD:
        tradeoffs.append(f"pricier (+{abs(cost_d):.0f} cost pts)")
    if nut_d <= -SCORE_CLAIM_THRESHOLD:
        tradeoffs.append(f"less nutrient dense ({nut_d:.0f} pts)")

    if parts:
        rationale = "Swap for " + ", ".join(parts) + "."
        if tradeoffs:
            rationale += " Trade-off: " + ", ".join(tradeoffs) + "."
        return rationale

    if tradeoffs:
        return "Ranked on balance despite " + ", ".join(tradeoffs) + "."

    return "Marginal combined improvement."


# ---------------------------------------------------------------------------
# Scoring helpers
# ---------------------------------------------------------------------------

def _norm(val, vmin, vmax) -> float:
    if vmax == vmin:
        return 50.0
    return float(np.clip((val - vmin) / (vmax - vmin) * 100, 0, 100))


def score_food_row(food_row: pd.Series, price_per_kg: Optional[float]) -> dict:
    b = _score_bounds
    env = round(
        _norm(food_row["Carbon"],  *b["carbon"])  * 0.5 +
        _norm(food_row["Water"],   *b["water"])   * 0.3 +
        _norm(food_row["Land"],    *b["land"])    * 0.2, 2
    )
    nutrition = round(
        _norm(food_row["Protein"], *b["protein"]) * 0.6 +
        _norm(food_row["Fibre"],   *b["fibre"])   * 0.4, 2
    )
    cost = round(_norm(price_per_kg, *b["price"]), 2) if price_per_kg else 50.0
    return {
        "env":       sanitise(env),
        "nutrition": sanitise(nutrition),
        "cost":      sanitise(cost),
    }


def get_food_by_id(food_id: str):
    foods, _, prices = get_data()
    row = foods[foods["food_id"] == food_id]
    if row.empty:
        return None, None
    row = row.iloc[0]
    p_row = prices[prices["food_id"] == food_id]
    price = float(p_row["best_price_per_kg"].iloc[0]) if not p_row.empty else None
    return row, price


# ---------------------------------------------------------------------------
# Request models
# ---------------------------------------------------------------------------

class BasketRequest(BaseModel):
    basket: list[str] = Field(..., description="List of food_ids e.g. ['P01', 'D04']")
    user_preferences: Optional[dict] = None


class FoodSearchRequest(BaseModel):
    query: str


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@app.get("/")
def root():
    return {"message": "AgriESG Food Optimisation API", "version": "0.3.2"}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/foods")
def list_foods():
    foods, _, _ = get_data()
    out = foods[["food_id", "Food_name", "Category", "role_norm"]].copy()
    out.columns = ["food_id", "food_name", "category", "role"]
    return {"foods": out.to_dict(orient="records"), "total": len(out)}


@app.get("/foods/{food_id}")
def get_food(food_id: str):
    row, price = get_food_by_id(food_id.upper())
    if row is None:
        raise HTTPException(status_code=404, detail=f"Food '{food_id}' not found")
    scores = score_food_row(row, price)
    return {
        "food_id":      str(row["food_id"]),
        "food_name":    str(row["Food_name"]),
        "role":         str(row["role_norm"]),
        "nutrition": {
            "calories":   float(row["Calories"]),
            "protein_g":  float(row["Protein"]),
            "fibre_g":    float(row["Fibre"]),
        },
        "environmental": {
            "carbon_kg_co2e": float(row["Carbon"]),
            "water_litres":   float(row["Water"]),
            "land_m2":        float(row["Land"]),
        },
        "price_per_kg_gbp": float(price) if price else 0.0,
        "scores": scores,
    }


@app.post("/calculate-impact")
def calculate_impact(request: BasketRequest):
    if not request.basket:
        raise HTTPException(status_code=400, detail="Basket cannot be empty")

    get_data()
    items, not_found = [], []

    for fid in request.basket:
        row, price = get_food_by_id(fid)
        if row is None:
            not_found.append(fid)
            continue
        scores = score_food_row(row, price)
        items.append({
            "food_id":    str(fid),
            "food_name":  str(row["Food_name"]),
            "role":       str(row["role_norm"]),
            **scores,
            "price_per_kg": float(price) if price else 0.0,
        })

    if not items:
        raise HTTPException(status_code=404, detail="No valid foods found in basket")

    avg_env  = round(np.mean([i["env"] for i in items]), 2)
    avg_nut  = round(np.mean([i["nutrition"] for i in items]), 2)
    avg_cost = round(np.mean([i["cost"] for i in items]), 2)

    return {
        "basket_score":        round(avg_env * 0.4 + avg_cost * 0.3 + (100 - avg_nut) * 0.3, 2),
        "avg_env_score":       avg_env,
        "avg_nutrition_score": avg_nut,
        "avg_cost_score":      avg_cost,
        "items":               items,
        "not_found":           not_found,
    }


@app.post("/optimise-basket")
def optimise_basket(request: BasketRequest):
    """
    Core endpoint — three-stage optimisation pipeline.

    Stage 1: Behavioural Realism Filter
    Stage 2: Supply Pressure Index attachment
    Stage 3: Pareto optimisation + preference ranking

    Response is backward compatible with v0.2.0.
    New fields added: pareto_rank, supply_stability, preference_score,
    realism_score, pareto_front_size, weights_applied, supply_pressure_index.
    """
    if not request.basket:
        raise HTTPException(status_code=400, detail="Basket cannot be empty")

    foods, subs, prices = get_data()
    prefs = request.user_preferences or {}

    # Resolve basket items — accept food_id or name string
    resolved_ids, not_found = [], []
    for item in request.basket:
        item_clean = item.strip()
        if item_clean.upper() in foods["food_id"].values:
            resolved_ids.append(item_clean.upper())
        else:
            match = foods[foods["name_lower"].str.contains(item_clean.lower(), na=False)]
            if not match.empty:
                resolved_ids.append(match.iloc[0]["food_id"])
            else:
                not_found.append(item_clean)

    if not resolved_ids:
        raise HTTPException(status_code=404, detail="No valid foods found in basket")

    # ── Basket scoring helpers ──────────────────────────────────────────────

    def score_basket(ids):
        items = []
        for fid in ids:
            row, price = get_food_by_id(fid)
            if row is None:
                continue
            scores = score_food_row(row, price)
            items.append({"food_id": fid, "food_name": row["Food_name"], **scores})
        return items

    def basket_summary(items):
        e = round(np.mean([i["env"] for i in items]), 2)
        n = round(np.mean([i["nutrition"] for i in items]), 2)
        c = round(np.mean([i["cost"] for i in items]), 2)
        return {
            "avg_env_score":       e,
            "avg_nutrition_score": n,
            "avg_cost_score":      c,
            "basket_score":        round(e * 0.4 + c * 0.3 + (100 - n) * 0.3, 2),
        }

    before_summary = basket_summary(score_basket(resolved_ids))

    # ── Three-stage pipeline per basket item ────────────────────────────────

    substitutions = []
    optimised_ids = list(resolved_ids)

    for i, fid in enumerate(resolved_ids):
        orig_row, orig_price = get_food_by_id(fid)
        if orig_row is None:
            continue

        orig_scores = score_food_row(orig_row, orig_price)
        orig_supply_category = get_supply_category(orig_row)

        # Get substitution candidates from dataset
        # Filter by minimum swap realism from Ifeanyi's audit
        sub_rows = subs[subs["food_id"] == fid].copy()
        sub_rows = sub_rows[sub_rows["swap_realism"] >= MIN_SWAP_REALISM].copy()
        # Flag low-realism pairs (score=1) for transparency
        # Algorithm handles filtering — Ifeanyi score informs but does not veto
        sub_rows["human_flagged_low_realism"] = sub_rows["swap_realism"] == 1
        sub_ids = sub_rows["substitute_food_id"].tolist()

        if not sub_ids:
            continue

        # Build candidate list with all objective scores
        raw_candidates = []
        for sub_id in sub_ids:
            sub_row, sub_price = get_food_by_id(str(sub_id))
            if sub_row is None:
                continue

            sub_scores = score_food_row(sub_row, sub_price)

            # Objective deltas — all expressed as improvement (higher = better)
            cost_delta      = round(orig_scores["cost"] - sub_scores["cost"], 2)
            nutrition_delta = round(sub_scores["nutrition"] - orig_scores["nutrition"], 2)
            env_delta       = round(orig_scores["env"] - sub_scores["env"], 2)

            # Check if Ifeanyi flagged this pair as low realism
            flag_row = sub_rows[sub_rows["substitute_food_id"] == sub_id]
            human_flagged = bool(
                flag_row["human_flagged_low_realism"].iloc[0]
                if not flag_row.empty else False
            )

            raw_candidates.append({
                "original_id":    str(fid),
                "original_name":  str(orig_row["Food_name"]),
                "substitute_id":  str(sub_id),
                "substitute_name": str(sub_row["Food_name"]),
                "role":           str(orig_row["role_norm"]),
                "food_category":  get_supply_category(sub_row),
                "cost_delta":     cost_delta,
                "nutrition_delta": nutrition_delta,
                "env_delta":      env_delta,
                "human_flagged_low_realism": human_flagged,
                # Original scores preserved for rationale generation
                "_orig_scores":   orig_scores,
                "_sub_scores":    sub_scores,
            })

        if not raw_candidates:
            continue

        # ── STAGE 1: Behavioural Realism Filter ────────────────────────────
        # Remove candidates that are behaviourally unrealistic
        # Uses taste, texture, flavour intensity, prep type, time, complexity
        # Missing behavioural fields → neutral score (0.5), not penalised
        realistic_candidates = filter_by_realism(raw_candidates, _food_lookup)

        if not realistic_candidates:
            # All candidates filtered — fall back to best raw candidate
            # to ensure we always return something rather than silence
            realistic_candidates = raw_candidates

        # ── STAGE 2 + 3: Supply Pressure + Pareto Optimisation ─────────────
        # Supply pressure scores attached inside optimise_substitutions()
        # Pareto filter removes dominated candidates
        # Preference ranking orders the frontier by user values
        result = optimise_substitutions(
            candidates=realistic_candidates,
            user_preferences=prefs,
            supply_pressure=_supply_pressure,
            top_n=3,
        )

        top = result.get("recommendations", [])
        if not top:
            continue

        # Use top-ranked Pareto candidate as the optimised replacement
        best = top[0]
        best_sub_id = best["substitute_id"]
        optimised_ids[i] = best_sub_id

        # ── Generate human-readable rationale ───────────────────────────────
        # Supply is one of the four ranked objectives, so it appears in the
        # sentence whenever it genuinely applies, with both figures shown so
        # they reconcile against supply_stability in this same response.
        env_d  = best.get("env_delta", 0)
        cost_d = best.get("cost_delta", 0)
        nut_d  = best.get("nutrition_delta", 0)

        supply_clause = build_supply_clause(
            orig_category=orig_supply_category,
            sub_category=best.get("food_category"),
            sub_stability=best.get("supply_stability"),
        )

        rationale = build_rationale(env_d, cost_d, nut_d, supply_clause)

        # ── Build substitution response ─────────────────────────────────────
        # Backward compatible fields preserved from v0.2.0
        # New fields added: pareto_rank, supply_stability, preference_score,
        # realism_score, pareto_front_size, weights_applied
        sub_entry = {
            # ── v0.2.0 fields (unchanged) ──
            "original_id":      str(fid),
            "original_name":    str(orig_row["Food_name"]),
            "substitute_id":    str(best_sub_id),
            "substitute_name":  best["substitute_name"],
            "role":             str(orig_row["role_norm"]),
            "improvement_score": float(best.get("preference_score", 0)),
            "env_delta":        float(env_d),
            "cost_delta":       float(cost_d),
            "nutrition_delta":  float(nut_d),
            "rationale":        rationale,
            # ── v0.3.0 new fields ──
            "pareto_rank":         int(best.get("rank", 1)),
            "pareto_front_size":   int(result.get("pareto_front_size", 1)),
            "supply_stability":    float(best.get("supply_stability", 0.5)),
            "preference_score":    float(best.get("preference_score", 0)),
            "realism_score":       float(best.get("realism_score", 0.5)),
            "weights_applied":     result.get("weights_applied", {}),
            "is_pareto_optimal":   True,
            "human_flagged_low_realism": bool(best.get("human_flagged_low_realism", False)),
            # ── v0.3.1 new fields ──
            # Both supply categories exposed so a reader can trace the
            # rationale's supply clause back to /supply-pressure directly.
            "original_supply_category":   orig_supply_category,
            "substitute_supply_category": best.get("food_category"),
            "supply_influenced_rationale": supply_clause is not None,
        }

        substitutions.append(sub_entry)

    # Sort by preference score descending
    substitutions.sort(key=lambda x: x["preference_score"], reverse=True)

    after_summary = basket_summary(score_basket(optimised_ids))

    return {
        # ── v0.2.0 fields (unchanged) ──
        "before": before_summary,
        "after":  after_summary,
        "improvement": {
            "basket_score_gain": round(before_summary["basket_score"] - after_summary["basket_score"], 2),
            "env_reduction":     round(before_summary["avg_env_score"] - after_summary["avg_env_score"], 2),
            "nutrition_gain":    round(after_summary["avg_nutrition_score"] - before_summary["avg_nutrition_score"], 2),
            "cost_reduction":    round(before_summary["avg_cost_score"] - after_summary["avg_cost_score"], 2),
        },
        "substitutions":       substitutions,
        "items_scored":        len(resolved_ids),
        "substitutions_found": len(substitutions),
        "not_found":           not_found,
        # ── v0.3.0 new fields ──
        "supply_pressure_index": {
            "grain_pressure":        _supply_pressure.get("grain_pressure", {}),
            "food_category_pressure": _supply_pressure.get("food_category_pressure", {}),
            "data_vintage":          _supply_pressure.get("data_vintage"),
        },
        # ── v0.3.1 new field ──
        # How many of the returned swaps carry a supply clause in their
        # rationale. Exposed rather than inferred so the influence of the
        # Supply Pressure Index on this basket is directly countable.
        "supply_influenced_count": sum(
            1 for s in substitutions if s.get("supply_influenced_rationale")
        ),
        # ── v0.3.2 new field ──
        # Second pressure component, kept separate from supply_pressure_index
        # because it has a different data source, a different horizon and a
        # different validation status. Null for every category except pork.
        "feed_cost_pressure": {
            c: current_feed_pressure(_feed_series, c)
            for c in sorted(FEED_VALIDATED_CATEGORIES)
        },
        "engine_version": "0.3.2",
    }


@app.get("/feed-cost-pressure")
def feed_cost_pressure_endpoint():
    """
    Feed cost pressure, derived from AHDB weekly feed ingredient prices.

    Separate from /supply-pressure because it is a different measurement with
    a different horizon and a different validation status. Validated for pork
    only; every other category returns null rather than a default.
    """
    get_data()
    results = {c: current_feed_pressure(_feed_series, c) for c in sorted(FEED_VALIDATED_CATEGORIES)}
    return {
        "feed_cost_pressure": results,
        "explanations": {c: describe_pressure(r) for c, r in results.items()},
        "validated_categories": sorted(FEED_VALIDATED_CATEGORIES),
        "untested_categories": ["poultry", "beef", "dairy", "eggs"],
        "note": "Beef was tested and showed no significant relationship at any lag "
                "from 8 weeks to 2 years; feed is a small share of UK beef production "
                "cost. Poultry, dairy and eggs are untested. See "
                "data/validation/feed_lead_lag.md.",
    }


@app.post("/search-foods")
def search_foods(request: FoodSearchRequest):
    foods, _, _ = get_data()
    q = request.query.strip().lower()
    matches = foods[foods["name_lower"].str.contains(q, na=False)]
    return {
        "results": matches[["food_id", "Food_name", "Category", "role_norm"]].rename(
            columns={"Food_name": "food_name", "Category": "category", "role_norm": "role"}
        ).to_dict(orient="records"),
        "total": len(matches),
    }


@app.get("/get-seasonal-foods")
def get_seasonal_foods(category: Optional[str] = None):
    foods, _, prices = get_data()
    seasonal = prices.dropna(subset=["seasonal_note"])
    if category:
        cat_ids = foods[foods["Category"].str.lower() == category.lower()]["food_id"].tolist()
        seasonal = seasonal[seasonal["food_id"].isin(cat_ids)]
    return {
        "seasonal_foods": seasonal[["food_id", "food_name", "seasonal_note"]].to_dict(orient="records"),
        "total": len(seasonal),
    }


@app.get("/supply-pressure")
def supply_pressure():
    """
    Expose current Supply Pressure Index scores.
    Shows grain-level and food-category-level supply pressure
    derived from AHDB UK cereal balance sheet data.
    """
    get_data()
    cat_pressure = _supply_pressure.get("food_category_pressure", {}) or {}

    # Categories sitting on the neutral default have no free stock series
    # published in the balance sheets. Naming them explicitly keeps a reader
    # from mistaking an absent series for a mid-range measurement.
    no_data_categories = [
        c for c, p in cat_pressure.items()
        if isinstance(p, (int, float)) and abs(float(p) - NEUTRAL_PRESSURE) < NEUTRAL_EPSILON
    ]

    return {
        "supply_pressure": _supply_pressure,
        "neutral_default": NEUTRAL_PRESSURE,
        "no_data_categories": no_data_categories,
        "description": "Supply pressure scores derived from AHDB UK cereal balance sheet data. "
                       "Higher score = more supply pressure = greater price volatility risk. "
                       f"A score of exactly {NEUTRAL_PRESSURE} means no free stock series is "
                       "published for that commodity, so it is treated neutrally rather than "
                       "penalised.",
    }


# ---------------------------------------------------------------------------
# Swap feedback telemetry
# Anonymous accept/dismiss counts — no user identifiers collected
# ---------------------------------------------------------------------------

import datetime as _dt


class SwapFeedbackRequest(BaseModel):
    original_id: str = Field(..., description="food_id of the original item, e.g. 'P01'")
    substitute_id: str = Field(..., description="food_id of the suggested substitute, e.g. 'P02'")
    accepted: bool = Field(..., description="true if the user accepted the swap, false if dismissed")


@app.post("/swap-feedback")
async def swap_feedback(request: SwapFeedbackRequest):
    """
    Record a user's accept/dismiss decision on a suggested swap.
    Anonymous — counts only, no user identifiers stored.
    """
    outcome = "accepted" if request.accepted else "dismissed"
    today = _dt.date.today().isoformat()
    pair = f"{request.original_id.upper()}-{request.substitute_id.upper()}"

    keys = [
        f"m:swaps_{outcome}",
        f"m:swaps_{outcome}:daily:{today}",
        f"m:swappair:{pair}:{outcome}",
    ]
    # Fire and forget — telemetry must never slow or fail the app.
    asyncio.create_task(_pipeline([["INCR", k] for k in keys]))

    return {"status": "recorded", "outcome": outcome}
