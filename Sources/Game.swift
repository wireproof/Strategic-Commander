import SwiftUI

struct BattleSnapshot: Equatable { var attackers: Int; var defenders: Int }
struct BattleReplay: Identifiable {
    let id = UUID(); let planet: String; let attacker: Int; let snapshots: [BattleSnapshot]
}
final class Game: ObservableObject {
    @Published var battles: [BattleReplay] = []
    @Published var s: State { didSet { if !isProcessingTurn { save() } } }
    private var isProcessingTurn = false
    @Published var selected = 0
    @Published var destination: Int? = nil
    @Published var sendCount = 1
    private let key = "strategic-commander-prototype-v1"
    private let persist: Bool
    init(initialState: State? = nil, persist: Bool = true) {
        self.persist = persist
        if let initialState = initialState { s = initialState }
        else {
            if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset") { UserDefaults.standard.removeObject(forKey:key) }
            if let data = UserDefaults.standard.data(forKey:key), let state = try? JSONDecoder().decode(State.self, from:data) { s = state } else { s = .fresh() }
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-battle") {
            s = .fresh(); s.planets[2].owner = 1; s.planets[2].ships = 3; s.planets[2].industry = 0
            s.fleets = [Fleet(owner:0,source:0,destination:2,ships:50,turns:1)]
        }
        #endif
    }
    func save() { guard persist else { return }; if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey:key) } }
    func newGame(planetCount: Int) { s = .fresh(planetCount: planetCount); battles = []; selected = 0; destination = nil }
    func build(_ research: Bool) {
        guard s.result == nil, let i = s.planets.firstIndex(where: {$0.id == selected}), s.planets[i].owner == 0 else { return }
        let price = research ? FacilityAccounting.labPrice : FacilityAccounting.factoryPrice
        let planet = s.planets[i]
        guard s.gold[0] >= price, planet.industry + planet.research < planet.capacity else { return }
        var next = s
        if research {
            var costs = FacilityAccounting.costs(existing: planet.labCosts, count: planet.research, home: planet.home, research: true)
            costs.append(price); next.planets[i].labCosts = costs; next.planets[i].research += 1
        } else {
            var costs = FacilityAccounting.costs(existing: planet.factoryCosts, count: planet.industry, home: planet.home, research: false)
            costs.append(price); next.planets[i].factoryCosts = costs; next.planets[i].industry += 1
        }
        next.gold[0] -= price
        s = next
    }
    @discardableResult func sellFacility(slot: Int) -> Int? {
        guard s.result == nil, let i = s.planets.firstIndex(where: {$0.id == selected}), s.planets[i].owner == 0 else { return nil }
        let planet = s.planets[i]
        guard slot >= 0 && slot < planet.industry + planet.research else { return nil }
        var next = s
        var refund = 0
        if slot < planet.industry {
            let costs = FacilityAccounting.costs(existing: planet.factoryCosts, count: planet.industry, home: planet.home, research: false)
            guard let sale = FacilityAccounting.sold(costs, index: slot) else { return nil }
            next.planets[i].factoryCosts = sale.remaining; next.planets[i].industry -= 1; next.gold[0] += sale.refund; refund = sale.refund
        } else {
            let costs = FacilityAccounting.costs(existing: planet.labCosts, count: planet.research, home: planet.home, research: true)
            guard let sale = FacilityAccounting.sold(costs, index: slot - planet.industry) else { return nil }
            next.planets[i].labCosts = sale.remaining; next.planets[i].research -= 1; next.gold[0] += sale.refund; refund = sale.refund
        }
        s = next
        return refund
    }
    func distance(_ a: Planet, _ b: Planet) -> Double { hypot((a.x-b.x)*28, (a.y-b.y)*28) }
    func travel(_ a: Planet, _ b: Planet, owner: Int) -> Int { max(1, Int(ceil(distance(a,b) / Double(5+s.tech[owner])))) }
    func send() {
        guard s.result == nil, let dest = destination, let i = s.planets.firstIndex(where: {$0.id == selected}), let j = s.planets.firstIndex(where: {$0.id == dest}), s.planets[i].owner == 0, i != j, sendCount > 0, sendCount <= s.planets[i].ships, distance(s.planets[i],s.planets[j]) <= Double(11+s.tech[0]) else { return }
        let turns = travel(s.planets[i],s.planets[j],owner:0)
        s.planets[i].ships -= sendCount; s.fleets.append(Fleet(owner:0,source:selected,destination:dest,ships:sendCount,turns:turns)); destination = nil
    }
    func endTurn() {
        guard s.result == nil else { return }
        isProcessingTurn = true
        defer { isProcessingTurn = false; save() }
        var events: [String] = []
        var turnBattles: [BattleReplay] = []
        // Prototype economy and AI; values are approximations until verified against the original.
        for i in s.planets.indices where s.planets[i].owner >= 0 {
            let owner = s.planets[i].owner, p = s.planets[i]
            let output = PlanetProduction.calculate(p)
            s.planets[i].ships += output.ships
            s.gold[owner] += output.gold
            s.researchPoints[owner] += output.research
        }
        for owner in 0...1 where s.tech[owner] < 15 {
            let threshold = (s.tech[owner]+1)*10
            if s.researchPoints[owner] >= threshold { s.researchPoints[owner] -= threshold; s.tech[owner] += 1; events.append("\(owner == 0 ? "Your" : "Enemy") technology reached level \(s.tech[owner]).") }
        }
        // Prototype AI develops captured worlds and avoids sending duplicate fleets.
        for i in s.planets.indices where s.planets[i].owner == 1 {
            let p = s.planets[i]
            if p.industry + p.research < p.capacity {
                if p.industry == 0 && s.gold[1] >= 200 { s.gold[1] -= 200; s.planets[i].industry += 1 }
                else if p.industry >= 2 && p.research == 0 && s.gold[1] >= 250 { s.gold[1] -= 250; s.planets[i].research += 1 }
                else if s.gold[1] >= 200 { s.gold[1] -= 200; s.planets[i].industry += 1 }
            }
            let src = s.planets[i], reserve = src.home ? 10 : 3
            guard src.ships > reserve + 4 else { continue }
            let targets = s.planets.filter { target in
                target.owner != 1 && distance(src,target) <= Double(11+s.tech[1]) &&
                !s.fleets.contains(where: { $0.owner == 1 && $0.destination == target.id }) &&
                (target.owner == -1 || src.ships - reserve > target.ships)
            }
            if let target = targets.min(by: { distance(src,$0) < distance(src,$1) }) {
                let count = src.ships - reserve; s.planets[i].ships -= count
                s.fleets.append(Fleet(owner:1,source:src.id,destination:target.id,ships:count,turns:travel(src,target,owner:1)))
            }
        }
        for i in s.fleets.indices { s.fleets[i].turns -= 1 }
        let arrivals = s.fleets.filter {$0.turns <= 0}; s.fleets.removeAll {$0.turns <= 0}
        for f in arrivals {
            guard let i = s.planets.firstIndex(where: {$0.id == f.destination}) else { continue }
            let oldOwner = s.planets[i].owner, name = s.planets[i].name
            if oldOwner == f.owner { s.planets[i].ships += f.ships; if f.owner == 0 { events.append("Reinforcements arrived at \(name): \(f.ships) ships joined the fleet.") }; continue }
            if oldOwner == -1 { s.planets[i].owner = f.owner; s.planets[i].ships = f.ships; events.append("\(f.owner == 0 ? "You claimed" : "Enemy claimed") \(name) with \(f.ships) ships; the planet was unoccupied."); continue }
            let initialDefenders = s.planets[i].ships
            var attacking = f.ships, defending = initialDefenders
            let chance = min(0.9,max(0.1,0.5 + Double(s.tech[f.owner]-s.tech[oldOwner])*0.0267))
            var frames = [BattleSnapshot(attackers:attacking,defenders:defending)]
            while attacking > 0 && defending > 0 {
                if Double.random(in:0..<1) < chance { defending -= 1 } else { attacking -= 1 }
                frames.append(BattleSnapshot(attackers:attacking,defenders:defending))
            }
            if initialDefenders > 0 { turnBattles.append(BattleReplay(planet:name,attacker:f.owner,snapshots:frames)) }
            if attacking > 0 {
                s.planets[i].owner = f.owner; s.planets[i].ships = attacking
                if initialDefenders == 0 {
                    events.append("\(f.owner == 0 ? "You captured" : "Enemy captured") undefended \(name) with \(attacking) ships. No battle was needed.")
                } else {
                    events.append("BATTLE AT \(name): \(f.owner == 0 ? "Your" : "Enemy") \(f.ships) ships attacked \(initialDefenders) defenders. \(f.owner == 0 ? "Victory" : "Planet lost"): \(attacking) attacking ships remain.")
                }
                if s.planets[i].home { s.result = f.owner == 0 ? "Victory!" : "Your home world has fallen." }
            } else { s.planets[i].ships = defending; events.append("BATTLE AT \(name): \(f.owner == 0 ? "Your" : "Enemy") \(f.ships) ships attacked \(initialDefenders) defenders. \(f.owner == 0 ? "Attack defeated" : "Defense held"): \(defending) defending ships remain.") }
        }
        for f in s.fleets where f.owner == 0 {
            let name = s.planets.first(where: { $0.id == f.destination })?.name ?? "destination"
            events.append("Fleet to \(name): \(f.ships) ships arriving in \(f.turns) turn\(f.turns == 1 ? "" : "s").")
        }
        battles = turnBattles
        s.turn += 1; s.events = events.isEmpty ? ["No major events this turn."] : events
    }
}
