"""
AgriESG — FastAPI Backend
Food Optimisation Engine API
"""

import math
import numpy as np
import pandas as pd
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional

from services.data_loader import load_food_data

# ---------------------------------------------------------------------------
# App setup
# ---------------------------------------------------------------------------

app = FastAPI(
    title="AgriESG Food Optimisation API",
    description="Multi-objective food basket optimisation: cost, nutrition, environment.",
    version="0.2.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Role normalisation — collapses inconsistent Role column into functional roles
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
}

def normalise_role(raw: str) -> str:
    return ROLE_MAP.get(str(raw).strip().lower(), "other")

# ---------------------------------------------------------------------------
# Dataset — loaded once at startup
# ---------------------------------------------------------------------------

_foods: pd.DataFrame = None
_subs: pd.DataFrame = None
_prices: pd.DataFrame = None
_score_bounds: dict = {}

def get_data():
    global _foods, _subs, _prices, _score_bounds
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

        _score_bounds = {
            "carbon": (_foods["Carbon_footprint"].min(), _foods["Carbon_footprint"].max()),
            "water":  (_foods["Water"].min(),            _foods["Water"].max()),
            "land":   (_foods["Land"].min(),             _foods["Land"].max()),
            "protein":(_foods["Protein"].min(),          _foods["Protein"].max()),
            "fibre":  (_foods["Fibre"].min(),            _foods["Fibre"].max()),
            "price":  (_prices["best_price_per_kg"].min(), _prices["best_price_per_kg"].max()),
        }

    return _foods, _subs, _prices

# ---------------------------------------------------------------------------
# JSON safety — replace NaN/Inf with 0.0
# ---------------------------------------------------------------------------

def sanitise(val):
    if isinstance(val, float) and (math.isnan(val) or math.isinf(val)):
        return 0.0
    return val

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
        _norm(food_row["Carbon_footprint"], *b["carbon"]) * 0.5 +
        _norm(food_row["Water"],            *b["water"])  * 0.3 +
        _norm(food_row["Land"],             *b["land"])   * 0.2, 2
    )
    nutrition = round(
        _norm(food_row["Protein"], *b["protein"]) * 0.6 +
        _norm(food_row["Fibre"],   *b["fibre"])   * 0.4, 2
    )
    cost = round(_norm(price_per_kg, *b["price"]), 2) if price_per_kg else 50.0
    return {
        "env": sanitise(env),
        "nutrition": sanitise(nutrition),
        "cost": sanitise(cost),
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

def improvement_score(orig_scores: dict, cand_scores: dict) -> float:
    return round(
        (orig_scores["env"]  - cand_scores["env"])  * 0.4 +
        (orig_scores["cost"] - cand_scores["cost"]) * 0.3 +
        (cand_scores["nutrition"] - orig_scores["nutrition"]) * 0.3, 2
    )

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
    return {"message": "AgriESG Food Optimisation API", "version": "0.2.0"}

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
        "food_id": str(row["food_id"]),
        "food_name": str(row["Food_name"]),
        "role": str(row["role_norm"]),
        "nutrition": {
            "calories": float(row["Calories"]),
            "protein_g": float(row["Protein"]),
            "fibre_g": float(row["Fibre"]),
        },
        "environmental": {
            "carbon_kg_co2e": float(row["Carbon_footprint"]),
            "water_litres": float(row["Water"]),
            "land_m2": float(row["Land"]),
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
            "food_id": str(fid),
            "food_name": str(row["Food_name"]),
            "role": str(row["role_norm"]),
            **scores,
            "price_per_kg": float(price) if price else 0.0,
        })

    if not items:
        raise HTTPException(status_code=404, detail="No valid foods found in basket")

    avg_env  = round(np.mean([i["env"] for i in items]), 2)
    avg_nut  = round(np.mean([i["nutrition"] for i in items]), 2)
    avg_cost = round(np.mean([i["cost"] for i in items]), 2)

    return {
        "basket_score": round(avg_env * 0.4 + avg_cost * 0.3 + (100 - avg_nut) * 0.3, 2),
        "avg_env_score": avg_env,
        "avg_nutrition_score": avg_nut,
        "avg_cost_score": avg_cost,
        "items": items,
        "not_found": not_found,
    }

