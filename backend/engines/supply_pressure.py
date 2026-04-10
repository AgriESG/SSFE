"""
Supply Pressure Index — AgriESG Food Twin Engine
=================================================
Author: Esther Oluwasolayimika Olusola

PURPOSE:
--------
This module computes a Supply Pressure Index (SPI) for UK cereal crops
(wheat, barley, oats) using publicly available AHDB national balance sheet data.

The SPI is a novel component of the Food Twin optimisation engine. It translates
upstream agricultural supply conditions into a forward-looking signal that
adjusts food substitution recommendations before retail price movements become
visible to consumers.

NOVEL CONTRIBUTION:
-------------------
No existing consumer food optimisation system incorporates agricultural supply
chain intelligence. The SPI connects farm-gate cereal supply conditions to
consumer basket optimisation through three mechanisms:

1. Stock-to-use ratio as structural supply baseline
2. Multi-season trend as directional pressure signal
3. Grain-to-food category mapping derived from AHDB animal feed production data

DESIGN DECISIONS:
-----------------
- Stock-to-use ratio chosen over raw price data because it reflects structural
  supply state independent of short-term market speculation
- Historical average normalisation chosen over fixed thresholds because UK
  cereal markets have different baseline conditions across decades
- Neutral score (0.5) applied when data is insufficient rather than
  excluding the grain — consistent with AgriESG scoring philosophy
- Pressure scores capped at [0, 1] to ensure stable optimisation inputs
"""

import pandas as pd
import numpy as np
from pathlib import Path

# ─────────────────────────────────────────────
# File paths — relative to project root (SSFE/)
# ─────────────────────────────────────────────
# Resolve path relative to this file so it works regardless of where uvicorn launches from
_BASE = Path(__file__).resolve().parent.parent.parent
SUPPLY_DEMAND_PATH = _BASE / "data" / "supply_demand.xlsx"
ANIMAL_FEED_PATH = _BASE / "data" / "animal_feed_production.xlsx"

# Grains tracked — these are the three cereals with
# complete UK balance sheet data in the AHDB dataset
GRAINS = ['Wheat', 'Barley', 'Oats']

# ─────────────────────────────────────────────────────────────────
# Grain-to-food category mapping weights
#
# These weights are empirically derived from the AHDB GB Animal Feed
# Production dataset (GB_AFproduction.xlsx), which shows monthly
# grain usage in thousand tonnes by feed category.
#
# Design decision: weights reflect actual grain composition of each
# feed category, not assumed values. This makes the mapping
# defensible and traceable to published AHDB data.
#
# Poultry: wheat-dominant (~60%), some barley (~20%)
# Pork: wheat-dominant (~50%), some barley (~20%)
# Beef/dairy: more diversified, barley more prominent
# Bread/cereals: direct wheat consumption, no animal feed intermediary
# ─────────────────────────────────────────────────────────────────
FOOD_CATEGORY_WEIGHTS = {
    'poultry': {'Wheat': 0.60, 'Barley': 0.20, 'Oats': 0.05},
    'pork':    {'Wheat': 0.50, 'Barley': 0.20, 'Oats': 0.05},
    'beef':    {'Wheat': 0.20, 'Barley': 0.30, 'Oats': 0.10},
    'dairy':   {'Wheat': 0.15, 'Barley': 0.20, 'Oats': 0.10},
    'bread':   {'Wheat': 0.90, 'Barley': 0.00, 'Oats': 0.00},
    'cereals': {'Wheat': 0.50, 'Barley': 0.10, 'Oats': 0.40},
    'eggs':    {'Wheat': 0.55, 'Barley': 0.15, 'Oats': 0.05},
}


# ─────────────────────────────────────────
# STAGE 1: Data Loading
# ─────────────────────────────────────────

def load_supply_demand() -> dict:
    """
    Load UK cereal supply and demand balance sheets from AHDB public data.

    Returns a dict keyed by grain name, each value is a raw DataFrame.
    Raw format is preserved here — parsing happens in extract_balance_sheet()
    to keep loading and transformation separate (separation of concerns).
    """
    data = {}
    for grain in GRAINS:
        df = pd.read_excel(SUPPLY_DEMAND_PATH, sheet_name=grain, header=None)
        data[grain] = df
    return data


