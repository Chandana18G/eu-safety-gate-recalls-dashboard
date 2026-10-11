"""
verify_counts.py - recompute the dashboard's headline numbers in Python.

It applies the same cleaning rules as power-query/Recall.m and AffectedCountries.m,
independently of Power BI, so the dashboard's cards can be checked against it.

Usage:
    pip install pandas openpyxl
    python checks/verify_counts.py
"""

from pathlib import Path

import pandas as pd

DATA = Path(__file__).resolve().parent.parent / "data" / "safety_gate_motor_vehicles_2026-08-02.xlsx"

BRAND_FIXES = {"Bmw": "BMW", "Vw": "VW", "Ktm": "KTM", "Daf": "DAF", "Man": "MAN", "AUDI": "Audi",
               "CITROEN": "Citroen", "NEW HOLLAND": "New Holland", "VOLVO TRUCKS": "Volvo Trucks"}

VEHICLE_RULES = [  # first match wins, same order as Recall.m
    ("Component / Part", ["tyre", "tire", "part", "component", "helmet"]),
    ("Passenger car", ["passenger car"]),
    ("Camper / Motorhome", ["camper", "motorhome", "mobile home", "caravan"]),
    ("Two-Wheeler", ["motorcycle", "scooter", "moped", "bicycle", "three-wheel"]),
    ("Van / LCV", ["van", "light commercial", "pickup", "pick-up", "utility"]),
    ("Truck / Lorry", ["lorry", "truck", "heavy goods"]),
    ("Bus / Coach", ["bus", "coach"]),
    ("Agricultural / ATV", ["tractor", "terrain", "atv", "quad"]),
    ("Trailer", ["trailer"]),
]

COMPONENT_RULES = [
    ("Airbag / Restraints", ["airbag", "seat belt", "seatbelt"]),
    ("Braking / ESP", ["brak"]),
    ("Steering", ["steer"]),
    ("Fuel System", ["fuel"]),
    ("Battery / HV", ["batter", "high-voltage", "high voltage"]),
    ("Electrical / Software", ["electr", "software", "wiring"]),
    ("Wheels / Suspension", ["wheel", "suspension", "bearing", "axle"]),
    ("Engine / Powertrain", ["engine", "transmission", "gearbox"]),
    ("Body / Interior", ["roof", "door", "window", "mirror"]),
]


def classify(text, rules, default):
    low = text.lower()
    return next((label for label, words in rules if any(w in low for w in words)), default)


def load():
    raw = pd.read_excel(DATA, sheet_name="Weekly Reports", header=2, dtype=str)
    raw = raw[raw["Alert number"].fillna("").str.strip() != ""]
    df = pd.DataFrame({
        "alert": raw["Alert number"].str.strip(),
        "risk": raw["Type of alert"].str.strip(),
        "notifying": raw["Alert submitted by"].str.strip(),
        "origin": raw["Country of origin"].str.strip(),
        "hazard": raw["Risk type"].fillna("").str.strip(),
        "description": raw["Risk legal provision"].fillna("").str.strip(),
        "vehicle_type": raw["Product"].fillna("").str.strip(),
        "brand_raw": raw["Brand"].fillna("").str.strip(),
        "also": raw["Products were found and measures were taken also in"].fillna("").str.strip(),
    })
    df["year"] = 2000 + df["alert"].str.split("/").str[-1].astype(int)
    df["multi_brand"] = df["brand_raw"].str.contains(",")
    df["brand"] = df["brand_raw"].str.split(",").str[0].str.strip().replace(BRAND_FIXES)
    df["category"] = df["vehicle_type"].map(lambda v: classify(v, VEHICLE_RULES, "Other"))
    df["component"] = df["description"].map(
        lambda d: "Not classified (no description)" if not d else classify(d, COMPONENT_RULES, "Other (unmatched)"))
    affected = (df[["alert", "also"]].assign(country=df["also"].str.split(","))
                .explode("country").assign(country=lambda t: t["country"].str.strip()))
    affected = affected[affected["country"] != ""].drop_duplicates(["alert", "country"])
    return df, affected


def main():
    df, affected = load()
    n = len(df)
    pct = lambda x: f"{100 * x / n:.1f}%"
    unclassified = df["component"].isin(["Other (unmatched)", "Not classified (no description)"]).sum()
    print(f"Total Alerts             {n:,}  (unique alert numbers: {df['alert'].nunique():,})")
    print(f"Years                    {df['year'].min()}-{df['year'].max()}")
    print(f"Serious Risk %           {pct((df['risk'] == 'Serious risk').sum())}")
    print(f"Fire Alert %             {pct(df['hazard'].str.contains('fire', case=False).sum())}")
    print(f"Distinct Brands          {df['brand'].nunique():,}")
    print(f"Airbag alerts            {(df['component'] == 'Airbag / Restraints').sum():,}")
    print(f"Missing Description %    {pct((df['description'] == '').sum())}")
    print(f"Classified Component %   {pct(n - unclassified)}")
    print(f"Multi-Brand Alerts       {df['multi_brand'].sum():,}")
    print(f"Downstream exposure      {len(affected):,} alert-country pairs, "
          f"{affected['country'].nunique()} countries")
    print(f"Avg Countries Affected   {len(affected) / n:.2f}")
    print("\nAlerts per year:", df["year"].value_counts().sort_index().to_dict())
    print("\nTop brands:", df["brand"].value_counts().head(5).to_dict())
    print("Top notifying:", df["notifying"].value_counts().head(3).to_dict())
    print("Top origin:", df["origin"].value_counts().head(3).to_dict())
    print("\nVehicle category:", df["category"].value_counts().to_dict())
    print("Component:", df["component"].value_counts().to_dict())


if __name__ == "__main__":
    main()
