// External data:
//  - upcoming fixtures: TheSportsDB (eventsnextleague + eventsround around the
//    current round)
//  - historical results for the goal model: openfootball/football.json on
//    GitHub — one request per season, hosted on raw.githubusercontent.com so
//    there is no WAF, no rate limit, no User-Agent games.
//
// (football-data.co.uk was tried first but is blocked from the Supabase egress;
// bulk TheSportsDB `eventsround` fetching hits HTTP 429 after ~30 calls.)
// A small TheSportsDB `eventsround` fallback fills the current season if
// openfootball is unreachable.

const TSDB_KEY = Deno.env.get("THESPORTSDB_KEY") ?? "123";
const TSDB_BASE = `https://www.thesportsdb.com/api/v1/json/${TSDB_KEY}`;
const OPENFOOTBALL_BASE =
  "https://raw.githubusercontent.com/openfootball/football.json/master";

export const MODELLED_LEAGUES = {
  premierLeague: { tsdb: "4328", openfootball: "en.1" },
  laLiga: { tsdb: "4335", openfootball: "es.1" },
  bundesliga: { tsdb: "4331", openfootball: "de.1" },
  serieA: { tsdb: "4332", openfootball: "it.1" },
} as const;

export interface Fixture {
  id: string;
  leagueId: string;
  season: string | null;
  homeTeam: string;
  awayTeam: string;
  kickoff: string; // ISO 8601
}

export interface HistMatch {
  date: Date;
  home: string;
  away: string;
  homeGoals: number;
  awayGoals: number;
}

interface TSDBEvent {
  idEvent?: string;
  idLeague?: string;
  strSeason?: string;
  strHomeTeam?: string;
  strAwayTeam?: string;
  strTimestamp?: string;
  dateEvent?: string;
  strTime?: string;
  intRound?: string;
  intHomeScore?: string | null;
  intAwayScore?: string | null;
}

async function tsdbEvents(path: string, params: Record<string, string>): Promise<TSDBEvent[]> {
  const url = new URL(`${TSDB_BASE}/${path}`);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`TheSportsDB ${path} -> ${res.status}`);
  const json = await res.json();
  return (json.events as TSDBEvent[] | null) ?? [];
}

