import SwiftUI

struct Planet: Identifiable, Codable {
    var id: Int; var name: String; var x: Double; var y: Double
    var owner: Int; var home: Bool; var ships: Int; var industry: Int; var research: Int
    var capacity: Int; var grade: Int; var shipPercent: Double
}
struct Fleet: Identifiable, Codable {
    var id = UUID(); var owner: Int; var source: Int; var destination: Int; var ships: Int; var turns: Int
}
struct State: Codable {
    var planets: [Planet]; var fleets: [Fleet] = []; var turn = 1
    var gold = [600, 600]; var tech = [0, 0]; var researchPoints = [0, 0]
    var events = ["Build manufacturing and research, then send ships to claim worlds."]
    var result: String? = nil
    static func fresh() -> State {
        let names = ["Sol", "Vega", "Sirius", "Altair", "Deneb", "Rigel", "Arcturus", "Procyon", "Capella", "Spica", "Polaris", "Antares", "Aldebaran", "Bellatrix", "Regulus", "Orion"]
        let points: [(Double,Double)] = [(0.11,0.18),(0.89,0.82),(0.31,0.12),(0.52,0.10),(0.76,0.19),(0.15,0.39),(0.37,0.35),(0.59,0.31),(0.84,0.42),(0.12,0.67),(0.34,0.59),(0.55,0.55),(0.73,0.66),(0.25,0.85),(0.48,0.82),(0.69,0.89)]
        return State(planets: points.enumerated().map { i,p in Planet(id:i, name:names[i], x:p.0, y:p.1, owner:i < 2 ? i : -1, home:i < 2, ships:i < 2 ? 12 : 0, industry:i < 2 ? 2 : 0, research:0, capacity:5 + i % 5, grade:i % 8, shipPercent:0.7) })
    }
}
struct BattleSnapshot: Equatable { var attackers: Int; var defenders: Int }
struct BattleReplay: Identifiable {
    let id = UUID(); let planet: String; let attacker: Int; let snapshots: [BattleSnapshot]
}
final class Game: ObservableObject {
    @Published var battles: [BattleReplay] = []
    @Published var s: State { didSet { save() } }
    @Published var selected = 0
    @Published var destination: Int? = nil
    @Published var sendCount = 1
    private let key = "strategic-commander-prototype-v1"
    init() { if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset") { UserDefaults.standard.removeObject(forKey:key) }; if let data = UserDefaults.standard.data(forKey:key), let state = try? JSONDecoder().decode(State.self, from:data) { s = state } else { s = .fresh() }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-battle") {
            s = .fresh(); s.planets[2].owner = 1; s.planets[2].ships = 3; s.planets[2].industry = 0
            s.fleets = [Fleet(owner:0,source:0,destination:2,ships:50,turns:1)]
        }
        #endif
    }
    func save() { if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey:key) } }
    func newGame() { s = .fresh(); battles = []; selected = 0; destination = nil }
    func build(_ research: Bool) {
        guard s.result == nil, let i = s.planets.firstIndex(where: {$0.id == selected}), s.planets[i].owner == 0 else { return }
        let cost = research ? 250 : 200
        guard s.gold[0] >= cost, s.planets[i].industry + s.planets[i].research < s.planets[i].capacity else { return }
        s.gold[0] -= cost
        if research { s.planets[i].research += 1 } else { s.planets[i].industry += 1 }
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
        var events: [String] = []
        var turnBattles: [BattleReplay] = []
        // Prototype economy and AI; values are approximations until verified against the original.
        for i in s.planets.indices where s.planets[i].owner >= 0 {
            let owner = s.planets[i].owner, p = s.planets[i]
            let output = max(1, 8-p.grade/2)
            s.planets[i].ships += Int(Double(p.industry * output) * p.shipPercent)
            s.gold[owner] += Int(Double(p.industry * output * 8) * (1-p.shipPercent))
            s.researchPoints[owner] += p.research
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
@main struct StrategicCommanderApp: App { @StateObject var game = Game(); var body: some Scene { WindowGroup { ContentView().environmentObject(game).preferredColorScheme(.dark) } } }
struct ContentView: View {
    @EnvironmentObject var g: Game
    @State private var showReport = false
    @State private var confirmNew = false
    @State private var isOrdering = false
    @State private var showGuide = false
    @State private var launchNotice: String?
    @State private var dragSource: Int?
    @State private var dragPoint: CGPoint?
    var p: Planet { g.s.planets.first(where: {$0.id == g.selected}) ?? g.s.planets[0] }
    var body: some View {
        GeometryReader { geo in
            VStack(spacing:0) {
                header
                if geo.size.width > 700 {
                    HStack(spacing:0) { map.frame(maxWidth:.infinity,maxHeight:.infinity); Divider(); activePanel.frame(width:min(400,geo.size.width*0.38)) }
                } else {
                    VStack(spacing:0) { map.frame(maxWidth:.infinity,maxHeight:.infinity); Divider(); activePanel.frame(height:geo.size.height*0.50) }
                }
            }.background(Color(red:0.025,green:0.045,blue:0.08)).foregroundStyle(.white)
        }.alert("Start a new game?",isPresented:$confirmNew) { Button("Cancel",role:.cancel){}; Button("New Game",role:.destructive){g.newGame()} } message: { Text("Your current game will be replaced.") }

    }
    var header: some View {
        HStack(spacing:12) { VStack(alignment:.leading,spacing:2) { Text("STRATEGIC COMMANDER").font(.system(size:15,weight:.heavy,design:.rounded)); Text("COMMAND THE STARS").font(.system(size:9,weight:.bold)).foregroundStyle(.cyan) }; Spacer(); VStack(alignment:.trailing) { Text("TURN \(g.s.turn)").font(.caption.bold()); Text("◆ \(g.s.gold[0])  ·  TECH \(g.s.tech[0])").font(.caption2.monospacedDigit()).foregroundStyle(.yellow) }; Menu { Button("How to play") {isOrdering = false; showReport = false; showGuide = true}; Button("Turn report") {isOrdering = false; showGuide = false; g.battles = []; showReport = true}; Button("New game",role:.destructive) {confirmNew = true} } label: { Image(systemName:"ellipsis.circle").font(.title3) } }.padding(.horizontal,16).padding(.vertical,10).background(.black.opacity(0.25))
    }
    var map: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment:.topLeading) {
                Canvas { context,size in
                    for i in 0..<90 { let x = CGFloat((i*137)%997)/997*size.width, y = CGFloat((i*239+33)%991)/991*size.height; context.fill(Path(ellipseIn:CGRect(x:x,y:y,width:i%7 == 0 ? 2:1,height:i%7 == 0 ? 2:1)),with:.color(.white.opacity(0.35))) }
                    for f in g.s.fleets { if let a = g.s.planets.first(where:{$0.id == f.source}), let b = g.s.planets.first(where:{$0.id == f.destination}) { var path = Path(); path.move(to:CGPoint(x:a.x*size.width,y:a.y*size.height)); path.addLine(to:CGPoint(x:b.x*size.width,y:b.y*size.height)); context.stroke(path,with:.color(f.owner == 0 ? .cyan.opacity(0.5) : .red.opacity(0.5)),style:StrokeStyle(lineWidth:1,dash:[4,4])) } }
                }
                if let sourceID = dragSource, let end = dragPoint, let source = g.s.planets.first(where: { $0.id == sourceID }) {
                    Path { path in path.move(to: mapPosition(source, width:w, height:h)); path.addLine(to:end) }
                        .stroke(.cyan,style:StrokeStyle(lineWidth:2,dash:[6,4])).allowsHitTesting(false)
                    Circle().stroke(.cyan,lineWidth:2).frame(width:28,height:28).position(end).allowsHitTesting(false)
                }
                ForEach(g.s.planets) { planet in
                    Button { selectPlanet(planet) } label: {
                        VStack(spacing:2) { ZStack { Circle().fill(RadialGradient(colors:[color(planet).opacity(0.28),color(planet).opacity(0.03),.clear],center:.center,startRadius:0,endRadius:25)).frame(width:50,height:50); Image("Planet\(planet.id % 4)").resizable().aspectRatio(contentMode:.fit).frame(width:34,height:34).overlay(Circle().stroke(color(planet),lineWidth:2).frame(width:28,height:28)).overlay(Text(String(UnicodeScalar(65+planet.grade)!)).font(.system(size:10,weight:.black,design:.rounded)).foregroundStyle(.white).shadow(color:.black,radius:2)); if planet.id == g.selected || planet.id == g.destination { Circle().stroke(.white,lineWidth:1.5).frame(width:31,height:31) } }; Text(planet.name).font(.system(size:10,weight:.semibold)).lineLimit(1).fixedSize(); if planet.owner == 0 { Text("\(planet.ships) ships").font(.system(size:8,weight:.medium)).foregroundStyle(.cyan.opacity(0.8)).fixedSize() } }.contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("planet-\(planet.id)")
                    .position(mapPosition(planet,width:w,height:h))
                }
                if isOrdering, let destination = g.destination, let target = g.s.planets.first(where: { $0.id == destination }) {
                    Path { path in path.move(to:mapPosition(p,width:w,height:h)); path.addLine(to:mapPosition(target,width:w,height:h)) }.stroke(.cyan,style:StrokeStyle(lineWidth:2,dash:[5,4])).allowsHitTesting(false)
                }
                Text(isOrdering && g.destination == nil ? "TAP A DESTINATION ON THE MAP" : "TAP TO INSPECT  ·  DRAG FROM A BLUE WORLD TO SEND").font(.system(size:9,weight:.bold)).tracking(1).foregroundStyle(.white.opacity(0.55)).padding(12)
            }.coordinateSpace(name:"starMap").contentShape(Rectangle())
            .simultaneousGesture(DragGesture(minimumDistance:10,coordinateSpace:.named("starMap"))
                .onChanged { value in
                    guard g.s.result == nil else { return }
                    if dragSource == nil, let start = nearestPlanet(to:value.startLocation,width:w,height:h), start.owner == 0, start.ships > 0 { dragSource = start.id }
                    if dragSource != nil { dragPoint = value.location }
                }
                .onEnded { value in
                    defer { dragSource = nil; dragPoint = nil }
                    guard let sourceID = dragSource, let source = g.s.planets.first(where:{$0.id == sourceID}), let target = nearestPlanet(to:value.location,width:w,height:h), target.id != source.id else { return }
                    beginOrder(from:source,to:target)
                })
        }.clipped()
    }
    func nearestPlanet(to point:CGPoint,width:CGFloat,height:CGFloat) -> Planet? {
        let closest = g.s.planets.min { a,b in
            let pa = mapPosition(a,width:width,height:height), pb = mapPosition(b,width:width,height:height)
            return hypot(pa.x-point.x,pa.y-point.y) < hypot(pb.x-point.x,pb.y-point.y)
        }
        guard let planet = closest else { return nil }
        let center = mapPosition(planet,width:width,height:height)
        return hypot(center.x-point.x,center.y-point.y) <= 55 ? planet : nil
    }
    func beginOrder(from source:Planet,to target:Planet) {
        g.selected = source.id; showReport = false; showGuide = false
        guard g.distance(source,target) <= Double(11+g.s.tech[0]) else { isOrdering = false; g.destination = nil; launchNotice = "\(target.name) is out of range. Research increases fleet range."; return }
        launchNotice = nil; g.destination = target.id; g.sendCount = max(1,source.ships/2); isOrdering = true
    }
    func selectPlanet(_ planet:Planet) {
        if isOrdering, planet.id != g.selected { beginOrder(from:p,to:planet); return }
        g.selected = planet.id; g.destination = nil; isOrdering = false; showReport = false; showGuide = false; launchNotice = nil
    }
    var activePanel: some View {
        Group {
            if showReport { TurnReportView(onDone:{showReport = false}).environmentObject(g) }
            else if showGuide { guidePanel }
            else if isOrdering { orderPanel }
            else { details }
        }.background(Color(red:0.06,green:0.09,blue:0.14))
    }
    var guidePanel: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack { Text("HOW TO PLAY").font(.headline); Spacer(); Button("Back") {showGuide = false} }
            ScrollView { Text("Capture the enemy home world while defending your own. Drag from one of your blue worlds to another world, choose how many ships to send, and launch. You can also tap Send Ships and select a destination on the map. End your turn to advance fleets. Build factories to produce ships or gold and labs to improve technology.").font(.subheadline).frame(maxWidth:.infinity,alignment:.leading) }
        }.padding(14)
    }
    var orderPanel: some View {
        VStack(alignment:.leading,spacing:10) {
            HStack { Text("SEND SHIPS").font(.headline); Spacer(); Button("Cancel") {isOrdering = false; g.destination = nil} }
            HStack { Text("From \(p.name)").font(.subheadline.bold()); Spacer(); Text("\(p.ships) available").font(.caption).foregroundStyle(.secondary) }
            if let id = g.destination, let target = g.s.planets.first(where:{$0.id == id}) {
                HStack { Text("To \(target.name)").font(.subheadline.bold()); Spacer(); Text("\(g.travel(p,target,owner:0)) turn(s)").font(.caption).foregroundStyle(.cyan) }
                HStack { Text("Ships"); Spacer(); Text("\(g.sendCount) / \(p.ships)").font(.headline.monospacedDigit()).foregroundStyle(.cyan) }
                Slider(value:Binding(get:{Double(g.sendCount)},set:{g.sendCount = min(p.ships,Int($0.rounded()))}),in:1...Double(max(2,p.ships)),step:1).disabled(p.ships <= 1)
                HStack { Button("Half") {g.sendCount = max(1,p.ships/2)}; Spacer(); Button("All ships") {g.sendCount = p.ships} }.font(.caption)
                Button { let count = g.sendCount; let name = target.name; g.send(); isOrdering = false; launchNotice = "\(count) ships launched to \(name). End your turn to move them." } label: { Label("Launch Fleet to \(target.name)",systemImage:"paperplane.fill").frame(maxWidth:.infinity).padding(.vertical,6) }.buttonStyle(.borderedProminent).tint(.teal)
                Text("Tap another world to change destination.").font(.caption).foregroundStyle(.secondary)
            } else {
                Spacer(); Label("Tap a destination on the map",systemImage:"hand.tap").font(.subheadline.bold()).foregroundStyle(.cyan); Text("Choose a world within range to set the fleet size.").font(.caption).foregroundStyle(.secondary); Spacer()
            }
            Spacer(minLength:0)
        }.padding(14)
    }
    func mapPosition(_ p: Planet, width: CGFloat, height: CGFloat) -> CGPoint { CGPoint(x:max(28,min(width-28,p.x*width)),y:max(30,min(height-28,p.y*height))) }
    func color(_ p: Planet) -> Color { p.owner == 0 ? .cyan : p.owner == 1 ? .red : .gray }
    var details: some View {
        VStack(spacing:0) {
            HStack(alignment:.firstTextBaseline) { Text(p.name).font(.title2.bold()); if p.home { Image(systemName:"crown.fill").foregroundStyle(.yellow) }; Spacer(); Text(p.owner == 0 ? "YOUR WORLD" : p.owner == 1 ? "ENEMY" : "UNCHARTED").font(.caption2.bold()).foregroundStyle(color(p)) }.padding(.horizontal,14).padding(.top,10).padding(.bottom,6)
            ScrollView {
            VStack(alignment:.leading,spacing:10) {
                HStack(alignment:.center,spacing:16) {
                    PlanetPortrait(planet:p).frame(width:86,height:86)
                    VStack(alignment:.leading,spacing:6) {
                        Text("CLASS \(String(UnicodeScalar(65+p.grade)!))").font(.headline.bold())
                        Text("\(p.ships) ships in orbit").font(.subheadline.monospacedDigit())
                        Text("\(p.industry+p.research) / \(p.capacity) building slots").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength:0)
                }.frame(maxWidth:.infinity,alignment:.leading).padding(10).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:12))
                if p.owner == 0 {
                    let threshold = (g.s.tech[0]+1)*10
                    VStack(alignment:.leading,spacing:4) {
                        HStack { Text("RESEARCH PROGRESS"); Spacer(); Text(g.s.tech[0] >= 15 ? "MAX LEVEL" : "\(g.s.researchPoints[0]) / \(threshold)") }.font(.system(size:9,weight:.bold)).foregroundStyle(.secondary)
                        ProgressView(value:Double(min(g.s.researchPoints[0],threshold)),total:Double(threshold)).tint(.cyan)
                    }
                }
                if p.owner == 0 && g.s.result == nil {
                    HStack { Text("BUILDINGS").font(.system(size:10,weight:.bold)).tracking(1).foregroundStyle(.secondary); Spacer(); Text("\(p.industry+p.research) / \(p.capacity)").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                    BuildingSlots(planet:p)
                    HStack { Button("+ Factory · 200") {g.build(false)}.disabled(g.s.gold[0] < 200 || p.industry+p.research >= p.capacity); Button("+ Research · 250") {g.build(true)}.disabled(g.s.gold[0] < 250 || p.industry+p.research >= p.capacity) }.buttonStyle(.bordered).font(.caption)
                    VStack(alignment:.leading,spacing:2) { HStack { Text("PRODUCTION MIX").font(.system(size:9,weight:.bold)).foregroundStyle(.secondary); Spacer(); Text("\(Int((1-p.shipPercent)*100))% GOLD  ·  \(Int(p.shipPercent*100))% SHIPS").font(.system(size:9,weight:.bold)).foregroundStyle(.cyan) }; HStack { Image(systemName:"diamond.fill").foregroundStyle(.yellow); Slider(value:Binding(get:{p.shipPercent},set:{v in if let i = g.s.planets.firstIndex(where:{$0.id == p.id}) {g.s.planets[i].shipPercent = v}})); Image(systemName:"paperplane.fill").foregroundStyle(.cyan) }.font(.caption) }
                    HStack { Text("\(p.industry) factories  ·  \(p.research) labs").font(.caption).foregroundStyle(.secondary); Spacer() }
                    Button { g.destination = nil; g.sendCount = max(1,p.ships / 2); isOrdering = true } label: {
                        Label("Send Ships", systemImage:"paperplane.fill").frame(maxWidth:.infinity).padding(.vertical,7)
                    }.buttonStyle(.borderedProminent).tint(.teal).disabled(p.ships == 0)
                    if p.ships == 0 { Text("Build a factory and end a turn to produce ships.").font(.caption).foregroundStyle(.secondary) }
                    if let notice = launchNotice { Label(notice,systemImage:"checkmark.circle.fill").font(.caption).foregroundStyle(.green) }

                } else if g.destination == nil { Text("Select one of your worlds to build or send ships.").font(.caption).foregroundStyle(.secondary) }
                if !g.s.fleets.filter({$0.owner == 0}).isEmpty {
                    VStack(alignment:.leading,spacing:5) {
                        Text("FLEETS IN TRANSIT").font(.system(size:9,weight:.bold)).foregroundStyle(.secondary)
                        ForEach(g.s.fleets.filter({$0.owner == 0})) { f in
                            let from = g.s.planets.first(where:{$0.id == f.source})?.name ?? "?"
                            let to = g.s.planets.first(where:{$0.id == f.destination})?.name ?? "?"
                            HStack { Image(systemName:"paperplane.fill").foregroundStyle(.cyan); Text("\(from) → \(to)"); Spacer(); Text("\(f.ships) ships · \(f.turns) turn\(f.turns == 1 ? "" : "s")").foregroundStyle(.secondary) }.font(.caption)
                        }
                    }.padding(10).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:10))
                }
                if let result = g.s.result { Text(result).font(.headline).foregroundStyle(.yellow) }
            }.padding(.horizontal,14).padding(.bottom,10)
            }.scrollIndicators(.visible)
            Button { launchNotice = nil; g.endTurn(); showReport = true } label: { HStack { Spacer(); Text("END TURN").font(.subheadline.bold()); Image(systemName:"arrow.right"); Spacer() }.padding(7) }.buttonStyle(.borderedProminent).tint(.indigo).disabled(g.s.result != nil).padding(.horizontal,14).padding(.vertical,8)
        }.background(Color(red:0.06,green:0.09,blue:0.14))
    }
    func stat(_ label:String,_ value:String) -> some View { VStack(alignment:.leading,spacing:3) { Text(label).font(.system(size:9,weight:.bold)).foregroundStyle(.secondary); Text(value).font(.subheadline.monospacedDigit().bold()) }.frame(maxWidth:.infinity,alignment:.leading).padding(8).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:8)) }
}


