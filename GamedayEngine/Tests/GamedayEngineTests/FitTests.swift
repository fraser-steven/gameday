import Testing
@testable import GamedayEngine

struct FitTests {
    // Indices into a tiny synthetic double round robin.
    private static let strong: Int32 = 0
    private static let weak: Int32 = 1
    private static let midA: Int32 = 2
    private static let midB: Int32 = 3

    // (home, away, homeGoals, awayGoals) — team 0 dominant, team 1 hapless,
    // teams 2/3 roughly level mid-table. Every pair plays home and away, so
    // the schedule is balanced (no team's raw tally is skewed by a lopsided
    // run of fixtures).
    private static let fixtures: [(Int32, Int32, Int32, Int32)] = [
        (strong, weak, 4, 0),
        (weak, strong, 0, 3),
        (strong, midA, 2, 0),
        (midA, strong, 0, 2),
        (strong, midB, 3, 1),
        (midB, strong, 0, 2),
        (weak, midA, 0, 2),
        (midA, weak, 3, 0),
        (weak, midB, 1, 3),
        (midB, weak, 2, 0),
        (midA, midB, 1, 1),
        (midB, midA, 1, 1),
    ]

    private static func fitSyntheticLeague() -> LeagueFit? {
        Engine.fit(
            homeIndex: fixtures.map(\.0),
            awayIndex: fixtures.map(\.1),
            homeGoals: fixtures.map(\.2),
            awayGoals: fixtures.map(\.3),
            weight: Array(repeating: 1.0, count: fixtures.count),
            teamCount: 4
        )
    }

    @Test func fitsASyntheticLeague() throws {
        let fit = try #require(Self.fitSyntheticLeague())

        #expect(fit.attack.count == 4)
        #expect(fit.defence.count == 4)
        for value in fit.attack + fit.defence {
            #expect(value.isFinite && value > 0)
        }
        #expect(fit.homeAdvantage.isFinite && fit.homeAdvantage > 0)
    }

    @Test func strongTeamOutscoresAndOutdefendsTheWeakTeam() throws {
        let fit = try #require(Self.fitSyntheticLeague())

        // Team 0 scored heavily and conceded almost nothing against team 1
        // specifically (4-0, 3-0). Attack should reflect it scores more;
        // defence (a *concession* multiplier — low is good) should reflect
        // it concedes less.
        #expect(fit.attack[Int(Self.strong)] > fit.attack[Int(Self.weak)])
        #expect(fit.defence[Int(Self.strong)] < fit.defence[Int(Self.weak)])
    }

    @Test func midTableTeamsEndUpBetweenTheExtremes() throws {
        let fit = try #require(Self.fitSyntheticLeague())

        for mid in [Int(Self.midA), Int(Self.midB)] {
            #expect(fit.attack[mid] > fit.attack[Int(Self.weak)])
            #expect(fit.attack[mid] < fit.attack[Int(Self.strong)])
        }
    }

    @Test func fitIsDeterministic() throws {
        let first = try #require(Self.fitSyntheticLeague())
        let second = try #require(Self.fitSyntheticLeague())
        #expect(first == second)
    }

    @Test func invalidInputsReturnNil() {
        // Mismatched array lengths.
        #expect(Engine.fit(homeIndex: [0], awayIndex: [1, 0], homeGoals: [1],
                           awayGoals: [1], weight: [1.0], teamCount: 2) == nil)
        // Team index out of range.
        #expect(Engine.fit(homeIndex: [0], awayIndex: [5], homeGoals: [1],
                           awayGoals: [1], weight: [1.0], teamCount: 2) == nil)
        // No matches.
        #expect(Engine.fit(homeIndex: [], awayIndex: [], homeGoals: [],
                           awayGoals: [], weight: [], teamCount: 2) == nil)
        // Too many teams.
        #expect(Engine.fit(homeIndex: [0], awayIndex: [1], homeGoals: [1],
                           awayGoals: [1], weight: [1.0], teamCount: 65) == nil)
    }
}