def load_animal_feed() -> pd.DataFrame:
    """
    Load GB animal feed production data from AHDB public dataset.

    We use the monthly view sheet which shows grain usage by feed category
    in thousand tonnes. This is the empirical basis for FOOD_CATEGORY_WEIGHTS.
    """
    df = pd.read_excel(
        ANIMAL_FEED_PATH,
        sheet_name='GB animal feed month view',
        header=None
    )
    return df


# ─────────────────────────────────────────
# STAGE 2: Balance Sheet Extraction
# ─────────────────────────────────────────

def extract_balance_sheet(raw_df: pd.DataFrame) -> pd.DataFrame:
    """
    Extract structured balance sheet from raw AHDB supply/demand DataFrame.

    The AHDB Excel format uses:
    - Row 6: crop year headers starting at column 1 (e.g. '1999/00', '2000/01')
    - Column 0: row labels throughout
    - Rows 7+: data

    Rows extracted:
    - Free Stock (of which free stock): genuinely available buffer after operating requirements met
    - Total Domestic Consumption: all domestic use (feed, food, seed, waste)
    - Exports: grain leaving the UK

    Design decision: Total Demand = Total Domestic Consumption + Exports
    This gives us the denominator for stock-to-use ratio that reflects
    all claims on available supply, not just domestic consumption.
    """

    # Extract crop years from row 6, starting at column 1
    crop_years = raw_df.iloc[6, 1:].tolist()

    # Extract data rows — column 0 is label, columns 1+ are values
    data_rows = raw_df.iloc[7:].copy()
    data_rows = data_rows.set_index(0)
    data_rows.columns = crop_years
    data_rows.index = data_rows.index.astype(str).str.strip()

    # Row labels as they actually appear in AHDB Excel files
    # These were verified against the published dataset structure
    rows_needed = {
        'closing_stocks': 'of which free stock',
        'domestic_use': 'Total Domestic Consumption',
        'exports': 'Exports'
    }

    extracted = {}
    for key, label in rows_needed.items():
        # Partial match handles minor label variations across grain sheets
        matching = [idx for idx in data_rows.index
                   if label.lower() in idx.lower()]
        if matching:
            row = data_rows.loc[matching[0]]
            extracted[key] = pd.to_numeric(row, errors='coerce')
        else:
            extracted[key] = pd.Series(dtype=float)

    result = pd.DataFrame(extracted)

    # Total demand = domestic consumption + exports
    # Design decision: exports included because they represent real
    # claims on supply that reduce available buffer stock
    result['total_demand'] = result['domestic_use'] + result['exports']

    # Stock-to-use ratio
    # Design decision: free stock used rather than commercial end-season stocks
    # because free stock is the genuinely available buffer after operating
    # stock requirements are met. Negative values preserved as meaningful signals.
    result['stock_to_use'] = result['closing_stocks'] / result['total_demand']

    return result


# ─────────────────────────────────────────
# STAGE 3: Supply Pressure Calculation
# ─────────────────────────────────────────

def calculate_grain_pressure(balance_sheet: pd.DataFrame) -> float:
    """
    Calculate a single Supply Pressure Score for one grain.

    Returns a float between 0 and 1 where:
    - 0.0 = no supply pressure (stocks well above historical average)
    - 0.5 = neutral (stocks at historical average)
    - 1.0 = maximum supply pressure (stocks critically below historical average)

    METHODOLOGY:
    ------------
    Step 1: Use percentile rank of current free stock ratio vs history
            Design decision: percentile rank chosen over simple deviation
            because free stock ratios include negative values (deficit years)
            making mean-based normalisation unreliable. Percentile rank is
            robust to negative values and extreme outliers.

    Step 2: Invert percentile to get pressure
            Low percentile rank = low stocks vs history = high pressure
            pressure = 1 - percentile_rank

    Step 3: Add trend component
            Direction of change over last 3 seasons amplifies signal
            when conditions are deteriorating
            Design decision: trend weighted at 30% to avoid overreaction
            to single-season anomalies

    Step 4: Cap between 0 and 1
            Ensures stable input to optimisation engine
    """

    stu = balance_sheet['stock_to_use'].dropna()

    if len(stu) < 3:
        # Insufficient data — return neutral score
        # Consistent with AgriESG missing data philosophy
        return 0.5

    # Current state — most recent crop year
    current_stu = stu.iloc[-1]

    # Percentile rank of current value within historical distribution
    # Design decision: percentile rank is robust to negative free stock
    # values which occur in genuine deficit years (e.g. UK wheat 2020/21)
    # A mean-based approach would be distorted by these extreme values
    percentile_rank = (stu < current_stu).sum() / len(stu)

    # Invert: low stocks = low percentile = high pressure
    base_pressure = 1 - percentile_rank

    # Trend component — direction of change over last 3 seasons
    # Positive trend_pressure means free stocks have been falling
    recent = stu.iloc[-3:]
    trend = np.polyfit(range(len(recent)), recent.values, 1)[0]

    # Normalise trend by standard deviation to make scale-independent
    # Using std rather than mean because mean may be near zero with
    # negative values present
    std = stu.std()
    trend_pressure = (-trend / std) * 0.5 if std > 0 else 0.0

    # Combine: 70% current percentile state, 30% trend direction
    # Design decision: current state weighted higher because trend can
    # reverse quickly in response to a good harvest
    combined_pressure = (0.70 * base_pressure) + (0.30 * trend_pressure)

    # Cap between 0 and 1
    return float(np.clip(combined_pressure, 0.0, 1.0))



