#ifndef GAMEDAY_H
#define GAMEDAY_H

#include <stdint.h>

#define GD_MAX_GOALS 10
#define GD_MAX_TEAMS 64

typedef struct {
    double home;
    double draw;
    double away;
    double btts_yes;
} gd_market_probs;

/// Fills `out` with 1X2 + BTTS probabilities from a Dixon-Coles-adjusted
/// Poisson score matrix. Returns 0 on success, -1 on invalid input.
int gd_poisson_markets(double lambda_home, double lambda_away,
                       double rho, gd_market_probs *out);

typedef struct {
    double attack[GD_MAX_TEAMS];
    double defence[GD_MAX_TEAMS];
    double home_advantage;
    int32_t team_count;
} gd_league_fit;

/// Fits per-team attack/defence and a shared home-advantage multiplier from
/// weighted historical results, via iterative proportional fitting (the
/// closed-form MLE procedure for this Poisson log-linear model):
/// `lambda_home = attack[home] * defence[away] * home_advantage`,
/// `lambda_away = attack[away] * defence[home]`.
///
/// Note the sign of `defence`: it's a *concession* multiplier, not a strength
/// score — a strong defence has a LOW value (it shrinks opponents' expected
/// goals), a weak defence a HIGH one. Same convention as `attack`, which is a
/// scoring multiplier (high = strong).
///
/// `home_idx`/`away_idx` are team indices in [0, team_count); `home_goals`/
/// `away_goals` the final score; `weight` a per-match recency weight (e.g.
/// exponential time decay) applied uniformly, all arrays length `match_count`.
///
/// Returns 0 on success. Returns -1 if `out` is NULL, `team_count` is not in
/// (0, GD_MAX_TEAMS], `match_count` is not positive, `max_iterations` is not
/// positive, `tolerance` is not finite and positive, any `home_idx`/`away_idx`
/// is outside [0, team_count), any goal count is negative, or any weight is
/// not finite or is negative.
int gd_fit_league(const int32_t *home_idx, const int32_t *away_idx,
                  const int32_t *home_goals, const int32_t *away_goals,
                  const double *weight, int32_t match_count,
                  int32_t team_count, int32_t max_iterations,
                  double tolerance, gd_league_fit *out);

#endif
