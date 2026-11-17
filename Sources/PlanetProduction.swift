import Foundation

struct PlanetProduction {
    let outputPerFactory: Int
    let ships: Int
    let gold: Int
    let research: Int

    static func calculate(_ planet: Planet) -> PlanetProduction {
        let output = max(1, 8 - planet.grade / 2)
        return PlanetProduction(outputPerFactory: output,
            ships: Int(Double(planet.industry * output) * planet.shipPercent),
            gold: Int(Double(planet.industry * output * 8) * (1 - planet.shipPercent)),
            research: planet.research)
    }
}
