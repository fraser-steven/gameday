// refresh-predictions
//
// Regenerates the `predictions` table from a Dixon-Coles goal model for the
// Premier League, La Liga, Bundesliga and Serie A (openfootball history).
// Triggered by the app on launch; a 6h staleness guard makes repeat calls no-ops.

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  fetchHistory,
  fetchUpcomingFixtures,
  MODELLED_LEAGUES,
  type Fixture,
} from "./sources.ts";
import {
  buildLeagueModel,
  expectedGoals,
  finalise,
  poissonMarkets,
  type Prediction,
} from "./model.ts";

const STALE_AFTER_MS = 6 * 3_600_000;

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 1. Staleness guard.
  const { data: latest } = await supabase
    .from("predictions")
    .select("generated_at")
    .order("generated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (latest && Date.now() - Date.parse(latest.generated_at) < STALE_AFTER_MS) {
    return json({ status: "fresh", generated_at: latest.generated_at });
  }

  // 2. Per league: fixtures + fitted model, isolated so one failure doesn't sink the run.
  const rows: PredictionRow[] = [];
  const errors: string[] = [];

  for (const league of Object.values(MODELLED_LEAGUES)) {
    try {
      const [fixtures, history] = await Promise.all([
        fetchUpcomingFixtures(league.tsdb),
        fetchHistory(league, errors),
      ]);
      if (history.length < 30) throw new Error(`only ${history.length} history rows`);

      const model = buildLeagueModel(history);
      for (const fixture of fixtures) {
        const lambdas = expectedGoals(model, fixture.homeTeam, fixture.awayTeam);
        if (!lambdas) {
          errors.push(`unmatched: ${fixture.homeTeam} / ${fixture.awayTeam}`);
          continue;
        }
        const probs = poissonMarkets(lambdas.lambdaHome, lambdas.lambdaAway);
        const prediction = finalise(probs, "poisson-dc-v1");
        rows.push(toRow(fixture, prediction));
      }
    } catch (err) {
      errors.push(`league ${league.tsdb}: ${err instanceof Error ? err.message : err}`);
    }
  }

  if (rows.length === 0) {
    return json({ status: "error", errors }, 502);
  }

  // 3. Upsert.
  const generatedAt = new Date().toISOString();
  for (const row of rows) row.generated_at = generatedAt;

  const { error: upsertError } = await supabase
    .from("predictions")
    .upsert(rows, { onConflict: "fixture_id" });
  if (upsertError) return json({ status: "error", errors: [upsertError.message, ...errors] }, 500);

  return json({ status: "updated", count: rows.length, errors });
});

// ---------------------------------------------------------------------------

interface PredictionRow {
  fixture_id: string;
  league_id: string;
  season: string | null;
  home_team: string;
  away_team: string;
  kickoff: string;
  prob_home: number;
  prob_draw: number;
  prob_away: number;
  prob_btts_yes: number;
  pick: string;
  confidence: string;
  rationale: string | null;
  model_version: string;
  generated_at: string;
}

function toRow(fixture: Fixture, p: Prediction): PredictionRow {
  return {
    fixture_id: fixture.id,
    league_id: fixture.leagueId,
    season: fixture.season,
    home_team: fixture.homeTeam,
    away_team: fixture.awayTeam,
    kickoff: fixture.kickoff,
    prob_home: round3(p.home),
    prob_draw: round3(p.draw),
    prob_away: round3(p.away),
    prob_btts_yes: round3(p.bttsYes),
    pick: p.pick,
    confidence: p.confidence,
    rationale: null,
    model_version: p.modelVersion,
    generated_at: "",
  };
}

const round3 = (x: number) => Math.round(x * 1000) / 1000;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
