# Supabase — GameDay AI

Project ref: `bnvkdexyzgficwepzjss`

## Schema

| Table | Purpose |
|---|---|
| `predictions` | One row per fixture: 1X2 + BTTS probabilities, a pick, a confidence band. Written by the `refresh-predictions` function; read by the iOS app. Keyed by `fixture_id` = TheSportsDB `idEvent`. |

`rationale` is still a column (nullable) but nothing writes it — the Claude
rationale step was dropped (see below). It's safe to leave in the schema in
case it comes back.

## Edge Function: `refresh-predictions`

Regenerates `predictions` from a Dixon-Coles goal model for **Premier League,
La Liga, Bundesliga and Serie A**, fitted on the last 3 seasons of
[openfootball/football.json](https://github.com/openfootball/football.json)
results (time-weighted). No Champions League (cross-league goal modelling
doesn't work without a shared ratings source, and the one we tried — Club Elo —
is unreliable; see `data-source-pivot` memory for the history).

Called by the app on launch. A 6-hour staleness guard makes repeat calls no-ops
(`{"status":"fresh"}`). A healthy run returns `{"status":"updated","count":~60,"errors":[]}`.

**No Claude call** — the one-line rationale text was dropped because it needs
separate Anthropic API credits (distinct from a Claude Code/claude.ai
subscription — see `rationale.ts` in git history if reviving it, or the
`Co-Authored-By` days of this file for the full story). `prediction.rationale`
is simply always `null`; the app already renders that gracefully.

## Setup

### 1. Apply the migration

Dashboard → **SQL Editor** → paste `migrations/20260907120000_predictions.sql` → Run.
(Or `supabase db push` with the CLI.)

### 2. Deploy the function

```bash
brew install supabase/tap/supabase        # if not installed
supabase login
supabase link --project-ref bnvkdexyzgficwepzjss
supabase functions deploy refresh-predictions --no-verify-jwt
```

`--no-verify-jwt` because the app authenticates with the new-style
`sb_publishable_…` key (not a JWT). The function only computes over public data
and the 6-hour staleness guard caps how often it does real work, so an
unauthenticated trigger is low-risk.

### 3. Smoke-test

```bash
curl -X POST 'https://bnvkdexyzgficwepzjss.supabase.co/functions/v1/refresh-predictions' \
  -H "Authorization: Bearer <ANON_KEY>"
# -> {"status":"updated","count":~60,"errors":[]}
# run again within 6h -> {"status":"fresh", ...}
```

Then check Dashboard → Table editor → `predictions`.

## Keys

- **iOS app**: project URL + publishable key (`SUPABASE_ANON_KEY` env var in the
  run scheme, or `SupabaseConfig.fallbackAnonKey`). RLS allows `select` only.
- **Function → DB**: `service_role` key, injected by the platform automatically.

## Local development

```bash
supabase functions serve refresh-predictions
```