function eventDate(e: TSDBEvent): Date | null {
  if (e.strTimestamp) {
    const iso = e.strTimestamp.includes("T") ? e.strTimestamp : e.strTimestamp.replace(" ", "T");
    const d = new Date(iso.endsWith("Z") || iso.includes("+") ? iso : `${iso}Z`);
    if (!isNaN(d.getTime())) return d;
  }
  if (e.dateEvent) {
    const d = new Date(`${e.dateEvent}T${e.strTime ?? "00:00:00"}Z`);
    if (!isNaN(d.getTime())) return d;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

function toFixture(e: TSDBEvent): Fixture | null {
  const date = eventDate(e);
  if (!e.idEvent || !e.strHomeTeam || !e.strAwayTeam || !date) return null;
  return {
    id: e.idEvent,
    leagueId: e.idLeague ?? "",
    season: e.strSeason ?? null,
    homeTeam: e.strHomeTeam,
    awayTeam: e.strAwayTeam,
    kickoff: date.toISOString(),
  };
}

/** Fixtures for one league kicking off within the next `days` days. */
export async function fetchUpcomingFixtures(leagueTsdbId: string, days = 10): Promise<Fixture[]> {
  const next = await tsdbEvents("eventsnextleague.php", { id: leagueTsdbId });
  const pivot = Math.min(
    ...next.map((e) => Number(e.intRound)).filter((n) => Number.isFinite(n) && n > 0),
    Infinity,
  );

  const season = next.find((e) => e.strSeason)?.strSeason;
  const rounds: TSDBEvent[] = [];
  if (Number.isFinite(pivot) && season) {
    for (const r of [pivot, pivot + 1]) {
      rounds.push(...await tsdbEvents("eventsround.php", { id: leagueTsdbId, r: String(r), s: season }));
    }
  }

  const cutoff = Date.now() + days * 86_400_000;
  const seen = new Set<string>();
  const fixtures: Fixture[] = [];
  for (const raw of [...next, ...rounds]) {
    const fixture = toFixture(raw);
    if (!fixture || seen.has(fixture.id)) continue;
    const ts = Date.parse(fixture.kickoff);
    if (ts < Date.now() - 3 * 3_600_000 || ts > cutoff) continue;
    seen.add(fixture.id);
    fixtures.push(fixture);
  }
  return fixtures.sort((a, b) => a.kickoff.localeCompare(b.kickoff));
}

// ---------------------------------------------------------------------------
// History
// ---------------------------------------------------------------------------

interface OpenfootballMatch {
  date?: string;
  time?: string;
  team1?: string;
  team2?: string;
  // openfootball is inconsistent: usually { ft: [h, a] }, sometimes a bare [h, a].
  score?: { ft?: [number, number] } | [number, number];
}

/** Full-time goals from either openfootball `score` shape, or null if unplayed. */
function fullTimeGoals(score: OpenfootballMatch["score"]): [number, number] | null {
  const ft = Array.isArray(score) ? score : score?.ft;
  if (!Array.isArray(ft) || ft.length !== 2) return null;
  const [h, a] = [Number(ft[0]), Number(ft[1])];
  return Number.isFinite(h) && Number.isFinite(a) ? [h, a] : null;
}

/** openfootball season folders for "now" and the `count - 1` seasons before it. */
export function recentSeasonFolders(count = 3, now = new Date()): string[] {
  const startYear = now.getUTCMonth() >= 6 ? now.getUTCFullYear() : now.getUTCFullYear() - 1;
  return Array.from({ length: count }, (_, back) => {
    const y = startYear - back;
    return `${y}-${String((y + 1) % 100).padStart(2, "0")}`;
  });
}

/** Finished results for one openfootball league file, or [] (with a diagnostic). */
export async function fetchOpenfootballSeason(
  season: string,
  code: string,
  errors: string[],
): Promise<HistMatch[]> {
  const url = `${OPENFOOTBALL_BASE}/${season}/${code}.json`;
  try {
    const res = await fetch(url);
    if (!res.ok) {
      if (res.status !== 404) errors.push(`openfootball ${season}/${code} -> ${res.status}`);
      return [];
    }
    const data = await res.json() as { matches?: OpenfootballMatch[] };
    return parseOpenfootball(data.matches ?? []);
  } catch (err) {
    errors.push(`openfootball ${season}/${code} -> ${err instanceof Error ? err.message : err}`);
    return [];
  }
}

/**
 * Historical results for a league from openfootball. On a thin result, tops up
 * with the current TheSportsDB season. `errors` collects diagnostics.
 */
export async function fetchHistory(
  league: { tsdb: string; openfootball: string },
  errors: string[],
): Promise<HistMatch[]> {
  const out: HistMatch[] = [];
  for (const season of recentSeasonFolders()) {
    out.push(...await fetchOpenfootballSeason(season, league.openfootball, errors));
  }

  if (out.length < 50) {
    errors.push(`openfootball thin for ${league.openfootball} (${out.length} rows); topping up from TheSportsDB`);
    out.push(...await currentSeasonFromTSDB(league.tsdb, errors));
  }
  return out;
}

function parseOpenfootball(matches: OpenfootballMatch[]): HistMatch[] {
  const rows: HistMatch[] = [];
  for (const m of matches) {
    if (!m.date || !m.team1 || !m.team2) continue;
    const goals = fullTimeGoals(m.score);
    if (!goals) continue;
    const date = new Date(`${m.date}T${m.time || "12:00"}:00Z`);
    if (isNaN(date.getTime())) continue;
    rows.push({ date, home: m.team1, away: m.team2, homeGoals: goals[0], awayGoals: goals[1] });
  }
  return rows;
}

function finishedMatch(e: TSDBEvent): HistMatch | null {
  const date = eventDate(e);
  const hg = Number(e.intHomeScore);
  const ag = Number(e.intAwayScore);
  if (
    !date || !e.strHomeTeam || !e.strAwayTeam ||
    e.intHomeScore == null || e.intAwayScore == null ||
    !Number.isFinite(hg) || !Number.isFinite(ag)
  ) return null;
  return { date, home: e.strHomeTeam, away: e.strAwayTeam, homeGoals: hg, awayGoals: ag };
}

/** Finished results from the current TheSportsDB season (rounds 1..pivot). Small
 *  and safe — well under the rate-limit threshold. */
async function currentSeasonFromTSDB(leagueTsdbId: string, errors: string[]): Promise<HistMatch[]> {
  try {
    const next = await tsdbEvents("eventsnextleague.php", { id: leagueTsdbId });
    const season = next.find((e) => e.strSeason)?.strSeason;
    const pivot = Math.min(
      ...next.map((e) => Number(e.intRound)).filter((n) => Number.isFinite(n) && n > 0),
      Infinity,
    );
    if (!season || !Number.isFinite(pivot)) return [];

    const out: HistMatch[] = [];
    for (let round = 1; round <= pivot; round++) {
      const events = await tsdbEvents("eventsround.php", { id: leagueTsdbId, r: String(round), s: season });
      out.push(...events.map(finishedMatch).filter((m): m is HistMatch => m !== null));
    }
    return out;
  } catch (err) {
    errors.push(`TheSportsDB history fallback -> ${err instanceof Error ? err.message : err}`);
    return [];
  }
}
