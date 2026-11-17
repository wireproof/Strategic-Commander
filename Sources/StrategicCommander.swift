import SwiftUI

@main struct StrategicCommanderApp: App { @StateObject var game = Game(); var body: some Scene { WindowGroup { ContentView().environmentObject(game).preferredColorScheme(.dark) } } }
struct ContentView: View {
    @EnvironmentObject var g: Game
    @State private var showReport = false
    @State private var confirmNew = false
    @State private var isOrdering = false
    @State private var showGuide = false
    @State private var launchNotice: String?
    @State private var facilityNotice: String?
    @State private var dragSource: Int?
    @State private var dragPoint: CGPoint?
    @State private var panelLevel = 1
    @AppStorage("next-game-planet-count") private var nextGamePlanetCount = 16
    @State private var mapZoom: CGFloat = 1
    @State private var pinchStartZoom: CGFloat?
    @State private var pinchStartOffset: CGSize = .zero
    @State private var isZooming = false
    @State private var mapOffset: CGSize = .zero
    @State private var panStart: CGSize?
    @State private var isPanning = false
    var p: Planet { g.s.planets.first(where: {$0.id == g.selected}) ?? g.s.planets[0] }
    var body: some View {
        NavigationStack {
        GeometryReader { geo in
                if geo.size.width > 700 {
                    HStack(spacing: 0) {
                        map.frame(maxWidth: .infinity, maxHeight: .infinity)
                        Divider()
                        activePanel.frame(width: min(400, geo.size.width * 0.38))
                    }
                } else {
                    let heights = [min(86.0, geo.size.height * 0.16), geo.size.height * 0.43, geo.size.height * 0.78]
                    ZStack(alignment: .bottom) {
                        map.frame(maxWidth: .infinity, maxHeight: .infinity)
                        SlidingPlanetPanel(level: $panelLevel, heights: heights, planetName: p.name, onInteraction: { cancelDraft() }) { activePanel }
                    }
                }
        }.background(Color(red:0.025,green:0.045,blue:0.08)).foregroundStyle(.white)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if #available(iOS 27.1, *) {
                ToolbarItem(placement: .navigationBarTrailing) { headerStat("TURN", value: "\(g.s.turn)", color: .white) }.axisBehavior(.verticalPreferred)
                ToolbarItem(placement: .navigationBarTrailing) { headerStat("GOLD", value: g.s.gold[0].formatted(), color: .yellow) }.axisBehavior(.verticalPreferred)
                ToolbarItem(placement: .navigationBarTrailing) { headerStat("TECH", value: "\(g.s.tech[0])", color: .cyan) }.axisBehavior(.verticalPreferred)
                ToolbarItem(placement: .navigationBarTrailing) { gameMenu }.axisBehavior(.verticalPreferred)
            } else {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 10) {
                        headerStat("TURN", value: "\(g.s.turn)", color: .white)
                        headerStat("GOLD", value: g.s.gold[0].formatted(), color: .yellow)
                        headerStat("TECH", value: "\(g.s.tech[0])", color: .cyan)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) { gameMenu }
            }
        }
        }.alert("Start a new game?",isPresented:$confirmNew) { Button("Cancel",role:.cancel){}; Button("New Game",role:.destructive){g.newGame(planetCount: nextGamePlanetCount); mapOffset = .zero; mapZoom = 1; isOrdering = false; showReport = false; showGuide = false} } message: { Text("Your current game will be replaced with a \(GalaxyLayout.normalizedCount(nextGamePlanetCount))-planet game.") }
    }
    var gameMenu: some View {
        Menu {
            Button("How to play") { cancelDraft(); showReport = false; showGuide = true; panelLevel = 2 }
            Button("Turn report") { cancelDraft(); showGuide = false; g.battles = []; showReport = true; panelLevel = 2 }
            Menu("Planets in next game: \(GalaxyLayout.normalizedCount(nextGamePlanetCount))") {
                ForEach(GalaxyLayout.choices, id: \.self) { count in
                    Button { cancelDraft(); nextGamePlanetCount = count } label: {
                        if nextGamePlanetCount == count { Label("\(count) planets", systemImage: "checkmark") }
                        else { Text("\(count) planets") }
                    }
                }
            }
            Button("Reset map view") { cancelDraft(); withAnimation(.easeInOut(duration: 0.2)) { mapZoom = 1; mapOffset = .zero } }
            Button("New game", role: .destructive) { cancelDraft(); confirmNew = true }
        } label: { Label("Game menu", systemImage: "ellipsis") }
    }
    func headerStat(_ label: String, value: String, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.65))
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit()).foregroundStyle(color).lineLimit(1)
        }.accessibilityElement(children: .ignore).accessibilityLabel("\(label) \(value)")
    }
    var map: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment:.topLeading) {
                Canvas { context,size in
                    for i in 0..<90 { let x = CGFloat((i*137)%997)/997*size.width, y = CGFloat((i*239+33)%991)/991*size.height; context.fill(Path(ellipseIn:CGRect(x:x,y:y,width:i%7 == 0 ? 2:1,height:i%7 == 0 ? 2:1)),with:.color(.white.opacity(0.35))) }
                    for f in g.s.fleets { if let a = g.s.planets.first(where:{$0.id == f.source}), let b = g.s.planets.first(where:{$0.id == f.destination}) { var path = Path(); path.move(to:mapPosition(a,width:size.width,height:size.height)); path.addLine(to:mapPosition(b,width:size.width,height:size.height)); context.stroke(path,with:.color(f.owner == 0 ? .cyan.opacity(0.5) : .red.opacity(0.5)),style:StrokeStyle(lineWidth:1,dash:[4,4])) } }
                }.contentShape(Rectangle()).onTapGesture { cancelDraft() }
                if let sourceID = dragSource, let end = dragPoint, let source = g.s.planets.first(where: { $0.id == sourceID }) {
                    Path { path in path.move(to: mapPosition(source, width:w, height:h)); path.addLine(to:end) }
                        .stroke(.cyan,style:StrokeStyle(lineWidth:2,dash:[6,4])).allowsHitTesting(false)
                    Circle().stroke(.cyan,lineWidth:2).frame(width:28,height:28).position(end).allowsHitTesting(false)
                }
                ForEach(g.s.planets) { planet in
                    Button { selectPlanet(planet) } label: {
                        VStack(spacing:2) { ZStack { Circle().fill(RadialGradient(colors:[color(planet).opacity(0.28),color(planet).opacity(0.03),.clear],center:.center,startRadius:0,endRadius:25)).frame(width:50,height:50); PlanetArtwork(id:planet.id, size:34).overlay(Circle().stroke(color(planet),lineWidth:2).frame(width:28,height:28)).overlay(Text(String(UnicodeScalar(65+planet.grade)!)).font(.system(size:10,weight:.black,design:.rounded)).foregroundStyle(.white).shadow(color:.black,radius:2)); if planet.id == g.selected || planet.id == g.destination { Circle().stroke(.white,lineWidth:1.5).frame(width:31,height:31) } }; Text(planet.name).font(.system(size:10,weight:.semibold)).lineLimit(1).fixedSize(); if planet.owner == 0 { Text("\(planet.ships) ships").font(.system(size:8,weight:.medium)).foregroundStyle(.cyan.opacity(0.8)).fixedSize() } }.frame(width:72,height:78,alignment:.top).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("planet-\(planet.id)")
                    .scaleEffect(mapZoom)
                    .position(x:mapPosition(planet,width:w,height:h).x,y:mapPosition(planet,width:w,height:h).y + 14 * mapZoom)
                }
                if isOrdering, let destination = g.destination, let target = g.s.planets.first(where: { $0.id == destination }) {
                    Path { path in path.move(to:mapPosition(p,width:w,height:h)); path.addLine(to:mapPosition(target,width:w,height:h)) }.stroke(.cyan,style:StrokeStyle(lineWidth:2,dash:[5,4])).allowsHitTesting(false)
                }

            }.coordinateSpace(name:"starMap").contentShape(Rectangle())
            .highPriorityGesture(DragGesture(minimumDistance:10,coordinateSpace:.named("starMap"))
                .onChanged { value in
                    guard !isZooming else { return }
                    if dragSource == nil && !isPanning {
                        cancelDraft()
                        if g.s.result == nil, let start = nearestPlanet(to:value.startLocation,width:w,height:h, radius:28 * mapZoom), start.owner == 0, start.ships > 0 {
                            dragSource = start.id
                        } else {
                            isPanning = true
                            panStart = mapOffset
                        }
                    }
                    if dragSource != nil { dragPoint = value.location }
                    else if isPanning, let base = panStart {
                        let panLimit = max(0.45, mapZoom - 0.5)
                        mapOffset = CGSize(width:max(-w*panLimit,min(w*panLimit,base.width + value.translation.width)), height:max(-h*panLimit,min(h*panLimit,base.height + value.translation.height)))
                    }
                }
                .onEnded { value in
                    defer { dragSource = nil; dragPoint = nil; isPanning = false; panStart = nil }
                    guard !isZooming, let sourceID = dragSource, let source = g.s.planets.first(where:{$0.id == sourceID}), let target = nearestPlanet(to:value.location,width:w,height:h, radius:55 * mapZoom), target.id != source.id else { return }
                    beginOrder(from:source,to:target)
                })
            .simultaneousGesture(MagnifyGesture()
                .onChanged { value in
                    if pinchStartZoom == nil {
                        cancelDraft()
                        pinchStartZoom = mapZoom; pinchStartOffset = mapOffset; isZooming = true
                        dragSource = nil; dragPoint = nil; isPanning = false; panStart = nil
                    }
                    if let base = pinchStartZoom {
                        let nextZoom = min(3, max(0.65, base * value.magnification))
                        let anchor = CGPoint(x:value.startAnchor.x * w, y:value.startAnchor.y * h)
                        let nextOffset = MapGeometry.zoomOffset(startOffset:pinchStartOffset, startZoom:base, newZoom:nextZoom, anchor:anchor, center:CGPoint(x:w/2,y:h/2))
                        let limit = max(0.15, nextZoom - 0.5)
                        mapZoom = nextZoom
                        mapOffset = CGSize(width:max(-w*limit,min(w*limit,nextOffset.width)), height:max(-h*limit,min(h*limit,nextOffset.height)))
                    }
                }
                .onEnded { _ in pinchStartZoom = nil; isZooming = false })
        }.clipped()
    }
    func nearestPlanet(to point:CGPoint,width:CGFloat,height:CGFloat, radius:CGFloat) -> Planet? {
        let closest = g.s.planets.min { a,b in
            let pa = mapPosition(a,width:width,height:height), pb = mapPosition(b,width:width,height:height)
            return hypot(pa.x-point.x,pa.y-point.y) < hypot(pb.x-point.x,pb.y-point.y)
        }
        guard let planet = closest else { return nil }
        let center = mapPosition(planet,width:width,height:height)
        return hypot(center.x-point.x,center.y-point.y) <= radius ? planet : nil
    }
    func beginOrder(from source:Planet,to target:Planet) {
        g.selected = source.id; showReport = false; showGuide = false; panelLevel = 2
        guard g.distance(source,target) <= Double(11+g.s.tech[0]) else { isOrdering = false; g.destination = nil; launchNotice = "\(target.name) is out of range. Research increases fleet range."; return }
        launchNotice = nil; g.destination = target.id; g.sendCount = max(1,source.ships/2); isOrdering = true
    }
    func cancelDraft() {
        if isOrdering || g.destination != nil { isOrdering = false; g.destination = nil }
    }
    func selectPlanet(_ planet:Planet) {
        cancelDraft()
        g.selected = planet.id; showReport = false; showGuide = false; launchNotice = nil; facilityNotice = nil
        if panelLevel == 0 { panelLevel = 1 }
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
            ScrollView { Text("Capture the enemy home world while defending your own. Drag from one of your blue worlds to another world, choose how many ships to send, and launch. Tap another world or move the map to discard an unfinished order. End your turn to advance fleets. Build factories to produce ships or gold and labs to improve technology.").font(.subheadline).frame(maxWidth:.infinity,alignment:.leading) }
        }.padding(14)
    }
    var orderPanel: some View {
        ScrollView {
        VStack(alignment:.leading,spacing:10) {
            Text("SEND SHIPS").font(.headline)
            HStack { Text("From \(p.name)").font(.subheadline.bold()); Spacer(); Text("\(p.ships) available").font(.caption).foregroundStyle(.secondary) }
            if let id = g.destination, let target = g.s.planets.first(where:{$0.id == id}) {
                HStack { Text("To \(target.name)").font(.subheadline.bold()); Spacer(); Text("\(g.travel(p,target,owner:0)) turn(s)").font(.caption).foregroundStyle(.cyan) }
                HStack { Text("Ships"); Spacer(); Text("\(g.sendCount) / \(p.ships)").font(.headline.monospacedDigit()).foregroundStyle(.cyan) }
                Slider(value:Binding(get:{Double(g.sendCount)},set:{g.sendCount = min(p.ships,Int($0.rounded()))}),in:1...Double(max(2,p.ships)),step:1).disabled(p.ships <= 1)
                HStack { Button("Half") {g.sendCount = max(1,p.ships/2)}; Spacer(); Button("All ships") {g.sendCount = p.ships} }.font(.caption)
                Button { let count = g.sendCount; let name = target.name; g.send(); isOrdering = false; launchNotice = "\(count) ships launched to \(name). End your turn to move them." } label: { Label("Launch Fleet to \(target.name)",systemImage:"paperplane.fill").frame(maxWidth:.infinity).padding(.vertical,6) }.buttonStyle(.borderedProminent).tint(.teal)
                Text("Tap a world or move the map to discard this order.").font(.caption).foregroundStyle(.secondary)
            } else {
                Spacer(); Label("Tap a destination on the map",systemImage:"hand.tap").font(.subheadline.bold()).foregroundStyle(.cyan); Text("Choose a world within range to set the fleet size.").font(.caption).foregroundStyle(.secondary); Spacer()
            }
        }.padding(14)
        }.scrollIndicators(.visible)
    }
    func mapPosition(_ p: Planet, width: CGFloat, height: CGFloat) -> CGPoint {
        let x = max(38,min(width-38,p.x*width))
        let y = max(60,min(height-50,60+p.y*max(1,height-110)))
        return CGPoint(x:(x-width/2)*mapZoom+width/2+mapOffset.width, y:(y-height/2)*mapZoom+height/2+mapOffset.height)
    }
    func color(_ p: Planet) -> Color { p.owner == 0 ? .cyan : p.owner == 1 ? .red : .gray }
    var details: some View {
        VStack(spacing:0) {
            ScrollView {
            VStack(alignment:.leading,spacing:10) {
                HStack(alignment:.center,spacing:16) {
                    PlanetPortrait(planet:p, size:110).frame(width:110,height:110)
                    VStack(alignment:.leading,spacing:5) {
                        HStack(spacing:5) { Text(p.name).font(.headline.bold()); if p.home { Image(systemName:"crown.fill").foregroundStyle(.yellow) }; Spacer(); Text(p.owner == 0 ? "YOUR WORLD" : p.owner == 1 ? "ENEMY" : "UNCHARTED").font(.caption2.bold()).foregroundStyle(color(p)) }
                        let production = PlanetProduction.calculate(p)
                        Text("CLASS \(String(UnicodeScalar(65+p.grade)!)) · \(production.outputPerFactory) OUTPUT / FACTORY").font(.caption.bold())
                        Text("\(p.ships) ships in orbit").font(.subheadline.monospacedDigit())
                        Text("+\(production.ships) ships · +\(production.gold) gold / turn").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Text("+\(production.research) research / turn").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth:.infinity,alignment:.leading).padding(10).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:12))
                if p.owner == 0 {
                    let threshold = (g.s.tech[0]+1)*10
                    VStack(alignment:.leading,spacing:4) {
                        HStack { Text("RESEARCH PROGRESS"); Spacer(); Text(g.s.tech[0] >= 15 ? "MAX LEVEL" : "\(g.s.researchPoints[0]) / \(threshold)") }.font(.system(size:9,weight:.bold)).foregroundStyle(.secondary)
                        ProgressView(value:Double(min(g.s.researchPoints[0],threshold)),total:Double(threshold)).tint(.cyan)
                    }
                }
                if p.owner == 0 && g.s.result == nil {
                    HStack { Text("BUILDINGS").font(.system(size:10,weight:.bold)).tracking(1).foregroundStyle(.secondary); Spacer(); Text(facilityNotice ?? "\(p.industry+p.research) / \(p.capacity)").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                    BuildingSlots(planet:p, gold:g.s.gold[0], onBuild:{ g.build($0); facilityNotice = nil }, onSell:{ if let refund = g.sellFacility(slot:$0) { facilityNotice = "+\(refund) GOLD" } })
                    Text("Tap a facility to sell it. FREE facilities return 0 gold.").font(.caption2).foregroundStyle(.secondary)
                    GeometryReader { row in
                        HStack(spacing:8) {
                            VStack(alignment:.leading,spacing:2) {
                                HStack { Text("PRODUCTION MIX").font(.system(size:9,weight:.bold)).foregroundStyle(.secondary); Spacer(); Text("\(Int((1-p.shipPercent)*100))% GOLD · \(Int(p.shipPercent*100))% SHIPS").font(.system(size:9,weight:.bold)).foregroundStyle(.cyan).lineLimit(1).minimumScaleFactor(0.7) }
                                HStack { Image(systemName:"diamond.fill").foregroundStyle(.yellow); Slider(value:Binding(get:{p.shipPercent},set:{v in if let i = g.s.planets.firstIndex(where:{$0.id == p.id}) {g.s.planets[i].shipPercent = v}})); Image(systemName:"paperplane.fill").foregroundStyle(.cyan) }.font(.caption)
                            }.frame(width:max(0,(row.size.width-8)*0.75))
                            endTurnButton
                        }
                    }.frame(height:58)
                    if p.ships == 0 { Text("Build a factory and end a turn to produce ships.").font(.caption).foregroundStyle(.secondary) }
                    if let notice = launchNotice { Label(notice,systemImage:"checkmark.circle.fill").font(.caption).foregroundStyle(.green) }

                } else if g.s.result == nil {
                    HStack { Text("Select one of your worlds to build or send ships.").font(.caption).foregroundStyle(.secondary); Spacer(); endTurnButton.frame(width:100) }
                }
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
            }.scrollIndicators(.visible).id(p.id)
        }.background(Color(red:0.06,green:0.09,blue:0.14))
    }
    var endTurnButton: some View {
        Button { cancelDraft(); launchNotice = nil; facilityNotice = nil; g.endTurn(); showReport = true; panelLevel = 2 } label: {
            VStack(spacing:3) { Image(systemName:"arrow.right"); Text("End Turn").lineLimit(1).minimumScaleFactor(0.7) }.font(.caption.bold()).frame(maxWidth:.infinity).frame(height:52)
        }.buttonStyle(.borderedProminent).tint(.indigo).disabled(g.s.result != nil).accessibilityLabel("End Turn")
    }
    func stat(_ label:String,_ value:String) -> some View { VStack(alignment:.leading,spacing:3) { Text(label).font(.system(size:9,weight:.bold)).foregroundStyle(.secondary); Text(value).font(.subheadline.monospacedDigit().bold()) }.frame(maxWidth:.infinity,alignment:.leading).padding(8).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:8)) }
}


