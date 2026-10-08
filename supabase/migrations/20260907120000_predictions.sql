-- GameDay AI — match predictions cache
--
-- One row per fixture. Written by the nightly prediction job (penaltyblog
-- Dixon-Coles for the numbers, Claude for the rationale) using the service-role
-- key. Read by the iOS app with the anon key.
--
-- The app already gets fixtures from TheSportsDB at runtime; this table is
-- joined to them client-side on `fixture_id` (TheSportsDB `idEvent`). Core
-- markets (1X2, BTTS) are typed columns; anything experimental goes in
-- `extra_markets` so new markets don't need a migration or an app rebuild.

create table if not exists public.predictions (
    fixture_id      text primary key,                       -- TheSportsDB idEvent
    league_id       text        not null,                   -- TheSportsDB idLeague
    season          text,
    home_team       text        not null,
    away_team       text        not null,
    kickoff         timestamptz not null,

    -- 1X2 (match result)
    prob_home       real        not null check (prob_home between 0 and 1),
    prob_draw       real        not null check (prob_draw between 0 and 1),
    prob_away       real        not null check (prob_away between 0 and 1),

    -- Both teams to score
    prob_btts_yes   real        not null check (prob_btts_yes between 0 and 1),

    -- Presentation (computed by the job so the app stays dumb)
    pick            text        not null check (pick in ('home', 'draw', 'away')),
    confidence      text        not null check (confidence in ('low', 'medium', 'high')),
    rationale       text,

    -- Room to grow: over/under, correct score, etc. -> { "over_2_5": 0.61, ... }
    extra_markets   jsonb       not null default '{}'::jsonb,

    -- Provenance
    model_version   text        not null,
    generated_at    timestamptz not null default now(),

    constraint predictions_1x2_sums_to_one
        check (prob_home + prob_draw + prob_away between 0.97 and 1.03)
);

create index if not exists predictions_kickoff_idx  on public.predictions (kickoff);
create index if not exists predictions_league_idx   on public.predictions (league_id, kickoff);

comment on table public.predictions is
    'Per-fixture match predictions. Upserted by the nightly job; public read-only.';

-- Row Level Security: anyone may read, nobody may write through the API.
-- The nightly job uses the service-role key, which bypasses RLS.
alter table public.predictions enable row level security;

drop policy if exists "predictions are publicly readable" on public.predictions;
create policy "predictions are publicly readable"
    on public.predictions
    for select
    using (true);
