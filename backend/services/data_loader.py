"""
Data Loader — AgriESG Food Twin Engine
=======================================
Loads the three sheets from food_knowledge_dataset.xlsx and returns
clean DataFrames ready for use by the API and scoring engines.

PATH NOTE
---------
The data directory is split by how each file behaves over time:

    data/live/        refreshed weekly (feed prices, balance sheets)
    data/reference/   the food dataset, changes only when edited
    data/validation/  frozen snapshots backing the published backtest

This loader reads from data/reference/. An earlier version pointed at
data/ directly and broke silently when the subfolders were introduced,
so the path is now explicit and a missing file raises immediately rather
than surfacing as an opaque pandas error at request time.
"""

import os

import pandas as pd

DATASET_RELATIVE_PATH = os.path.join(
    "data", "reference", "food_knowledge_dataset.xlsx"
)


def load_food_data():
    """
    Load food dataset from Excel file.

    Returns:
    --------
    foods         : Foods_Master DataFrame — foods with nutrition,
                    environmental and behavioural fields, plus
                    supply_category and footprint_method
    substitutions : Substitutions DataFrame — pre-mapped swap pairs
                    with swap_realism scores
    prices        : Retailer_Prices DataFrame — Tesco, ASDA, Aldi prices

    Raises:
    -------
    FileNotFoundError : if the dataset is not where it is expected, naming
                        the path that was tried. abspath is used so the
                        result does not depend on the working directory the
                        server happens to start in.
    """
    base_dir = os.path.dirname(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    )
    file_path = os.path.join(base_dir, DATASET_RELATIVE_PATH)

    if not os.path.exists(file_path):
        raise FileNotFoundError(
            f"Food dataset not found at {file_path}. "
            f"Expected {DATASET_RELATIVE_PATH} relative to the repository root "
            f"(resolved base: {base_dir})."
        )

    foods = pd.read_excel(file_path, sheet_name="Foods_Master")
    substitutions = pd.read_excel(file_path, sheet_name="Substitutions")
    prices = pd.read_excel(file_path, sheet_name="Retailer_Prices")

    return foods, substitutions, prices
