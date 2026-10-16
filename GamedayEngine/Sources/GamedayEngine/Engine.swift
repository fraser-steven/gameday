internal import CGamedayEngine

public struct MarketProbabilities: Equatable, Sendable {
    public let home: Double
    public let draw: Double
    public let away: Double
    public let bttsYes: Double
}

/// Per-team attack/defence strength and a shared home-advantage multiplier,
/// as fitted by `Engine.fit`. `attack`/`defence` are indexed the same way the
/// `homeIndex`/`awayIndex` passed into `fit` were.
public struct LeagueFit: Equatable, Sendable {
    public let attack: [Double]
    public let defence: [Double]
    public let homeAdvantage: Double
}

public enum Engine {
    public static func markets(lambdaHome: Double, lambdaAway: Double,
                               rho: Double = -0.13) -> MarketProbabilities? {
        var out = gd_market_probs()
        guard gd_poisson_markets(lambdaHome, lambdaAway, rho, &out) == 0 else {
            return nil
        }
        return MarketProbabilities(home: out.home, draw: out.draw,
                                   away: out.away, bttsYes: out.btts_yes)
    }

    /// Fits per-team attack/defence strength and a shared home-advantage
    /// multiplier from weighted historical results, via iterative
    /// proportional fitting. `homeIndex`/`awayIndex`/`homeGoals`/`awayGoals`/
    /// `weight` must all be the same length (one entry per match);
    /// `homeIndex`/`awayIndex` values must be in `0..<teamCount`. Returns
    /// `nil` on invalid input (mismatched lengths, out-of-range indices,
    /// `teamCount` outside `1...64`, etc).
    public static func fit(
        homeIndex: [Int32],
        awayIndex: [Int32],
        homeGoals: [Int32],
        awayGoals: [Int32],
        weight: [Double],
        teamCount: Int,
        maxIterations: Int32 = 200,
        tolerance: Double = 1e-7
    ) -> LeagueFit? {
        guard awayIndex.count == homeIndex.count,
              homeGoals.count == homeIndex.count,
              awayGoals.count == homeIndex.count,
              weight.count == homeIndex.count else {
            return nil
        }
        let matchCount = Int32(homeIndex.count)

        var out = gd_league_fit()
        let status = homeIndex.withUnsafeBufferPointer { home in
            awayIndex.withUnsafeBufferPointer { away in
                homeGoals.withUnsafeBufferPointer { hg in
                    awayGoals.withUnsafeBufferPointer { ag in
                        weight.withUnsafeBufferPointer { w in
                            gd_fit_league(
                                home.baseAddress, away.baseAddress,
                                hg.baseAddress, ag.baseAddress,
                                w.baseAddress, matchCount,
                                Int32(teamCount), maxIterations, tolerance, &out
                            )
                        }
                    }
                }
            }
        }
        guard status == 0 else { return nil }

        // `gd_league_fit.attack`/`.defence` are fixed-size C arrays, which
        // import into Swift as anonymous tuples — not subscriptable, so pull
        // the first `teamCount` doubles out via the tuple's raw memory.
        let attack = withUnsafeBytes(of: &out.attack) { raw in
            Array(raw.bindMemory(to: Double.self).prefix(teamCount))
        }
        let defence = withUnsafeBytes(of: &out.defence) { raw in
            Array(raw.bindMemory(to: Double.self).prefix(teamCount))
        }
        return LeagueFit(attack: attack, defence: defence, homeAdvantage: out.home_advantage)
    }
}