struct FleetOrderView: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    var onLaunch: (String) -> Void
    @State private var choosingDestination = false
    var source: Planet { game.s.planets.first(where: {$0.id == game.selected}) ?? game.s.planets[0] }
    var destinations: [Planet] { game.s.planets.filter {$0.id != source.id}.sorted { game.distance(source,$0) < game.distance(source,$1) } }
    var target: Planet? { game.s.planets.first(where: {$0.id == game.destination}) }
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment:.leading,spacing:10) {
                        if geo.size.width > 550 {
                            HStack(alignment:.top,spacing:20) { route.frame(maxWidth:.infinity,alignment:.leading); if target != nil && !choosingDestination { quantity.frame(maxWidth:.infinity,alignment:.leading) } }
                        } else { route; if target != nil && !choosingDestination { quantity } }
                        if target == nil || choosingDestination { destinationList }
                    }.padding(.horizontal,16).padding(.vertical,8)
                }
            }.safeAreaInset(edge:.bottom) {
                if let target = target, !choosingDestination {
                    Button { let count = game.sendCount; let name = target.name; game.send(); onLaunch("\(count) ships launched to \(name). End your turn to move them."); dismiss() } label: { Label("Launch Fleet to \(target.name)",systemImage:"paperplane.fill").frame(maxWidth:.infinity).padding(.vertical,4) }.buttonStyle(.borderedProminent).tint(.teal).padding(.horizontal,16).padding(.vertical,6).background(.regularMaterial)
                }
            }.navigationTitle("Send Ships").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cancel") { game.destination = nil; dismiss() } } }
        }
    }
    var route: some View {
        VStack(alignment:.leading,spacing:8) {
            Text("FLEET ORDER").font(.caption.bold()).foregroundStyle(.secondary)
            Label("From \(source.name) · \(source.ships) ships",systemImage:"location.fill").font(.subheadline.bold())
            if let target = target { HStack { Label("To \(target.name)",systemImage:"scope"); Spacer(); Button("Change") {choosingDestination = true} }.font(.subheadline); Text("Arrival in \(game.travel(source,target,owner:0)) turn(s)").font(.caption).foregroundStyle(.secondary) }
        }.padding(10).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:10))
    }
    var quantity: some View {
        VStack(alignment:.leading,spacing:4) {
            HStack { Text("SHIPS").font(.caption.bold()).foregroundStyle(.secondary); Spacer(); Text("\(game.sendCount) / \(source.ships)").font(.headline.monospacedDigit()).foregroundStyle(.cyan) }
            Slider(value:Binding(get:{Double(game.sendCount)},set:{game.sendCount = Int($0.rounded())}),in:1...Double(max(2,source.ships)),step:1).disabled(source.ships <= 1)
            HStack { Button("Half") {game.sendCount = max(1,source.ships/2)}; Spacer(); Button("All ships") {game.sendCount = source.ships} }.font(.caption)
        }.padding(10).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:10))
    }
    var destinationList: some View {
        VStack(alignment:.leading,spacing:0) {
            Text("CHOOSE A DESTINATION").font(.caption.bold()).foregroundStyle(.secondary).padding(.vertical,8)
            ForEach(destinations) { world in
                let reachable = game.distance(source,world) <= Double(11+game.s.tech[0])
                Button { game.destination = world.id; choosingDestination = false } label: {
                    HStack { Text(world.name).font(.subheadline.bold()); Spacer(); Text(reachable ? "\(game.travel(source,world,owner:0)) turn(s)" : "Out of range").font(.caption).foregroundStyle(.secondary) }.padding(.vertical,8).contentShape(Rectangle())
                }.disabled(!reachable).accessibilityLabel("\(world.name), \(reachable ? "reachable" : "out of range")")
                Divider()
            }
        }
    }
}

