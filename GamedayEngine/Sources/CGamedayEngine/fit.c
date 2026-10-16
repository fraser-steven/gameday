#include "gameday.h"
#include <math.h>
#include <stddef.h>

// Floor for anything we're about to divide by, or a parameter we're about to
// produce — guards a team with no home (or away) appearances in the window,
// without needing a special case.
#define GD_EPSILON 1e-9

static int inputs_valid(const int32_t *home_idx, const int32_t *away_idx,
                        const int32_t *home_goals, const int32_t *away_goals,
                        const double *weight, int32_t match_count,
                        int32_t team_count, int32_t max_iterations,
                        double tolerance, gd_league_fit *out) {
    if (out == NULL) return 0;
    if (home_idx == NULL || away_idx == NULL || home_goals == NULL ||
        away_goals == NULL || weight == NULL) return 0;
    if (team_count <= 0 || team_count > GD_MAX_TEAMS) return 0;
    if (match_count <= 0) return 0;
    if (max_iterations <= 0) return 0;
    if (!isfinite(tolerance) || tolerance <= 0.0) return 0;

    for (int32_t m = 0; m < match_count; m++) {
        if (home_idx[m] < 0 || home_idx[m] >= team_count) return 0;
        if (away_idx[m] < 0 || away_idx[m] >= team_count) return 0;
        if (home_goals[m] < 0 || away_goals[m] < 0) return 0;
        if (!isfinite(weight[m]) || weight[m] < 0.0) return 0;
    }
    return 1;
}

/// One IPF sweep updates a vector of `team_count` parameters in place: each
/// `params[i]` becomes `sum(weighted actual) / sum(weighted expected-per-unit-
/// param)`, i.e. the closed-form value that maximises the log-likelihood for
/// that parameter alone, holding every other current parameter fixed. Returns
/// the largest relative change across the vector, for the convergence check.
static double ipf_sweep(double *params, int32_t team_count,
                        const double *numerator, const double *denominator) {
    double max_change = 0.0;
    for (int32_t i = 0; i < team_count; i++) {
        double denom = denominator[i] > GD_EPSILON ? denominator[i] : GD_EPSILON;
        double updated = numerator[i] / denom;
        if (updated < GD_EPSILON) updated = GD_EPSILON;

        double base = params[i] > GD_EPSILON ? params[i] : GD_EPSILON;
        double change = fabs(updated - params[i]) / base;
        if (change > max_change) max_change = change;

        params[i] = updated;
    }
    return max_change;
}

int gd_fit_league(const int32_t *home_idx, const int32_t *away_idx,
                  const int32_t *home_goals, const int32_t *away_goals,
                  const double *weight, int32_t match_count,
                  int32_t team_count, int32_t max_iterations,
                  double tolerance, gd_league_fit *out) {
    if (!inputs_valid(home_idx, away_idx, home_goals, away_goals, weight,
                      match_count, team_count, max_iterations, tolerance, out)) {
        return -1;
    }

    double attack[GD_MAX_TEAMS];
    double defence[GD_MAX_TEAMS];
    for (int32_t i = 0; i < team_count; i++) {
        attack[i] = 1.0;
        defence[i] = 1.0;
    }
    double home_advantage = 1.3; // sane prior; rescaled on the first sweep regardless

    for (int32_t iter = 0; iter < max_iterations; iter++) {
        double max_change = 0.0;

        // attack[i]: goals i actually scored, over goals i was "expected" to
        // score per unit of attack, given everyone's current defence/HA.
        double attack_num[GD_MAX_TEAMS] = {0};
        double attack_den[GD_MAX_TEAMS] = {0};
        for (int32_t m = 0; m < match_count; m++) {
            int32_t h = home_idx[m], a = away_idx[m];
            double w = weight[m];
            attack_num[h] += w * (double)home_goals[m];
            attack_den[h] += w * defence[a] * home_advantage;
            attack_num[a] += w * (double)away_goals[m];
            attack_den[a] += w * defence[h];
        }
        {
            double change = ipf_sweep(attack, team_count, attack_num, attack_den);
            if (change > max_change) max_change = change;
        }

        // defence[i]: goals i actually conceded, over goals i was "expected"
        // to concede per unit of defence, given everyone's current attack/HA.
        // Uses the attack values just updated above (Gauss-Seidel style).
        double defence_num[GD_MAX_TEAMS] = {0};
        double defence_den[GD_MAX_TEAMS] = {0};
        for (int32_t m = 0; m < match_count; m++) {
            int32_t h = home_idx[m], a = away_idx[m];
            double w = weight[m];
            defence_num[h] += w * (double)away_goals[m];
            defence_den[h] += w * attack[a];
            defence_num[a] += w * (double)home_goals[m];
            defence_den[a] += w * attack[h] * home_advantage;
        }
        {
            double change = ipf_sweep(defence, team_count, defence_num, defence_den);
            if (change > max_change) max_change = change;
        }

        // home_advantage: total home goals actually scored league-wide, over
        // total home goals "expected" per unit of home advantage.
        double ha_num = 0.0, ha_den = 0.0;
        for (int32_t m = 0; m < match_count; m++) {
            int32_t h = home_idx[m], a = away_idx[m];
            double w = weight[m];
            ha_num += w * (double)home_goals[m];
            ha_den += w * attack[h] * defence[a];
        }
        {
            double denom = ha_den > GD_EPSILON ? ha_den : GD_EPSILON;
            double updated = ha_num / denom;
            if (updated < GD_EPSILON) updated = GD_EPSILON;
            double base = home_advantage > GD_EPSILON ? home_advantage : GD_EPSILON;
            double change = fabs(updated - home_advantage) / base;
            if (change > max_change) max_change = change;
            home_advantage = updated;
        }

        if (max_change < tolerance) break;
    }

    for (int32_t i = 0; i < team_count; i++) {
        out->attack[i] = attack[i];
        out->defence[i] = defence[i];
    }
    out->home_advantage = home_advantage;
    out->team_count = team_count;
    return 0;
}
