"""
Data Loader — AgriESG Food Twin Engine
=======================================
Loads the three sheets from food_knowledge_dataset.xlsx and returns
clean DataFrames ready for use by the API and scoring engines.
"""

import os
import pandas as pd


def load_food_data():
    """
    Load food dataset from Excel file.

    Returns:
    --------
    foods         : Foods_Master DataFrame — 100 foods with nutrition,
                    environmental, behavioural fields
    substitutions : Substitutions DataFrame — pre-mapped swap pairs
                    with swap_realism scores
    prices        : Retailer_Prices DataFrame — Tesco, ASDA, Aldi prices
    """
    base_dir = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
    file_path = os.path.join(base_dir, "data", "food_knowledge_dataset.xlsx")

    foods = pd.read_excel(file_path, sheet_name="Foods_Master")
    substitutions = pd.read_excel(file_path, sheet_name="Substitutions")
    prices = pd.read_excel(file_path, sheet_name="Retailer_Prices")

    return foods, substitutions, prices