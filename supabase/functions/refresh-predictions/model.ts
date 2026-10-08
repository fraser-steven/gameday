// Prediction maths: a Dixon-Coles-style Poisson goal model (1X2 + BTTS) fitted
// from weighted historical results.

import { matchName } from "./aliases.ts";
import type { HistMatch } from "./sources.ts";

export interface MarketProbs {
  home: number;
  draw: number;
  away: number;
  bttsYes: number;
}

export interface Prediction extends MarketProbs {
  pick: "home" | "draw" | "away";
  confidence: "low" | "medium" | "high";
  modelVersion: string;
}

const MAX_GOALS = 10;
const TIME_DECAY = 0.0018; // per day; ~one-season half-life (Dixon-Coles xi)
const RHO = -0.13; // low-score dependency
const PRIOR_MATCHES = 4; // shrink sparse teams toward league average

// ---------------------------------------------------------------------------
// Poisson / Dixon-Coles
// ---------------------------------------------------------------------------

interface TeamRates {
  homeScored: number;
  homeConceded: number;
  awayScored: number;
  awayConceded: number;
}

interface LeagueModel {
  leagueHomeGoals: number;
  leagueAwayGoals: number;
  teams: Map<string, TeamRates>;
  names: string[];
}

/** Build attack/defence rates for every team from weighted history. */
export function buildLeagueModel(history: HistMatch[], asOf = new Date()): LeagueModel {
  const acc = new Map<string, {
    hsG: number; hsW: number; hcG: number;
    asG: number; asW: number; acG: number;
  }>();
  const get = (t: string) => {
    let v = acc.get(t);
    if (!v) acc.set(t, (v = { hsG: 0, hsW: 0, hcG: 0, asG: 0, asW: 0, acG: 0 }));
    return v;
  };

  let leagueHomeW = 0, leagueAwayW = 0, totalW = 0;
  for (const m of history) {
    const ageDays = (asOf.getTime() - m.date.getTime()) / 86_400_000;
    if (ageDays < 0) continue;
    const w = Math.exp(-TIME_DECAY * ageDays);

    const h = get(m.home);
    h.hsG += w * m.homeGoals; h.hsW += w; h.hcG += w * m.awayGoals;
    const a = get(m.away);
    a.asG += w * m.awayGoals; a.asW += w; a.acG += w * m.homeGoals;

    leagueHomeW += w * m.homeGoals;
    leagueAwayW += w * m.awayGoals;
    totalW += w;
  }

  const leagueHomeGoals = totalW > 0 ? leagueHomeW / totalW : 1.45;
  const leagueAwayGoals = totalW > 0 ? leagueAwayW / totalW : 1.15;

  const teams = new Map<string, TeamRates>();
  for (const [name, v] of acc) {
    teams.set(name, {
      homeScored: shrink(v.hsG, v.hsW, leagueHomeGoals),
      homeConceded: shrink(v.hcG, v.hsW, leagueAwayGoals),
      awayScored: shrink(v.asG, v.asW, leagueAwayGoals),
      awayConceded: shrink(v.acG, v.asW, leagueHomeGoals),
    });
  }

  return { leagueHomeGoals, leagueAwayGoals, teams, names: [...teams.keys()] };
}

/** Weighted mean of `sumGoals / weight`, pulled toward `leagueMean` when sparse. */
function shrink(sumGoals: number, weight: number, leagueMean: number): number {
  if (weight <= 0) return leagueMean;
  const observed = sumGoals / weight;
  const k = weight / (weight + PRIOR_MATCHES);
  return k * observed + (1 - k) * leagueMean;
}

/** Resolve a (possibly short) team name to the exact key used in the model. */
function resolveTeam(model: LeagueModel, team: string): string | null {
  if (model.teams.has(team)) return team;
  return matchName(team, model.names);
}

function lookup(model: LeagueModel, team: string): TeamRates | null {
  const key = resolveTeam(model, team);
  return key ? model.teams.get(key)! : null;
}

/** Expected goals for a fixture, or null if either team is unknown to the model. */
export function expectedGoals(
  model: LeagueModel,
  homeTeam: string,
  awayTeam: string,
): { lambdaHome: number; lambdaAway: number } | null {
  const home = lookup(model, homeTeam);
  const away = lookup(model, awayTeam);
  if (!home || !away) return null;

  const attackStrengthHome = home.homeScored / model.leagueHomeGoals;
  const defenceWeaknessAway = away.awayConceded / model.leagueHomeGoals;
  const attackStrengthAway = away.awayScored / model.leagueAwayGoals;
  const defenceWeaknessHome = home.homeConceded / model.leagueAwayGoals;

  return {
    lambdaHome: clamp(model.leagueHomeGoals * attackStrengthHome * defenceWeaknessAway, 0.15, 6),
    lambdaAway: clamp(model.leagueAwayGoals * attackStrengthAway * defenceWeaknessHome, 0.15, 6),
  };
}

/** 1X2 + BTTS from a Dixon-Coles-adjusted Poisson score matrix. */
export function poissonMarkets(lambdaHome: number, lambdaAway: number): MarketProbs {
  const homePmf = poissonPmf(lambdaHome, MAX_GOALS);
  const awayPmf = poissonPmf(lambdaAway, MAX_GOALS);

  let home = 0, draw = 0, away = 0, bttsYes = 0, total = 0;
  for (let i = 0; i <= MAX_GOALS; i++) {
    for (let j = 0; j <= MAX_GOALS; j++) {
      let p = homePmf[i] * awayPmf[j];
      if (i <= 1 && j <= 1) p *= dixonColesTau(i, j, lambdaHome, lambdaAway);
      if (p <= 0) continue;
      total += p;
      if (i > j) home += p;
      else if (i === j) draw += p;
      else away += p;
      if (i >= 1 && j >= 1) bttsYes += p;
    }
  }
  return { home: home / total, draw: draw / total, away: away / total, bttsYes: bttsYes / total };
}

function dixonColesTau(i: number, j: number, lh: number, la: number): number {
  if (i === 0 && j === 0) return 1 - lh * la * RHO;
  if (i === 0 && j === 1) return 1 + lh * RHO;
  if (i === 1 && j === 0) return 1 + la * RHO;
  if (i === 1 && j === 1) return 1 - RHO;
  return 1;
}

function poissonPmf(lambda: number, maxK: number): number[] {
  const pmf = [Math.exp(-lambda)];
  for (let k = 1; k <= maxK; k++) pmf[k] = pmf[k - 1] * lambda / k;
  return pmf;
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

export function finalise(probs: MarketProbs, modelVersion: string): Prediction {
  const entries: Array<["home" | "draw" | "away", number]> = [
    ["home", probs.home], ["draw", probs.draw], ["away", probs.away],
  ];
  entries.sort((a, b) => b[1] - a[1]);
  const [pick, top] = entries[0];
  const confidence: "low" | "medium" | "high" = top >= 0.55 ? "high" : top >= 0.4 ? "medium" : "low";

  return { ...probs, pick, confidence, modelVersion };
}

const clamp = (x: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, x));
