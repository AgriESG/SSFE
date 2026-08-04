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

OATS — RESOLVED, AND WHY THE MEASURES DIFFER BY GRAIN:
------------------------------------------------------
Oats previously returned the neutral 0.5 because the AHDB oats sheet publishes
neither 'of which free stock' nor 'Exports'. Two missing rows, not one: the
export line was the binding problem, since without it total demand was NaN and
the stock-to-use ratio never computed at all.

Both extractions now fall back:

    stocks   free stock            -> Commercial End-Season Stocks
    demand   domestic + exports    -> domestic consumption only

which means oats is measured differently from wheat and barley. That is
defensible for one specific reason: calculate_grain_pressure() scores each
grain by percentile rank within its OWN history, so an absolute level is never
compared across grains. Only "where does this season sit against this grain's
past" crosses the boundary, and that question is answerable from any
internally consistent measure.

It would not be defensible if the scores were compared on absolute level, and
it would not be defensible to switch wheat and barley onto commercial stocks
for symmetry — that measure ignores the operating stock requirement and would
materially change two readings that are currently correct.

Effect of the change (2024/25 vintage):
    Oats     0.5000 (no data)  ->  0.1126  on 26 seasons
    Wheat    0.4889            ->  0.4889  unchanged
    Barley   0.1925            ->  0.1925  unchanged
    Category stability spread   0.146  ->  0.215

measures_used is returned in the index so which fallback applied is visible in
the API response rather than buried here.
"""

import pandas as pd
import numpy as np
from pathlib import Path

# ─────────────────────────────────────────────
# File paths
# ─────────────────────────────────────────────
# Resolved relative to this file so it works regardless of where uvicorn
# launches from.
#
# data/ is split by how each file behaves over time:
#   data/live/        re-downloaded from AHDB on a weekly cadence
#   data/reference/   the food dataset, changes only when edited
#   data/validation/  frozen snapshots backing the published backtest
#
# These two are AHDB balance sheets, so they live in data/live/. An earlier
# version pointed at data/ directly and broke when those subfolders were
# introduced.
_BASE = Path(__file__).resolve().parent.parent.parent
SUPPLY_DEMAND_PATH = _BASE / "data" / "live" / "supply_demand.xlsx"
ANIMAL_FEED_PATH = _BASE / "data" / "live" / "animal_feed_production.xlsx"

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

    Raises FileNotFoundError naming the path that was tried, so a future
    directory change fails loudly at startup rather than surfacing as an
    opaque pandas error at request time.
    """
    if not SUPPLY_DEMAND_PATH.exists():
        raise FileNotFoundError(
            f"Balance sheet not found at {SUPPLY_DEMAND_PATH}. "
            f"Expected data/live/supply_demand.xlsx relative to the repository "
            f"root (resolved base: {_BASE})."
        )

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
    if not ANIMAL_FEED_PATH.exists():
        raise FileNotFoundError(
            f"Animal feed production data not found at {ANIMAL_FEED_PATH}. "
            f"Expected data/live/animal_feed_production.xlsx relative to the "
            f"repository root (resolved base: {_BASE})."
        )

    df = pd.read_excel(
        ANIMAL_FEED_PATH,
        sheet_name='GB animal feed month view',
        header=None
    )
    return df


# ─────────────────────────────────────────
# STAGE 2: Balance Sheet Extraction
# ─────────────────────────────────────────

