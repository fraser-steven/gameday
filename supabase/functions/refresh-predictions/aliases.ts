// Loose team-name matching. openfootball uses long official names
// ("FC Bayern München", "FC Internazionale Milano"); TheSportsDB fixtures use
// short ones ("Bayern Munich", "Inter Milan"). We match on significant name
// tokens, with a small alias table for cross-language cases the tokens miss.

const DROP_TOKENS = new Set([
  // legal-form / prefix noise
  "fc", "afc", "cf", "cd", "ca", "ac", "as", "ss", "ssc", "us", "sc", "sv", "sg",
  "sd", "rc", "rcd", "rb", "bc", "cfc", "acf", "bv", "vfb", "vfl", "tsg", "fsv",
  "the", "de", "do", "e",
  // descriptive words
  "club", "calcio", "balompie", "futbol", "football", "verein", "and",
]);

/** Two tokens match if equal, or one is a ≥4-char prefix of the other
 *  ("athen" ~ "athens"). */
function tokenMatch(a: string, b: string): boolean {
  if (a === b) return true;
  const [short, long] = a.length <= b.length ? [a, b] : [b, a];
  return short.length >= 4 && long.startsWith(short);
}

// normalized short name (fixture side) -> a token guaranteed to appear in the
// openfootball name (checked before token matching). For cross-language cases
// the token/prefix rules can't catch (München≠Munich, Internazionale≠Inter).
const ALIASES: Record<string, string> = {
  "bayern munich": "bayern",
  "inter milan": "internazionale",
  "inter": "internazionale",
  "ac milan": "milan",
  "cologne": "koln",
};

function tokenize(name: string): string[] {
  return name
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "") // combining diacritical marks
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .filter((t) => t.length > 0 && !DROP_TOKENS.has(t) && !/^\d+$/.test(t));
}

/**
 * Best match for `name` among `candidates`: an alias hint, then exact token-set
 * equality, then the smaller token set being a subset of the larger, then ≥2
 * shared significant tokens. Returns null if nothing qualifies.
 */
export function matchName(name: string, candidates: Iterable<string>): string | null {
  const cands = [...candidates];
  const normalized = name.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-z0-9\s]/g, " ").replace(/\s+/g, " ").trim();

  const aliasToken = ALIASES[normalized];
  if (aliasToken) {
    const hit = cands.find((c) => tokenize(c).includes(aliasToken));
    if (hit) return hit;
  }

  const target = tokenize(name);
  if (target.length === 0) return null;

  let subsetHit: string | null = null;
  let bestOverlap: { name: string; shared: number } | null = null;

  for (const candidate of cands) {
    const tokens = tokenize(candidate);
    if (tokens.length === 0) continue;

    const [small, big] = target.length <= tokens.length ? [target, tokens] : [tokens, target];
    const sharedInSmall = small.filter((t) => big.some((u) => tokenMatch(t, u))).length;

    if (sharedInSmall === small.length) {
      if (small.length === big.length) return candidate; // token-set equality
      subsetHit ??= candidate;
      continue;
    }

    if (sharedInSmall >= 2 && (!bestOverlap || sharedInSmall > bestOverlap.shared)) {
      bestOverlap = { name: candidate, shared: sharedInSmall };
    }
  }

  return subsetHit ?? bestOverlap?.name ?? null;
}
