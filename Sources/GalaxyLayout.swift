import Foundation

enum GalaxyLayout {
    static let choices = [12, 16, 20, 24]
    static let names = ["Sol", "Vega", "Sirius", "Altair", "Deneb", "Rigel", "Arcturus", "Procyon", "Capella", "Spica", "Polaris", "Antares", "Aldebaran", "Bellatrix", "Regulus", "Orion", "Pollux", "Castor", "Mira", "Canopus", "Betelgeuse", "Fomalhaut", "Hadar", "Sadr"]
    static let positions: [(Double, Double)] = [
        (0.11,0.18),(0.89,0.82),(0.31,0.12),(0.52,0.10),(0.76,0.19),(0.15,0.39),(0.37,0.35),(0.59,0.31),(0.84,0.42),(0.12,0.67),(0.34,0.59),(0.55,0.55),(0.73,0.66),(0.25,0.85),(0.48,0.82),(0.69,0.89),
        (0.14,0.52),(0.46,0.22),(0.86,0.56),(0.35,0.73),(0.65,0.16),(0.62,0.74),(0.22,0.27),(0.48,0.44)
    ]
    static func normalizedCount(_ count: Int) -> Int { choices.contains(count) ? count : 16 }
    static func position(index: Int, count: Int) -> (Double, Double) {
        // In the smaller map, keep a bridge to Vega within starting fleet range.
        positions[count == 12 && index == 11 ? 12 : index]
    }
}
