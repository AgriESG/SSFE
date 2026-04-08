import pandas as pd
import os

def load_food_data():
    base_dir = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
    file_path = os.path.join(base_dir, "data", "food_knowledge_dataset.xlsx")

    foods = pd.read_excel(file_path, sheet_name="Foods_Master")
    substitutions = pd.read_excel(file_path, sheet_name="Substitutions")
    prices = pd.read_excel(file_path, sheet_name="Retailer_Prices")

    return foods, substitutions, prices