# Applying the data fixes in Power BI Desktop

The fixes below were found by reading the `.pbix` model and checking it against the source
data with `checks/verify_counts.py`. They take about 10 minutes in Power BI Desktop.

Open `EU_Safety_Gate_Motor_Recalls.pbix` (a copy; the original stays untouched).

> **Status:** applied to `EU_Safety_Gate_Motor_Recalls.pbix` on 11 October 2026. All nine cards
> and the 2021 check below match `checks/verify_counts.py` exactly. The `DimYear` → `Recall`
> relationship (step 2) was created automatically on refresh once both `Year` columns were
> whole numbers. Percentage measures were also formatted as percentages, and the Data Quality
> limitation text was updated to the corrected numbers.

## 1. Replace the two Power Query scripts

**Home → Transform data** opens Power Query. For each query below: select it on the left,
**Home → Advanced Editor**, select all, paste the file's contents, **Done**.

| Query | Paste the contents of |
|---|---|
| `Recall` | `power-query/Recall.m` (check that `DataFile` points to the workbook in `data/`) |
| `AffectedCountries` | `power-query/AffectedCountries.m` |

Then **Home → Close & Apply**.

## 2. Connect the year table

**Model view → Manage relationships → New**:
`DimYear[Year]` (one) → `Recall[Year]` (many), single cross-filter direction, active.

Without this, the year slicer, the alerts-by-year chart, `YoY %` and the trend text don't
respond to the year.

## 3. Fix one measure

Select the measure **Bike Airbag Alerts** (table `AffectedCountries`), replace its formula and
rename it **Airbag Alerts**:

```dax
Airbag Alerts = CALCULATE([Total Alerts], 'Recall'[Component] = "Airbag / Restraints")
```

## 4. Check the cards against `checks/verify_counts.py`

With no filters selected, the cards should show:

| Card | Expected |
|---|---|
| Total Alerts | 4,184 |
| Serious Risk % | 97.9% |
| Fire Alert % | 19.9% |
| Distinct Brands | 443 |
| Airbag Alerts | 199 |
| Missing Description % | 20.0% |
| Classified Component % | 24.0% |
| Multi-Brand Alerts | 92 |
| Avg Countries Affected | 6.27 |

Selecting **2021** in the year slicer should show **548** alerts.

## What was wrong (before → after)

| Issue | Effect | Fix |
|---|---|---|
| Header row skipped, first alert promoted to column names | 2 alerts missing (4,182 instead of 4,184) | Skip the 2 title rows, promote the real header row |
| `DimYear` not related to `Recall` | Year slicer, yearly chart, YoY and trend text didn't filter | Add the 1 → many relationship |
| Keyword rules contained a literal tab (`"#(tab)brak"`) and were case-sensitive | Braking (144) and steering (93) alerts never classified; "Body / Interior" and "Camper / Motorhome" appeared twice | Case-insensitive keyword matching, no tabs |
| Unmatched label `other(unmatched)` vs `"Other (unmatched)"` in the measure | Classified Component % was ~100% instead of 24% | One consistent label |
| `Has Description` used `<> ""`, which is null-unsafe | Missing Description % showed 0% instead of 20% | Null-safe check |
| Affected countries split on spaces and de-duplicated globally | "The", "Netherlands," as countries; one row per country instead of per alert | Split on commas, de-duplicate per alert |
| `Bike Airbag Alerts` filtered on `"Airbag"`, a label that doesn't exist | Card was blank | Filter on `"Airbag / Restraints"` |
| Text replace `Man → MAN` on brand names | `Mann+Hummel` became `MANN+HUMMEL` | Whole-value brand fixes |
| Vehicle rules missed "Lorry", "Pickup", "Camper van", "Motorcycle tyre" | 579 vehicles in "other" | Ordered, case-insensitive rules: 64 in "Other" |

## Later polish (11 October 2026)

| Issue | Fix |
|---|---|
| 12 alerts have no brand, shown as a blank brand | Labelled "Not specified" (brand count unchanged) |
| One brand typed as "1. Land Rover 2. Range Rover" | Mapped to "Land Rover"; Distinct Brands 444 → **443** |
| Total Alerts card showed "4K" (the card visual has no display-units option) | Card shows `Total Alerts Label = FORMAT([Total Alerts], "#,0", "de-DE")`, matching the report's German number format |
| A duplicate Total Alerts / Airbag Alerts card covered the vehicle-category donut on Overview | Removed (both values are in the KPI row) |
| Donut labels showed "0K" / "3K" | Data-label display units set to None on both donuts |