def extract_balance_sheet(raw_df: pd.DataFrame) -> tuple[pd.DataFrame, dict]:
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

    Returns the balance sheet and a dict naming which measure was used for
    stocks and for demand, so a caller can surface the fallback rather than
    silently reporting a number derived differently from its neighbours.
    """

    # Extract crop years from row 6, starting at column 1
    crop_years = raw_df.iloc[6, 1:].tolist()

    # Extract data rows — column 0 is label, columns 1+ are values
    data_rows = raw_df.iloc[7:].copy()
    data_rows = data_rows.set_index(0)
    data_rows.columns = crop_years
    data_rows.index = data_rows.index.astype(str).str.strip()

    def row(label: str) -> pd.Series:
        """Partial match handles minor label variations across grain sheets."""
        matching = [idx for idx in data_rows.index if label.lower() in idx.lower()]
        if not matching:
            return pd.Series(dtype=float)
        return pd.to_numeric(data_rows.loc[matching[0]], errors='coerce')

    measures = {}

    # Stocks. Free stock is preferred: it is the genuinely available buffer
    # once the operating stock requirement is met. Where AHDB does not publish
    # it, commercial end-season stocks is the next best consistent series for
    # that grain.
    stocks = row('of which free stock')
    if stocks.dropna().empty:
        stocks = row('Commercial End-Season Stocks')
        measures['stocks'] = 'commercial end-season stocks'
    else:
        measures['stocks'] = 'free stock'

    # Demand. Exports are included where published because they are real claims
    # on supply that reduce the available buffer. The oats sheet carries no
    # export line, only an 'Exportable surplus' figure, which is a different
    # concept and is not substituted in.
    domestic = row('Total Domestic Consumption')
    exports = row('Exports')
    if exports.dropna().empty:
        demand = domestic
        measures['demand'] = 'domestic consumption only'
    else:
        demand = domestic + exports
        measures['demand'] = 'domestic consumption + exports'

    result = pd.DataFrame({
        'closing_stocks': stocks,
        'domestic_use': domestic,
        'exports': exports,
        'total_demand': demand,
    })

    # Stock-to-use ratio. Negative values are preserved as meaningful signals:
    # a free stock deficit is a real condition, not bad data.
    result['stock_to_use'] = result['closing_stocks'] / result['total_demand']

    return result, measures


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
        # Consistent with AgriESG missing data philosophy.
        # Downstream code treats exactly 0.5 as "no data" rather than as a
        # mid-range measurement, so this value must stay exact.
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
        'data_vintage': '2024/25–2025/26',
        'measures_used': {
            'Wheat': {'stocks': 'free stock',
                      'demand': 'domestic consumption + exports',
                      'vintage': '2025/26'},
            'Oats':  {'stocks': 'commercial end-season stocks',
                      'demand': 'domestic consumption only',
                      'vintage': '2024/25'}
        }
    }
    """

    # Load raw data
    raw_data = load_supply_demand()

    # Extract balance sheets and calculate grain pressure
    grain_pressures = {}
    measures_used = {}
    vintages = []

    for grain in GRAINS:
        balance_sheet, measures = extract_balance_sheet(raw_data[grain])
        grain_pressures[grain] = calculate_grain_pressure(balance_sheet)

        # Latest season this grain actually has a computable ratio for. Grains
        # do not move in step: AHDB publishes the oats stock figure later than
        # wheat and barley, so oats currently lags one season behind.
        valid_years = balance_sheet['stock_to_use'].dropna().index.tolist()
        grain_vintage = str(valid_years[-1]) if valid_years else None
        measures['vintage'] = grain_vintage
        # How many seasons the percentile rank is measured against. Grains
        # differ: free stock starts later than commercial stocks, so oats has
        # a longer run than wheat and barley despite lagging by a season.
        measures['seasons'] = len(valid_years)
        measures_used[grain] = measures
        if grain_vintage:
            vintages.append(grain_vintage)

    # Report the span, not one grain's value.
    #
    # An earlier version simply let the loop variable survive, so the whole
    # index was labelled with whichever grain happened to be iterated last.
    # Oats is last in GRAINS and lags a season, so the index reported the
    # OLDEST vintage by accident of ordering while discarding the current
    # readings for wheat and barley.
    #
    # Reporting only the newest would be the opposite error: it would imply
    # oats is current when it is not. Crop years sort correctly as strings
    # because the starting year is four digits.
    if not vintages:
        data_vintage = None
    elif min(vintages) == max(vintages):
        data_vintage = min(vintages)
    else:
        data_vintage = f'{min(vintages)}–{max(vintages)}'

    # Map to food categories
    food_category_pressure = calculate_food_category_pressure(grain_pressures)

    return {
        'grain_pressure': grain_pressures,
        'food_category_pressure': food_category_pressure,
        'data_vintage': data_vintage,
        # Which stock and demand series backed each grain. Surfaced rather than
        # hidden, because oats is derived from different rows than wheat and
        # barley and a reader should be able to see that.
        'measures_used': measures_used,
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
        m = result['measures_used'].get(grain, {})
        note = f"  [{m.get('stocks', '?')} / {m.get('demand', '?')}, {m.get('vintage', '?')}]"
        if score == 0.5:
            note += '  (neutral default — insufficient data)'
        print(f"  {grain:<8} {score:.3f}  {bar}{note}")

    print(f"\nFood Category Pressure Scores (data vintage: {result['data_vintage']}):")
    for category, score in result['food_category_pressure'].items():
        bar = '█' * int(score * 20)
        print(f"  {category:<10} {score:.4f}  {bar}")