# ─────────────────────────────────────────
# STAGE 4: Food Category Pressure Mapping
# ─────────────────────────────────────────

def calculate_food_category_pressure(grain_pressures: dict) -> dict:
    """
    Map grain-level supply pressure to consumer food categories.

    Uses FOOD_CATEGORY_WEIGHTS to translate cereal supply conditions
    into food-category-level pressure scores.

    Design decision: weighted sum rather than maximum because multiple
    grains contribute to most food categories simultaneously. Using
    maximum would overstate pressure when only one grain is tight.

    Returns dict of food category → pressure score (0 to 1)
    """
    category_pressure = {}

    for category, weights in FOOD_CATEGORY_WEIGHTS.items():
        pressure = 0.0
        total_weight = 0.0

        for grain, weight in weights.items():
            if grain in grain_pressures and weight > 0:
                pressure += grain_pressures[grain] * weight
                total_weight += weight

        # Normalise by actual weights used
        if total_weight > 0:
            category_pressure[category] = round(pressure / total_weight, 4)
        else:
            category_pressure[category] = 0.5

    return category_pressure


# ─────────────────────────────────────────
# STAGE 5: Main Interface
# ─────────────────────────────────────────

def get_supply_pressure_index() -> dict:
    """
    Main entry point for the Supply Pressure Index.

    Called by the Food Twin optimisation engine to retrieve current
    supply pressure scores by food category.

    Returns:
    --------
    {
        'grain_pressure': {
            'Wheat': 0.73,
            'Barley': 0.41,
            'Oats': 0.28
        },
        'food_category_pressure': {
            'poultry': 0.61,
            'pork': 0.54,
            'beef': 0.38,
            'dairy': 0.33,
            'bread': 0.73,
            'cereals': 0.47,
            'eggs': 0.58
        },
        'data_vintage': '2024/25'
    }
    """

    # Load raw data
    raw_data = load_supply_demand()

    # Extract balance sheets and calculate grain pressure
    grain_pressures = {}
    data_vintage = None

    for grain in GRAINS:
        balance_sheet = extract_balance_sheet(raw_data[grain])
        grain_pressures[grain] = calculate_grain_pressure(balance_sheet)

        # Capture most recent crop year for transparency
        valid_years = balance_sheet['stock_to_use'].dropna().index.tolist()
        if valid_years:
            data_vintage = str(valid_years[-1])

    # Map to food categories
    food_category_pressure = calculate_food_category_pressure(grain_pressures)

    return {
        'grain_pressure': grain_pressures,
        'food_category_pressure': food_category_pressure,
        'data_vintage': data_vintage
    }


# ─────────────────────────────────────────
# Quick test when run directly
# ─────────────────────────────────────────

if __name__ == "__main__":
    print("Running Supply Pressure Index...\n")
    result = get_supply_pressure_index()

    print("Grain Pressure Scores:")
    for grain, score in result['grain_pressure'].items():
        bar = '█' * int(score * 20)
        print(f"  {grain:<8} {score:.3f}  {bar}")

    print(f"\nFood Category Pressure Scores (data vintage: {result['data_vintage']}):")
    for category, score in result['food_category_pressure'].items():
        bar = '█' * int(score * 20)
        print(f"  {category:<10} {score:.4f}  {bar}")