struct TurnReportView: View {
    @EnvironmentObject var game: Game
    var onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var battleIndex = 0
    @State private var frameIndex = 0
    @State private var battlePhase = 0
    @State private var hitAttacker = false
    @State private var shotProgress: CGFloat = 0
    var battle: BattleReplay? { game.battles.indices.contains(battleIndex) ? game.battles[battleIndex] : nil }
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment:.leading,spacing:10) {
                        if let b = battle {
                            Text("BATTLE AT \(b.planet.uppercased())").font(.headline)
                            let frame = b.snapshots[min(frameIndex,b.snapshots.count-1)]
                            battleArena(battle:b,frame:frame).frame(height:max(175,min(320,geo.size.height-100)))

                            HStack { Text(frameIndex == b.snapshots.count-1 ? ((frame.attackers > 0) == (b.attacker == 0) ? "Victory!" : "Defeat") : "Battle in progress…").font(.caption.bold()).foregroundStyle(.secondary); Spacer(); Button(frameIndex < b.snapshots.count-1 ? "Skip" : (battleIndex+1 < game.battles.count ? "Next Battle" : "Turn Report")) { if frameIndex < b.snapshots.count-1 { frameIndex = b.snapshots.count-1; battlePhase = 0 } else { battleIndex += 1; frameIndex = 0; battlePhase = 0 } }.buttonStyle(.borderedProminent).tint(.teal) }
                        } else {
                            Text("TURN \(game.s.turn)").font(.caption.bold()).foregroundStyle(.secondary)
                            let cols = geo.size.width > 600 ? [GridItem(.flexible()),GridItem(.flexible())] : [GridItem(.flexible())]
                            LazyVGrid(columns:cols,alignment:.leading,spacing:8) { ForEach(Array(game.s.events.enumerated()),id:\.offset) { _,event in Text(event).font(.subheadline).frame(maxWidth:.infinity,alignment:.leading).padding(10).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:9)) } }
                        }
                    }.padding(.horizontal,16).padding(.vertical,8)
                }
            }.navigationTitle(battle == nil ? "Turn report" : "Battle").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement:.confirmationAction) { Button("Back to map") {onDone()} } }
        }.task(id:battle?.id) {
            guard let b = battle else { return }
            frameIndex = 0
            if reduceMotion { frameIndex = b.snapshots.count-1; return }
            while frameIndex < b.snapshots.count-1 && !Task.isCancelled {
                let next = frameIndex + 1
                hitAttacker = b.snapshots[next].attackers < b.snapshots[frameIndex].attackers
                try? await Task.sleep(nanoseconds:350_000_000)
                if Task.isCancelled || frameIndex >= b.snapshots.count-1 { break }
                shotProgress = 0; battlePhase = 1
                try? await Task.sleep(nanoseconds:30_000_000)
                if Task.isCancelled || frameIndex >= b.snapshots.count-1 { break }
                withAnimation(.linear(duration:0.48)) { shotProgress = 1 }
                try? await Task.sleep(nanoseconds:480_000_000)
                if Task.isCancelled || frameIndex >= b.snapshots.count-1 { break }
                withAnimation(.easeOut(duration:0.15)) { battlePhase = 2 }
                try? await Task.sleep(nanoseconds:350_000_000)
                if Task.isCancelled || frameIndex >= b.snapshots.count-1 { break }
                withAnimation(.easeInOut(duration:0.12)) { frameIndex = next; battlePhase = 0 }
                try? await Task.sleep(nanoseconds:250_000_000)
            }
        }
    }
    func battleArena(battle:BattleReplay,frame:BattleSnapshot) -> some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let done = frameIndex == battle.snapshots.count-1
            ZStack {
                RoundedRectangle(cornerRadius:10).fill(Color.white)
                fleetMarker(title:battle.attacker == 0 ? "YOUR FLEET" : "ENEMY FLEET",count:frame.attackers,color:battle.attacker == 0 ? Color(red:0.02,green:0.25,blue:0.65) : Color(red:0.65,green:0.08,blue:0.12))
                    .position(x:max(58,w*0.14),y:34)
                fleetMarker(title:battle.attacker == 0 ? "DEFENDERS" : "YOUR DEFENSE",count:frame.defenders,color:battle.attacker == 0 ? Color(red:0.65,green:0.08,blue:0.12) : Color(red:0.02,green:0.25,blue:0.65))
                    .position(x:min(w-58,w*0.86),y:h-34)
                if !done || frame.attackers > 0 {
                    battleFighter(hit:battlePhase == 2 && hitAttacker).position(x:w*0.42,y:h*0.27)
                }
                if !done || frame.defenders > 0 {
                    battleFighter(hit:battlePhase == 2 && !hitAttacker).position(x:w*0.58,y:h*0.66)
                }
                if battlePhase == 1 && !done {
                    Image(systemName:"plus").font(.system(size:18,weight:.black)).foregroundStyle(.black)
                        .position(x:hitAttacker ? w*(0.58-0.16*shotProgress) : w*(0.42+0.16*shotProgress),y:hitAttacker ? h*(0.66-0.39*shotProgress) : h*(0.27+0.39*shotProgress))
                        .transition(.opacity)
                }
                if done { Text((frame.attackers > 0) == (battle.attacker == 0) ? "WON!" : "LOST…").font(.headline.bold()).foregroundStyle(.black).position(x:w*0.5,y:h*0.48) }
                Text(battle.planet).font(.system(size:10,weight:.bold)).foregroundStyle(.black.opacity(0.65)).position(x:w*0.5,y:h-12)
            }.clipped()
        }.accessibilityLabel("Battle animation")
    }
    func battleFighter(hit:Bool) -> some View {
        ZStack {
            if hit { Image(systemName:"burst.fill").font(.system(size:32)).foregroundStyle(.red).overlay(Image(systemName:"burst.fill").font(.system(size:15)).foregroundStyle(.yellow)) }
            else { Image("ClassicFighter").resizable().interpolation(.high).aspectRatio(contentMode:.fit).frame(width:42,height:48) }
        }.frame(width:46,height:50)
    }
    func fleetMarker(title:String,count:Int,color:Color) -> some View {
        VStack(spacing:1) {
            HStack(spacing:3) {
                VStack(spacing:1) { ForEach(0..<2,id:\.self) { _ in HStack(spacing:1) { ForEach(0..<2,id:\.self) { _ in Image("ClassicFighter").resizable().interpolation(.high).aspectRatio(contentMode:.fit).frame(width:13,height:14) } } } }
                Text("\(count)").font(.system(size:15,weight:.heavy,design:.monospaced)).foregroundStyle(.black)
            }
            Text(title).font(.system(size:8,weight:.bold)).foregroundStyle(color)
        }.accessibilityElement(children:.combine)
    }
}
struct ClassicBattleShip: Shape {
    func path(in rect:CGRect) -> Path {
        var p = Path(); p.move(to:CGPoint(x:rect.minX+rect.width*0.08,y:rect.minY+rect.height*0.36))
        p.addLines([CGPoint(x:rect.minX+rect.width*0.3,y:rect.minY+rect.height*0.15),CGPoint(x:rect.minX+rect.width*0.33,y:rect.minY),CGPoint(x:rect.minX+rect.width*0.48,y:rect.minY+rect.height*0.30),CGPoint(x:rect.minX+rect.width*0.75,y:rect.minY+rect.height*0.4),CGPoint(x:rect.maxX,y:rect.maxY),CGPoint(x:rect.minX+rect.width*0.53,y:rect.minY+rect.height*0.77),CGPoint(x:rect.minX+rect.width*0.13,y:rect.minY+rect.height*0.63)]);p.closeSubpath();return p
    }

}

