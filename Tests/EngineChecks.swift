import Foundation

@main struct EngineChecks {
    static func main() throws {
        var initial = State.fresh()
        initial.gold[0] = 1_000
        initial.planets[0].capacity = 9
        let game = Game(initialState: initial, persist: false)
        for _ in 0..<3 { game.build(false) }
        precondition(game.s.gold[0] == 400 && game.s.planets[0].industry == 5)
        precondition(game.s.planets[0].factoryCosts == [0,0,200,200,200])
        let order = FacilityAccounting.displayOrder(factoryCosts: game.s.planets[0].factoryCosts!, labCosts: [])
        precondition(order == [2,3,4,0,1])
        for _ in 0..<3 { precondition(game.sellFacility(slot: 2) == 200) }
        precondition(game.s.gold[0] == 1_000 && game.s.planets[0].industry == 2)
        for _ in 0..<2 { game.build(true) }
        precondition(game.s.gold[0] == 500 && game.s.planets[0].research == 2)
        for _ in 0..<2 { precondition(game.sellFacility(slot: 2) == 250) }
        precondition(game.s.gold[0] == 1_000 && game.s.planets[0].research == 0)
        precondition(game.sellFacility(slot: 0) == 0 && game.s.gold[0] == 1_000)
        precondition(game.sellFacility(slot: 99) == nil && game.s.gold[0] == 1_000)
        game.build(false)
        precondition(game.s.gold[0] == 800 && game.sellFacility(slot: 1) == 200 && game.s.gold[0] == 1_000)
        let persisted = try JSONDecoder().decode(State.self, from: JSONEncoder().encode(game.s))
        precondition(persisted.planets[0].factoryCosts == [0])
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(initial)) as! [String: Any]
        var planets = legacy["planets"] as! [[String: Any]]
        for index in planets.indices { planets[index].removeValue(forKey:"factoryCosts"); planets[index].removeValue(forKey:"labCosts") }
        legacy["planets"] = planets
        let restored = try JSONDecoder().decode(State.self, from: JSONSerialization.data(withJSONObject: legacy))
        let oldGame = Game(initialState: restored, persist: false)
        oldGame.build(false)
        precondition(oldGame.sellFacility(slot: 2) == 200 && oldGame.s.gold[0] == 1_000)
        var productionPlanet = initial.planets[0]
        productionPlanet.industry = 2; productionPlanet.research = 2; productionPlanet.shipPercent = 0.7
        let output = PlanetProduction.calculate(productionPlanet)
        precondition(output.outputPerFactory == 8 && output.ships == 11 && output.gold == 38 && output.research == 2)
        var turnState = initial
        for i in turnState.planets.indices where i != 0 { turnState.planets[i].owner = -1 }
        turnState.planets[0] = productionPlanet
        let turnGame = Game(initialState: turnState, persist: false)
        let shipsBefore = turnGame.s.planets[0].ships, goldBefore = turnGame.s.gold[0]
        turnGame.endTurn()
        precondition(turnGame.s.planets[0].ships - shipsBefore == output.ships && turnGame.s.gold[0] - goldBefore == output.gold && turnGame.s.researchPoints[0] == output.research)
        print("Engine checks passed: repeat build/sell refunds, free starters, legacy saves, and per-turn production")
    }
}
