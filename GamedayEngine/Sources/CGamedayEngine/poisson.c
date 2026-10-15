#include "gameday.h"
#include <math.h>
#include <stddef.h>

static void poisson_pmf(double lambda, double *out) {
    out[0] = exp(-lambda);
    for (int k = 1; k <= GD_MAX_GOALS; k++) {
        out[k] = out[k - 1] * lambda / k;
    }
}

static double dixon_coles_tau(int i, int j, double lambda_home, double lambda_away, double rho) {
    if (i == 0 && j == 0) {
        return 1.0 - lambda_home * lambda_away * rho;
    }
    if (i == 0 && j == 1) {
        return 1.0 + lambda_home * rho;
    }
    if (i == 1 && j == 0) {
        return 1.0 + lambda_away * rho;
    }
    if (i == 1 && j == 1) {
        return 1.0 - rho;
    }
    return 1.0;
}

int gd_poisson_markets(double lambda_home, double lambda_away, double rho, gd_market_probs *out) {
    if (out == NULL) {
        return -1;
    }
    if (!isfinite(lambda_home) || lambda_home <= 0.0) {
        return -1;
    }
    if (!isfinite(lambda_away) || lambda_away <= 0.0) {
        return -1;
    }

    double home_pmf[GD_MAX_GOALS + 1];
    double away_pmf[GD_MAX_GOALS + 1];
    poisson_pmf(lambda_home, home_pmf);
    poisson_pmf(lambda_away, away_pmf);

    double home = 0.0, draw = 0.0, away = 0.0, btts = 0.0, total = 0.0;

    for (int i = 0; i <= GD_MAX_GOALS; i++) {
        for (int j = 0; j <= GD_MAX_GOALS; j++) {
            double p = home_pmf[i] * away_pmf[j];
            if (i <= 1 && j <= 1) {
                p *= dixon_coles_tau(i, j, lambda_home, lambda_away, rho);
            }
            if (p <= 0.0) {
                continue;
            }

            total += p;
            if (i > j) {
                home += p;
            } else if (i == j) {
                draw += p;
            } else {
                away += p;
            }
            if (i >= 1 && j >= 1) {
                btts += p;
            }
        }
    }

    out->home = home / total;
    out->draw = draw / total;
    out->away = away / total;
    out->btts_yes = btts / total;

    return 0;
}