// Keep drag state inside the panel so moving the handle does not invalidate the map.
struct SlidingPlanetPanel<Content: View>: View {
    @Binding var level: Int
    let heights: [CGFloat]
    let planetName: String
    let onInteraction: () -> Void
    @ViewBuilder var content: () -> Content
    @State private var drag: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        let height = PanelMotion.height(level: level, translation: drag, heights: heights)
        VStack(spacing: 0) {
            handle
            content().frame(maxWidth: .infinity).frame(height: max(0, height - 48)).clipped()
                .opacity(level == 0 && !isDragging ? 0 : 1)
                .overlay {
                    if level == 0 && !isDragging {
                        HStack { Text(planetName).font(.headline); Spacer(); Text("Drag up for details").font(.caption).foregroundStyle(.secondary) }.padding(.horizontal,14)
                    }
                }
        }
        .frame(height: height)
        .background(Color(red:0.06,green:0.09,blue:0.14))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.12)).frame(height: 1) }
    }
    private var handle: some View {
        Button {
            onInteraction()
            withAnimation(.easeInOut(duration: 0.22)) { level = level == 2 ? 0 : 2 }
        } label: {
            Capsule().fill(.white.opacity(0.6)).frame(width: 50, height: 6)
                .frame(maxWidth: .infinity).frame(height: 48).contentShape(Rectangle())
        }.buttonStyle(.plain)
        .accessibilityLabel(level == 2 ? "Collapse planet panel" : "Expand planet panel")
        .highPriorityGesture(DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { value in
                if !isDragging { onInteraction() }
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) { isDragging = true; drag = value.translation.height }
            }
            .onEnded { value in
                let target = PanelMotion.targetLevel(level: level, predictedTranslation: value.predictedEndTranslation.height, heights: heights)
                withAnimation(.easeInOut(duration: 0.22)) { level = target; drag = 0; isDragging = false }
            })
    }
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
            else { RemasteredFighter().frame(width:48,height:52) }
        }.frame(width:46,height:50)
    }
    func fleetMarker(title:String,count:Int,color:Color) -> some View {
        VStack(spacing:1) {
            HStack(spacing:3) {
                VStack(spacing:1) { ForEach(0..<2,id:\.self) { _ in HStack(spacing:1) { ForEach(0..<2,id:\.self) { _ in RemasteredFighter().frame(width:13,height:14) } } } }
                Text("\(count)").font(.system(size:15,weight:.heavy,design:.monospaced)).foregroundStyle(.black)
            }
            Text(title).font(.system(size:8,weight:.bold)).foregroundStyle(color)
        }.accessibilityElement(children:.combine)
    }
}
// Vector artwork stays crisp at both the battle and fleet-counter sizes.
struct RemasteredFighter: View {
    var body: some View {
        Canvas { context, size in
            let sx = size.width / 100, sy = size.height / 100
            context.scaleBy(x: sx, y: sy)
            func path(_ points: [(CGFloat, CGFloat)]) -> Path {
                var p = Path(); p.move(to: CGPoint(x: points[0].0, y: points[0].1))
                for point in points.dropFirst() { p.addLine(to: CGPoint(x: point.0, y: point.1)) }
                p.closeSubpath(); return p
            }
            let silhouette = path([(8,39),(27,25),(29,6),(36,17),(45,32),(69,37),(80,52),(93,90),(58,80),(23,67),(8,53)])
            context.fill(silhouette, with: .color(Color(red: 0.08, green: 0.10, blue: 0.13)))
            context.stroke(silhouette, with: .color(.black), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
            let wing = path([(12,42),(30,29),(43,38),(70,48),(86,84),(57,74),(23,62),(12,51)])
            context.fill(wing, with: .linearGradient(Gradient(colors: [Color(white: 0.86), Color(white: 0.48), Color(white: 0.23)]), startPoint: CGPoint(x: 12,y: 30), endPoint: CGPoint(x: 80,y: 83)))
            context.stroke(wing, with: .color(Color(white: 0.15)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            let fin = path([(30,10),(42,34),(38,49),(30,39)])
            context.fill(fin, with: .color(Color(white: 0.24)))
            context.stroke(fin, with: .color(.black), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            let canopy = path([(43,35),(65,40),(72,53),(56,51)])
            context.fill(canopy, with: .linearGradient(Gradient(colors: [Color(white: 0.7),Color(white: 0.3)]), startPoint: CGPoint(x: 45,y: 35), endPoint: CGPoint(x: 67,y: 53)))
            context.stroke(canopy, with: .color(.black.opacity(0.75)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            let light = path([(57,55),(68,57),(73,65),(63,65)])
            context.fill(light, with: .color(Color(red: 1,green: 0.89,blue: 0.12)))
            context.stroke(light, with: .color(Color(red: 0.37,green: 0.30,blue: 0.02)), style: StrokeStyle(lineWidth: 1.3, lineJoin: .round))
        }.accessibilityHidden(true)
    }
}
struct ClassicBattleShip: Shape {
    func path(in rect:CGRect) -> Path {
        var p = Path(); p.move(to:CGPoint(x:rect.minX+rect.width*0.08,y:rect.minY+rect.height*0.36))
        p.addLines([CGPoint(x:rect.minX+rect.width*0.3,y:rect.minY+rect.height*0.15),CGPoint(x:rect.minX+rect.width*0.33,y:rect.minY),CGPoint(x:rect.minX+rect.width*0.48,y:rect.minY+rect.height*0.30),CGPoint(x:rect.minX+rect.width*0.75,y:rect.minY+rect.height*0.4),CGPoint(x:rect.maxX,y:rect.maxY),CGPoint(x:rect.minX+rect.width*0.53,y:rect.minY+rect.height*0.77),CGPoint(x:rect.minX+rect.width*0.13,y:rect.minY+rect.height*0.63)]);p.closeSubpath();return p
    }

}

// Center the visible planet, not the uneven transparent canvas in the source art.
struct PlanetArtwork: View {
    let id: Int
    let size: CGFloat
    var body: some View {
        let variant = id % 4
        let horizontal: CGFloat = variant == 0 || variant == 2 ? -0.05 : 0.05
        let vertical: CGFloat = variant < 2 ? -0.025 : 0.03
        Image("Planet\(variant)").resizable().aspectRatio(contentMode:.fit)
            .frame(width:size,height:size).scaleEffect(1.15)
            .offset(x: size * horizontal, y: size * vertical)
            .frame(width:size,height:size).clipped()
    }
}
struct PlanetPortrait: View {
    let planet: Planet
    var size: CGFloat = 86
    var body: some View {
        ZStack {
            PlanetArtwork(id:planet.id, size:size)
            if planet.home { Image(systemName:"crown.fill").font(.system(size:16)).foregroundStyle(.yellow).shadow(color:.black,radius:2).offset(y:3) }
        }.accessibilityLabel("Class \(String(UnicodeScalar(65+planet.grade)!)) planet")
    }
}
struct BuildingSlots: View {
    let planet: Planet
    let gold: Int
    let onBuild: (Bool) -> Void
    let onSell: (Int) -> Void
    private let columns = [GridItem(.fixed(64),spacing:0), GridItem(.fixed(16),spacing:0)] + Array(repeating: GridItem(.fixed(64),spacing:6),count:5)
    var body: some View {
        let factories = FacilityAccounting.costs(existing:planet.factoryCosts,count:planet.industry,home:planet.home,research:false)
        let labs = FacilityAccounting.costs(existing:planet.labCosts,count:planet.research,home:planet.home,research:true)
        let refunds = factories + labs
        let order = FacilityAccounting.displayOrder(factoryCosts:factories,labCosts:labs)
        ScrollView(.horizontal, showsIndicators: true) {
            LazyVGrid(columns:columns,alignment:.leading,spacing:5) {
                ForEach(0..<14,id:\.self) { cell in
                    let column = cell % 7
                    let row = cell / 7
                    if column == 0 {
                        let research = row == 1
                        let price = research ? FacilityAccounting.labPrice : FacilityAccounting.factoryPrice
                        Button { onBuild(research) } label: {
                            tile(icon:research ? "atom" : "building.2.fill", title:research ? "LAB +" : "FACT +", detail:"\(price)", color:research ? .cyan : .orange, active:true)
                        }.buttonStyle(.plain)
                            .disabled(gold < price || planet.industry + planet.research >= planet.capacity)
                            .opacity(gold < price || planet.industry + planet.research >= planet.capacity ? 0.45 : 1)
                            .accessibilityLabel("Build \(research ? "research lab" : "factory") for \(price) gold")
                    } else if column == 1 {
                        Color.clear.frame(width:16,height:64).accessibilityHidden(true)
                    } else {
                        let position = row * 5 + column - 2
                        if position < planet.capacity {
                            if position < order.count {
                                let slot = order[position]
                                let factory = slot < planet.industry
                                let refund = refunds[slot]
                                Button { onSell(slot) } label: {
                                    tile(icon:factory ? "building.2.fill" : "atom", title:factory ? "FACT" : "LAB", detail:refund == 0 ? "FREE" : "+\(refund)", color:factory ? .orange : .cyan, active:true)
                                }.buttonStyle(.plain).accessibilityLabel("Sell \(factory ? "factory" : "research lab") for \(refund) gold")
                            } else {
                                tile(icon:"plus", title:"EMPTY", detail:nil, color:.white.opacity(0.18), active:false).accessibilityLabel("Empty building slot")
                            }
                        } else { Color.clear.frame(width:64,height:64).accessibilityHidden(true) }
                    }
                }
            }.frame(height:133,alignment:.topLeading)
        }
    }
    private func tile(icon:String,title:String,detail:String?,color:Color,active:Bool) -> some View {
        VStack(spacing:2) {
            Image(systemName:icon).font(.system(size:detail == nil ? 28 : 25,weight:.bold)).foregroundStyle(color)
            Text(title).font(.system(size:8,weight:.bold)).foregroundStyle(.secondary)
            if let detail = detail { Text(detail).font(.system(size:8,weight:.bold)).foregroundStyle(.yellow) }
        }.frame(width:64,height:64).background(.white.opacity(active ? 0.08 : 0.025),in:RoundedRectangle(cornerRadius:8)).overlay(RoundedRectangle(cornerRadius:8).stroke(.white.opacity(0.08),lineWidth:1))
    }
}
