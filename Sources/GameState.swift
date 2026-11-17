import Foundation

struct Planet: Identifiable, Codable {
    var id: Int; var name: String; var x: Double; var y: Double
    var owner: Int; var home: Bool; var ships: Int; var industry: Int; var research: Int
    var capacity: Int; var grade: Int; var shipPercent: Double
    var factoryCosts: [Int]? = nil; var labCosts: [Int]? = nil
}
struct Fleet: Identifiable, Codable {
    var id = UUID(); var owner: Int; var source: Int; var destination: Int; var ships: Int; var turns: Int
}
struct State: Codable {
    var planets: [Planet]; var fleets: [Fleet] = []; var turn = 1
    var gold = [600, 600]; var tech = [0, 0]; var researchPoints = [0, 0]
    var events = ["Build manufacturing and research, then send ships to claim worlds."]
    var result: String? = nil
    static func fresh(planetCount: Int = 16) -> State {
        let count = GalaxyLayout.normalizedCount(planetCount)
        return State(planets: (0..<count).map { i in
            let point = GalaxyLayout.position(index: i, count: count)
            return Planet(id:i, name:GalaxyLayout.names[i], x:point.0, y:point.1, owner:i < 2 ? i : -1, home:i < 2, ships:i < 2 ? 12 : 0, industry:i < 2 ? 2 : 0, research:0, capacity:5 + i % 5, grade:i % 8, shipPercent:0.7)
        })
    }

}