struct PlanetPortrait: View {
    let planet: Planet
    var body: some View {
        ZStack {
            Image("Planet\(planet.id % 4)").resizable().aspectRatio(contentMode:.fit).frame(width:86,height:86)
            if planet.home { Image(systemName:"crown.fill").font(.system(size:16)).foregroundStyle(.yellow).shadow(color:.black,radius:2).offset(y:3) }
        }.accessibilityLabel("Class \(String(UnicodeScalar(65+planet.grade)!)) planet")
    }
}
struct BuildingSlots: View {
    let planet: Planet
    var body: some View {
        LazyVGrid(columns:[GridItem(.adaptive(minimum:42,maximum:52),spacing:5)],alignment:.leading,spacing:5) {
            ForEach(0..<planet.capacity,id:\.self) { slot in
                let factory = slot < planet.industry
                let lab = slot >= planet.industry && slot < planet.industry + planet.research
                VStack(spacing:3) {
                    Image(systemName: factory ? "building.2.fill" : lab ? "atom" : "plus").font(.system(size:15,weight:.bold)).foregroundStyle(factory ? Color.orange : lab ? Color.cyan : Color.white.opacity(0.18))
                    Text(factory ? "FACT" : lab ? "LAB" : "EMPTY").font(.system(size:7,weight:.bold)).foregroundStyle(.secondary)
                }.frame(maxWidth:.infinity).frame(height:42).background(.white.opacity(factory || lab ? 0.08 : 0.025),in:RoundedRectangle(cornerRadius:6)).overlay(RoundedRectangle(cornerRadius:6).stroke(.white.opacity(0.08),lineWidth:1)).accessibilityLabel(factory ? "Factory" : lab ? "Research lab" : "Empty building slot")
            }
        }
    }
}
