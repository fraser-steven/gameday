#ifndef GAMEDAY_H
#define GAMEDAY_H

#define GD_MAX_GOALS 10

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

#endif