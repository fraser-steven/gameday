import Testing
@testable import GamedayEngine

struct PoissonTests {
    @Test func marketsForModerateLambdas() throws {
        let markets = try #require(Engine.markets(lambdaHome: 1.5, lambdaAway: 1.1))
        #expect(abs(markets.home - 0.448312) < 1e-6)
        #expect(abs(markets.draw - 0.289531) < 1e-6)
        #expect(abs(markets.away - 0.262157) < 1e-6)
        #expect(abs(markets.bttsYes - 0.534204) < 1e-6)
    }

    @Test func marketsForLopsidedLambdas() throws {
        let markets = try #require(Engine.markets(lambdaHome: 2.4, lambdaAway: 0.6))
        #expect(abs(markets.home - 0.764591) < 1e-6)
        #expect(abs(markets.draw - 0.170461) < 1e-6)
        #expect(abs(markets.away - 0.064947) < 1e-6)
        #expect(abs(markets.bttsYes - 0.419576) < 1e-6)
    }

    @Test func invalidLambdaReturnsNil() {
        #expect(Engine.markets(lambdaHome: 0, lambdaAway: 1.0) == nil)
        #expect(Engine.markets(lambdaHome: -1, lambdaAway: 1.0) == nil)
        #expect(Engine.markets(lambdaHome: .nan, lambdaAway: 1.0) == nil)
        #expect(Engine.markets(lambdaHome: .infinity, lambdaAway: 1.0) == nil)
    }

    @Test func probabilitiesSumToOne() throws {
        let markets = try #require(Engine.markets(lambdaHome: 1.8, lambdaAway: 1.2))
        let sum = markets.home + markets.draw + markets.away
        #expect(abs(sum - 1.0) < 1e-9)
    }
}
