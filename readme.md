# Elio technical assessment: predicting bad reviews at carrier handover

Predicts which Olist orders are likely to get a 1-2 star review, scored when the seller hands the parcel to the carrier, and designs a campaign and experiment around it. Written answers are in `analysis_answers.md` and the client memo in `memo.md`.

## Setup
- **Database:** DuckDB, as a local file (no account needed)
- **Python:** 3.14
- **Install dependencies** (Windows PowerShell):
  ```
  python -m venv .venv
  .venv\Scripts\Activate.ps1
  pip install -r requirements.txt
  ```
  On macOS or Linux, activate with `source .venv/bin/activate` instead.

## Data
Download the Olist Brazilian E-Commerce Public Dataset from Kaggle and place the nine CSV files in `data/raw/`. The raw data and the DuckDB file are not committed (see `.gitignore`).

## How to run
Run the notebooks in order, from the `notebooks/` folder:
1. **`00_load_and_explore_data.ipynb`**: loads the CSVs into `data/olist.duckdb` and explores the data (data quality, repeat purchase, delivery vs reviews, trends, sellers).
2. **`01_model.ipynb`**: runs the SQL files to build the modelling dataset, then trains and evaluates the model and sizes the campaign.

Close the first notebook (or run its last cell, `con.close()`) before starting the second, as DuckDB allows only one connection to write to the file at a time.

The SQL in `sql/` is run from `01_model.ipynb`, in this order:
1. `clean_orders.sql`: one row per delivered order, with items, payments and the earliest review
2. `seller_history.sql`: each seller's earlier late deliveries and bad reviews, counting only outcomes known at handover
3. `feature_table.sql`: features known at handover and the `bad_review` target

## Assumptions and shortcuts
- A bad review is 1-2 stars; 3 stars is treated as neutral.
- Each order is linked to its first item's seller (exact for 98.7% of orders).
- Seller rates are smoothed towards training-period averages (9% late, 14% bad reviews) with a fixed weight of 10 orders.
- Geolocation is not used; a same-state flag stands in for distance.
- A single train/test split is used (before / from 1 April 2018) rather than rolling validation.
- Campaign effect sizes (10-30%) and the 5 dollar voucher are assumptions. Amounts are in the dataset's currency (Brazilian reais), shown as $.

## What I would do next
- Recalibrate predicted probabilities on recent months, as the model over-predicts in calmer periods.
- Validate on rolling monthly windows, with a gap for the delay before reviews arrive.
- Add exact seller-customer distance from geolocation, and use the slowest seller's history for multi-seller orders.
- Analyse review text to understand bad reviews not explained by delivery timing.
- Compare against a gradient-boosted model, to check whether non-linear effects justify less explainability.
- Once the experiment has run, move from risk prediction to uplift modelling, targeting the orders where contact actually changes the outcome.