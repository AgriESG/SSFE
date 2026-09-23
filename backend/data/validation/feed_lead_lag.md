# Feed cost as a leading indicator of UK farm-gate prices

**Status:** link 1 validated for pork only. Link 2 validated for pork and beef.
Poultry, dairy and eggs untested throughout.
**Date:** 1 August 2026
**Reproduce:** `python feed_lead_lag.py --data <dir>` with the three AHDB files below.

---

## What this tests

AgriESG's Supply Pressure Index derives supply conditions from AHDB annual
balance sheets. Annual data updates once a year and says nothing about
conditions between publications.

This tests a second, faster signal: whether **protein feed cost** carries
information about **farm-gate livestock prices** ahead of time, and if so, at
what horizon.

The mechanism being tested is specific. Protein feed is the binding input cost
in intensive livestock production. When it rises, producers adjust breeding and
retention. Those decisions reach the slaughter market only at the speed the
animals grow. So the horizon should match the production cycle, and should
differ by species.

That is a falsifiable prediction, not a story fitted after the fact, and most
of the value here is that it can fail in identifiable ways.

## Data

| File | Source | Coverage | Role |
|---|---|---|---|
| `UK_feed_ingredient_prices.xlsx` | AHDB | weekly, 2015-01-30 to 2026-07-24 | driver |
| `All_historic_pig_data.xlsx` | AHDB | weekly, 2014-04 to 2026-07 | target |
| `Weekly_deadweight_cattle_prices.xlsx` | AHDB | weekly, 2019-01 to 2026-07 | species check |
| `Supermarket_red_meat_prices.xlsx` | AHDB | weekly, 2019-09 to 2026-08 | retail target |

Feed quotes carry three delivery months per date; the nearest is used as the
spot-equivalent level throughout.

## Method

Both series are converted to 13-week log changes and correlated at a range of
lags: driver at time *t* against target at *t + lag*.

**Overlapping windows are not used for the reported figures.** Consecutive
13-week changes share 12 weeks of data and are strongly autocorrelated, which
inflates apparent significance badly. Every r and p below comes from
**non-overlapping quarterly observations**, thinned to every 13th week *after*
alignment. Thinning before alignment silently discards most of the sample and
was an error in an earlier draft of this analysis.

## Result: pork

Protein feed cost leads GB deadweight pig price (SPP, EU spec).

| Feed input | Origin | Peak lag | r | p | n |
|---|---|---|---|---|---|
| Soyameal, Brazilian 48% | imported | 20 weeks | +0.381 | 0.012 | 43 |
| Rapemeal 34% | UK-crushed | 20 weeks | +0.384 | 0.019 | 37 |
| Pelleted wheat feed | UK | 36 weeks | +0.136 | 0.475 | 30 |

Correlation for soyameal is near zero at 8 weeks (r = 0.117, p = 0.448), rises
to a peak at 20 weeks, holds at 26 weeks (r = 0.353, p = 0.022), and decays
after 30. The peak is a **plateau across roughly five to six months**, not a
point estimate. It shifts between 20 and 26 weeks depending on gap-filling
choices, so it should always be reported as a range.

Three things support the result beyond the correlation itself:

**Independent corroboration.** UK-crushed rapemeal produces the same lag and
effectively the same strength as imported soyameal. The relationship is
therefore not an artefact of import costs, shipping, or sterling.

**Specificity.** Pelleted wheat feed shows nothing at any lag. Protein feed is
the constrained, expensive input in pig rations; energy feed is cheap and
substitutable. Signal appears in the input that binds and not in the one that
doesn't, which is what the mechanism predicts.

**Placebo.** Reversing the direction gives nothing (r = −0.079 at 8 weeks,
r = 0.005 at 26 weeks). Pig prices do not lead feed prices, so this is not
generic co-movement.

**The lag matches the biology.** UK pig production runs roughly 16 weeks
gestation plus around 24 weeks rearing to slaughter. A feed cost shock cannot
reach the slaughter market faster than that. Twenty to twenty-six weeks is
where first principles say the effect should land.

## Result: beef — no evidence

| Series | Best lag | r | p | n |
|---|---|---|---|---|
| Steers, England & Wales | 91 wks | −0.301 | 0.153 | 24 |
| Cull cows, dairy herd | 91 wks | −0.424 | 0.039 | 24 |
| Young bulls | 91 wks | −0.323 | 0.123 | 24 |

This is the expected result. UK beef is largely grass and forage finished, so
purchased protein concentrate is a much smaller share of production cost than
in pig production. The mechanism is weaker, and it does not show.

**On the cull cow figure.** It crosses p < 0.05, and it should not be reported
as a finding. Thirty lag-species combinations were tested across the cattle
series; at a 5% threshold, one or two spurious results are expected by chance
alone. It is also **negatively** signed, meaning higher feed cost would imply
lower cow prices 21 months later, for which there is no mechanism. A single
uncorrected p-value among thirty tests, pointing the wrong way, with no
mechanism, is noise. It is recorded here rather than dropped because selective
reporting of tests that worked is exactly what makes a result unreliable.


## Result: farm-gate to retail (link 2)

Added 2 August 2026, using AHDB Supermarket red meat prices (weekly, Sep 2019
to Aug 2026, pence per kg). Retail indices are the mean of all cuts for each
species, rebased to 100 at the start of the series.

**Pork: GB deadweight price leads supermarket pork retail**

