# GameDay AI

An iOS app that shows this week's football fixtures across four leagues and
generates a prediction for each match — entirely on-device.

## What it does

- **Home** — this week's fixtures (Premier League, La Liga, Bundesliga, Serie
  A), grouped by day, pulled live from [TheSportsDB](https://www.thesportsdb.com).
  Tap any fixture for a "Match Insight" sheet: a win/draw/loss pick with a
  confidence level, the full probability split, and a both-teams-to-score read.
- **Tips** — the five single highest-probability picks across all of this
  week's fixtures (win picks and BTTS picks pooled together, ranked by how
  confident the model is). A step toward accumulator suggestions next.

## How a prediction is made

No backend, no server call at prediction time — everything below runs on the
device.

1. **History.** For each league, the app pulls roughly three seasons of match
   results from [openfootball](https://github.com/openfootball/football.json),
   a free, open dataset hosted on GitHub.
2. **Fitting.** That history is fed into `GamedayEngine`, a small C library,
   which fits a **Dixon-Coles model** — the standard statistical approach for
   football prediction. It derives, per team, an attack strength and a defence
   strength (how many goals they tend to score/concede relative to the league
   average) plus a shared home-advantage factor.

   The fitting method is **iterative proportional fitting**: each team's
   numbers are repeatedly rescaled so its predicted scoring matches its actual
   record, given everyone else's current numbers, until the values converge.
   This is the closed-form maximum-likelihood solution for this class of
   model — not an approximation.
3. **Caching.** The fitted numbers (a handful of floats per team) are saved to
   a small file on-device. Refitting only happens if the cache is more than
   24 hours old.
4. **Prediction.** For an actual fixture, the two teams' attack/defence values
   combine into expected goals for each side. The C engine turns that into a
   full probability distribution over scorelines — a Poisson model, with the
   standard Dixon-Coles correction for low-scoring results (0-0, 1-1, etc.
   being more common than plain Poisson predicts). Summing that distribution
   gives win/draw/loss and both-teams-to-score probabilities.

## Architecture

| Piece | What it is |
|---|---|
| `gameday/` | The SwiftUI app: views, and services for fetching fixtures (TheSportsDB) and orchestrating predictions. |
| `GamedayEngine/` | A local Swift package. `CGamedayEngine` is the C core doing the statistics; a thin Swift wrapper sits on top. Both have their own unit tests — reference-value checks for the probability math, synthetic-league checks for the fitting. |
| `supabase/` | Legacy — an earlier version ran the same statistics on a Supabase Edge Function. Superseded by the on-device C version, which removes the backend dependency entirely (and was a deliberate exercise in writing the numerical fitting code in C). No longer called by the app. |

## Known limitation

The live fixture list depends on TheSportsDB's free API, which occasionally
rate-limits or has outages. When that happens the app shows "no fixtures"
rather than fake data, and recovers automatically once TheSportsDB is
reachable again. Predictions themselves don't depend on it once a league has
been fitted — only the "which fixtures to show" step does.