@app.post("/optimise-basket")
def optimise_basket(request: BasketRequest):
    """
    Core endpoint. Accepts food_ids OR food names (backwards compatible).
    Returns before/after scores + ranked substitution recommendations.
    """
    if not request.basket:
        raise HTTPException(status_code=400, detail="Basket cannot be empty")

    foods, subs, prices = get_data()

    # Resolve basket — food_id or name string
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
            "avg_env_score": e, "avg_nutrition_score": n, "avg_cost_score": c,
            "basket_score": round(e * 0.4 + c * 0.3 + (100 - n) * 0.3, 2),
        }

    before_summary = basket_summary(score_basket(resolved_ids))

    # Find best substitution per item
    substitutions = []
    optimised_ids = list(resolved_ids)

    for i, fid in enumerate(resolved_ids):
        orig_row, orig_price = get_food_by_id(fid)
        if orig_row is None:
            continue
        orig_scores = score_food_row(orig_row, orig_price)

        sub_ids = subs[subs["food_id"] == fid]["substitute_food_id"].tolist()
        best_score, best_sub_id, best_sub_row, best_sub_price = 0, None, None, None

        for sub_id in sub_ids:
            sub_row, sub_price = get_food_by_id(sub_id)
            if sub_row is None:
                continue
            imp = improvement_score(orig_scores, score_food_row(sub_row, sub_price))
            if imp > best_score:
                best_score, best_sub_id = imp, sub_id
                best_sub_row, best_sub_price = sub_row, sub_price

        if best_sub_id:
            best_scores = score_food_row(best_sub_row, best_sub_price)
            env_d  = round(orig_scores["env"]  - best_scores["env"],  2)
            cost_d = round(orig_scores["cost"] - best_scores["cost"], 2)
            nut_d  = round(best_scores["nutrition"] - orig_scores["nutrition"], 2)

            parts = []
            if env_d  >= 2: parts.append(f"lower environmental impact (-{env_d:.0f} pts)")
            if cost_d >= 2: parts.append(f"cheaper (-{cost_d:.0f} cost pts)")
            if nut_d  >  0: parts.append(f"better nutrition (+{nut_d:.0f} pts)")
            rationale = ("Swap for " + ", ".join(parts) + ".") if parts else "Marginal combined improvement."

            substitutions.append({
                "original_id": str(fid), "original_name": str(orig_row["Food_name"]),
                "substitute_id": str(best_sub_id), "substitute_name": str(best_sub_row["Food_name"]),
                "role": str(orig_row["role_norm"]), "improvement_score": float(best_score),
                "env_delta": float(env_d), "cost_delta": float(cost_d), "nutrition_delta": float(nut_d),
                "rationale": rationale,
            })
            optimised_ids[i] = best_sub_id

    substitutions.sort(key=lambda x: x["improvement_score"], reverse=True)
    after_summary = basket_summary(score_basket(optimised_ids))

    return {
        "before": before_summary,
        "after":  after_summary,
        "improvement": {
            "basket_score_gain": round(before_summary["basket_score"] - after_summary["basket_score"], 2),
            "env_reduction":     round(before_summary["avg_env_score"]      - after_summary["avg_env_score"], 2),
            "nutrition_gain":    round(after_summary["avg_nutrition_score"] - before_summary["avg_nutrition_score"], 2),
            "cost_reduction":    round(before_summary["avg_cost_score"]     - after_summary["avg_cost_score"], 2),
        },
        "substitutions":       substitutions,
        "items_scored":        len(resolved_ids),
        "substitutions_found": len(substitutions),
        "not_found":           not_found,
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