| Lag | r | p |
|---|---|---|
| 4 wks | +0.375 | 0.054 |
| 6 wks | +0.412 | 0.033 |
| **8 wks** | **+0.432** | **0.024** |
| 10 wks | +0.405 | 0.036 |
| 13 wks | +0.319 | 0.104 |
| 20 wks | −0.073 | 0.716 |

**Beef: the same link, stronger**

| Lag | r | p |
|---|---|---|
| 6 wks | +0.502 | 0.008 |
| 8 wks | +0.523 | 0.005 |
| 10 wks | +0.544 | 0.003 |
| **13 wks** | **+0.598** | **0.001** |
| 17 wks | +0.508 | 0.007 |

n = 27 non-overlapping quarterly observations throughout.

The beef result is the only figure in this document that survives a strict
Bonferroni correction (nine lags tested, threshold 0.0056; p = 0.001).

**Link 2 generalises where link 1 does not, and that is mechanistically
coherent.** Feed cost reaches farm-gate prices only where purchased feed is a
large share of production cost, which is why pork works and beef does not.
Farm-gate prices reach the shelf through retailer margin and repricing
behaviour, which applies to any meat regardless of how it was reared. So a
species-specific link 1 sitting on top of a general link 2 is what the
mechanism predicts, not an inconsistency.

## The full chain, and an honest null

Testing feed cost directly against retail pork:

| Lag | r | p |
|---|---|---|
| 26 wks | +0.123 | 0.558 |
| **30 wks** | **+0.235** | **0.259** |
| 39 wks | +0.021 | 0.922 |

**Not significant.** The direct feed-to-shelf relationship does not hold up.

But the peak sits at 30 weeks, and the two measured links predict 28 to 34
weeks (20-26 for link 1, plus 8 for link 2). That the direct estimate lands
inside the window implied by the two separate measurements is a consistency
check the analysis could have failed and did not.

Signal attenuating across two noisy links is expected. The correct reading is
that the chain is best described link by link, with the composite treated as
directionally consistent rather than independently established.

## Reconciling the 6-to-8-week claim

Earlier AgriESG materials state that the index anticipates price movements
6 to 8 weeks ahead. That figure is **not supported for feed to farm-gate**,
where r = 0.117 and p = 0.448 at 8 weeks.

It **is supported for farm-gate to retail**, where 6, 8 and 10 weeks are the
significant window for pork and the peak sits at 8 weeks.

So the horizon was attached to the wrong link rather than being wrong. Corrected
statement of the model:

| Link | Horizon | Species | Evidence |
|---|---|---|---|
| Protein feed cost to farm-gate | 20-26 weeks | pork only | r = 0.38, two independent feed series, placebo and specificity checks pass |
| Farm-gate to retail shelf | 6-10 weeks (pork), 13 weeks (beef) | both tested | r = 0.43 pork, r = 0.60 beef |

## Multiple comparisons — read this before quoting the p-values

Eighteen tests were run for the primary result (six lags across three feed
inputs). A strict Bonferroni correction would set the threshold at 0.0028, and
**neither the soyameal nor the rapemeal p-value clears it.**

Bonferroni is very conservative here, since adjacent lags are highly correlated
and are nowhere near independent tests. But the honest position is that the
pork result should not be defended on a single p-value.

What it should be defended on is convergence: two independent feed series
agreeing on both lag and magnitude, a horizon predicted in advance by the
production cycle, a passing placebo, and a passing specificity check. Each
alone is weak. Together they are hard to produce by chance.

The cull cow result has none of that. That is the difference between the two,
and it is a more useful test of a finding than a threshold.

## Limitations

**Effect size is modest.** r = 0.38 explains about 15% of variance. Real, not
strong. This is a contributing signal, not a forecast.

**Retail link now tested, chain not established end to end.** Link 2 is
measured and significant for both pork and beef. The direct feed-to-retail
relationship is not significant, so the chain should be described link by link
rather than as a single validated feed-to-shelf predictor.

**Retail prices are survey-based.** AHDB collects supermarket shelf prices,
which include promotional pricing. Short-term noise from promotions is baked
into the retail series and is not separated out here.

**Cattle power is low.** Cattle data begins January 2019 against feed from
2015, giving seven overlapping years and n of 23 to 29 per test. This is *no
evidence of an effect*, not evidence of no effect. Cull cows in particular came
closest at a plausible 20-week lag in an earlier specification, and would be
worth retesting on a longer series.

**Rapemeal quotes end 16 January 2026.** The series appears discontinued, so it
serves as historical corroboration and cannot carry a live signal. Live
implementation runs on soyameal alone.

**Untested species.** Poultry and eggs are the most likely remaining
candidates: intensive, feed-dominated, short cycle. Broilers reach slaughter in
about six weeks, so the expected lag is much shorter than pork. This has not
been tested and must not be assumed.

## What this changes in the product

`engines/feed_cost_pressure.py` implements this as a second pressure component
alongside the balance-sheet index. It returns `None` for every category except
pork, so an untested species yields no signal rather than a plausible-looking
number.

Current reading, 25 July 2026: soyameal at £356/t, 13-week change −2.2%, which
sits at the 45th percentile of its 2015-2026 distribution. Feed cost pressure
for pork 0.454, stability 0.546.

## Correction to prior documentation

Earlier materials state a single 6-to-8-week horizon for the whole model. That
conflates two links with different speeds.

The corrected two-link statement is in "Reconciling the 6-to-8-week claim"
above. Documents quoting a single horizon should be updated to state which link
they mean.
