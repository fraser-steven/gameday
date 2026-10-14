import CGamedayEngine

public struct MarketProbabilities: Equatable, Sendable {
    public let home: Double
    public let draw: Double
    public let away: Double
    public let bttsYes: Double
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
}