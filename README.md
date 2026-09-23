# AgriESG

A food optimisation engine that suggests grocery substitutions across four objectives at once: cost, nutrition, environmental footprint, and UK supply stability.

The supply stability objective is what distinguishes this from a carbon calculator. It reads AHDB UK cereal balance sheet data covering the 1999/2000 to 2024/25 seasons, percentile-ranks current free stock within each grain's own history, and feeds the result into the optimiser as a live signal. Because animal feed is traced through to the foods it produces, a basket's dependence on UK wheat includes the wheat inside its poultry.

- **Live API:** https://agriesg-api.onrender.com
- **API docs:** https://agriesg-api.onrender.com/docs
- **Current version:** v0.3.6
- **Client:** Flutter iOS app, TestFlight beta

> The API runs on a free hosting tier that spins down when idle. The first request after a quiet period takes 30 to 50 seconds to wake. Everything after that is fast.

---

## How it works

Each basket item goes through three stages.

**Stage 1: behavioural realism filter** (`engines/behavioural_realism.py`)
Rules out substitutions people would not actually make, scoring candidates on taste, texture, preparation effort and meal context. A swap that is optimal on paper but nobody would cook is not a useful recommendation.

**Stage 2: Supply Pressure Index** (`engines/supply_pressure.py`)
Derives a supply stability score per food category from AHDB cereal balance sheets. Each grain is percentile-ranked within its own history, so absolute levels never cross between grains. Grain-to-food category weights come from animal feed production data. Foods with no mapped AHDB series are treated as absent rather than scored, and the API says so in its response.

**Stage 3: Pareto optimisation** (`engines/pareto_optimiser.py`)
Computes the Pareto frontier across cost, nutrition, environment and supply stability, then ranks the undominated set by user preference. Supply stability is held at a fixed 0.15 weight regardless of preferences, because supply conditions are a structural fact rather than a matter of taste. The remaining weights renormalise around it.

Output is a ranked list of substitutions, each with a plain-English rationale that states what the swap gives up as well as what it gains.

Two components sit alongside the pipeline:

**Feed cost pressure** (`engines/feed_cost_pressure.py`) tracks 13-week movement in AHDB feed ingredient prices against history. It returns a result for pork only, and `None` for every other species, because pork is the only category where the backtest is complete. See [Validation](#validation).

**Crop provenance** traces which UK crops a basket actually rests on, separating direct consumption from the route through animal feed.

---

## Repository layout

```
backend/
  api/
    main.py               FastAPI app, 11 endpoints
    metrics.py            request counting and swap telemetry middleware
  engines/
    behavioural_realism.py
    supply_pressure.py
    pareto_optimiser.py
    feed_cost_pressure.py
  services/
    data_loader.py        workbook loading, held in memory at startup
  data/
    live/                  weekly refresh from AHDB
                          cereal balance sheets, feed ingredient prices,
                          animal feed production
    reference/             food knowledge dataset
                          113 foods, 164 substitution pairs, supply_category
                          mapping, retailer prices with source URLs
    validation/            frozen snapshots and backtest scripts
                          feed_lead_lag.py, feed_lead_lag.md

frontend/                 Flutter iOS client
```

`data/` lives inside `backend/`, not beside it. Render's `rootDir` for this service is `backend`, and its auto-deploy-on-push only evaluates commits that touch files under that root — a data-only refresh outside it is invisible to the trigger and silently never deploys. This bit us once; keeping the data the engines actually read inside the watched root is what makes a weekly AHDB refresh reliably go live on push instead of requiring someone to notice and deploy manually.

### Why there is no database

Reference data is read-only, small enough to hold in memory, and refreshed weekly rather than written to. A relational store would add operational overhead and migration burden for no gain.

It also matters for reproducibility. Published correlation and p-values in `backend/data/validation` were computed against exactly the bytes in that directory. That claim is straightforward to make about versioned files and difficult to make about a mutable database.

Runtime counters live in Redis, which is the one place persistence is genuinely needed.

---

## Running locally

Requires Python [VERSION] and Flutter [VERSION].

```bash
git clone git@github.com:AgriESG/SSFE.git
cd SSFE/backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn api.main:app --reload
```

The API comes up on `http://127.0.0.1:8000`, with interactive docs at `/docs`.

Data workbooks load at startup. If a path is wrong the loader raises `FileNotFoundError` naming the path it tried, rather than failing later with a confusing error.

### Environment variables

| Variable | Purpose | Required |
|---|---|---|
| `UPSTASH_REDIS_REST_URL` | Redis endpoint for usage counters | No, metrics disabled without it |
| `UPSTASH_REDIS_REST_TOKEN` | Redis auth | No |
| `METRICS_TOKEN` | Guards the `/metrics-internal` endpoint | Yes if metrics enabled |

The frontend lives in `frontend/`. Run it with `flutter run` after `flutter pub get`.

---

## API

| Endpoint | Method | Purpose |
|---|---|---|
| `/health` | GET | Liveness check |
| `/` | GET | Service root, returns version |
| `/foods` | GET | Full catalogue with total count |
| `/foods/{id}` | GET | Single food, nutrition, environment, price |
| `/search-foods` | POST | Partial and case-insensitive name search |
| `/calculate-impact` | POST | Basket impact scores |
| `/optimise-basket` | POST | Ranked substitutions with rationales |
| `/supply-pressure` | GET | Grain and category pressure, with `measures_used` and data vintage |
| `/feed-cost-pressure` | GET | Feed cost signal with its own validation record |
| `/get-seasonal-foods` | GET | Seasonal items, filterable by category |
| `/swap-feedback` | POST | Accept and dismiss telemetry |

`/metrics-internal` is not public and requires the `X-Metrics-Token` header.

Empty baskets return 400. Unknown food codes are reported in a `not_found` list rather than failing the request. Malformed payloads return 422.

---

## Data

Three directories, deliberately separated.

**`backend/data/live`** refreshes weekly from AHDB. Stage 2 and the feed cost engine read from here.

**`backend/data/reference`** holds the food knowledge dataset. Every food carries a `footprint_method` flag marking its value as `direct`, `proxy: <source>` or `derived: <recipe>`, so no proxy is undeclared. Composite products derive their footprint from declared QUID label percentages against Poore and Nemecek commodity values, using ingoing raw mass. Assumptions behind each derived value are recorded per row.

**`backend/data/validation`** holds frozen snapshots. These are not refreshed. Published statistics were computed against exactly these files, and refreshing them would silently break that correspondence.

### Data provenance

Source market data is published by the Agriculture and Horticulture Development Board and remains AHDB's. Environmental footprint values derive from Poore and Nemecek (2018). Neither is redistributed by this repository beyond what is required to run and verify the system, and neither should be republished from it.

---

## Validation

`backend/data/validation/feed_lead_lag.md` documents an empirical study of how feed costs propagate to retail prices, reproducible via `feed_lead_lag.py`.

The chain is validated link by link rather than end to end.

| Link | Horizon | Species |
|---|---|---|
| Protein feed cost to farm-gate | 20 to 26 weeks | pork only |
| Farm-gate to retail shelf | 6 to 10 weeks pork, 13 weeks beef | both |

Direct feed-to-retail is not significant, and peaks inside the window the two measured links imply, which is a consistency check the analysis could have failed.

The result is defended on convergence rather than on a single p-value: two independent feed series agree, UK-crushed rapemeal matches imported soyameal so it is not a currency artefact, energy feed shows nothing which is the specificity check, the reverse-direction placebo passes, and the lag matches the pig production cycle. Beef shows no relationship at any lag, which is expected for a largely grass and forage finished system, and is reported rather than dropped.

Caveats are carried in the document. An r of 0.38 explains roughly 15% of variance, which makes this a contributing signal rather than a forecast. A strict Bonferroni threshold across the primary tests would be 0.0028, which neither p-value clears.

`VALIDATED_CATEGORIES` in `feed_cost_pressure.py` is a one-line change per species once a backtest is complete. Poultry and eggs are the obvious next candidates, and their expected lag is much shorter than pork given a six week broiler cycle. That must be measured rather than assumed.

The backtest has been reproduced independently on a separate machine running Python 3.14 and pandas 3.0.5, matching every published figure.

---

## Deployment

The backend auto-deploys from `main` to Render. The iOS client ships through Xcode Cloud to TestFlight.

---

## Versioning

The API version string is returned by `GET /`. Breaking changes to response shape increment the minor version. See commit history for the full record.

---

## Licence

[TO CONFIRM] All rights reserved. AgriESG Limited, company number 16901352.
