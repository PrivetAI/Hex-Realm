import SwiftUI

// ============================================================================
// Deterministic RNG (seedable) so campaign maps are reproducible and combat
// rolls are bounded. SplitMix64.
// ============================================================================
struct HexRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func nextU64() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    /// Integer in [0, n).
    mutating func int(_ n: Int) -> Int {
        guard n > 0 else { return 0 }
        return Int(nextU64() % UInt64(n))
    }
    /// Double in [0,1).
    mutating func double() -> Double {
        return Double(nextU64() >> 11) * (1.0 / 9007199254740992.0)
    }
    mutating func range(_ lo: Int, _ hi: Int) -> Int {
        guard hi > lo else { return lo }
        return lo + int(hi - lo + 1)
    }
}

// ============================================================================
// Hex coordinates — axial (q, r). Pointy-top layout.
// ============================================================================
struct HexCoord: Codable, Hashable {
    var q: Int
    var r: Int

    static let directions: [HexCoord] = [
        HexCoord(q: 1, r: 0), HexCoord(q: 1, r: -1), HexCoord(q: 0, r: -1),
        HexCoord(q: -1, r: 0), HexCoord(q: -1, r: 1), HexCoord(q: 0, r: 1)
    ]
    func neighbors() -> [HexCoord] {
        HexCoord.directions.map { HexCoord(q: q + $0.q, r: r + $0.r) }
    }
    func distance(to o: HexCoord) -> Int {
        (abs(q - o.q) + abs(q + r - o.q - o.r) + abs(r - o.r)) / 2
    }
}

enum HexTerrain: Int, Codable, CaseIterable {
    case plains, forest, hills, mountain, water

    var name: String {
        switch self {
        case .plains: return "Plains"
        case .forest: return "Forest"
        case .hills: return "Hills"
        case .mountain: return "Mountain"
        case .water: return "Water"
        }
    }
    /// Defensive multiplier applied to the defender's strength.
    var defenseBonus: Double {
        switch self {
        case .plains: return 1.0
        case .forest: return 1.25
        case .hills: return 1.4
        case .mountain: return 1.7
        case .water: return 1.0
        }
    }
    /// Base gold produced per turn by an owned hex of this terrain.
    var goldYield: Int {
        switch self {
        case .plains: return 3
        case .forest: return 2
        case .hills: return 2
        case .mountain: return 1
        case .water: return 0
        }
    }
    /// Base army growth per turn for an owned hex of this terrain.
    var armyGrowth: Int {
        switch self {
        case .plains: return 2
        case .forest: return 1
        case .hills: return 1
        case .mountain: return 1
        case .water: return 0
        }
    }
    var isPassable: Bool { self != .water }
    var fill: Color {
        switch self {
        case .plains: return HexPalette.terrainPlains
        case .forest: return HexPalette.terrainForest
        case .hills: return HexPalette.terrainHills
        case .mountain: return HexPalette.terrainMountain
        case .water: return HexPalette.terrainWater
        }
    }
}

// ============================================================================
// Factions
// ============================================================================
struct FactionDef: Identifiable {
    let id: Int
    let name: String
    let blurb: String
    let color: Color
    // small distinct bonuses
    let goldBonus: Double   // multiplier on gold production
    let attackBonus: Double // multiplier on attack strength
    let defenseBonus: Double// extra multiplier on defense
    let growthBonus: Int    // flat extra army growth per owned hex per turn
}

enum Factions {
    // id 0 reserved-ish but used as player default; all selectable.
    static let all: [FactionDef] = [
        FactionDef(id: 0, name: "Crimson Order",
                   blurb: "Disciplined legions. +15% attack strength.",
                   color: HexPalette.crimson,
                   goldBonus: 1.0, attackBonus: 1.15, defenseBonus: 1.0, growthBonus: 0),
        FactionDef(id: 1, name: "Azure Pact",
                   blurb: "Wealthy traders. +20% gold income.",
                   color: HexPalette.research,
                   goldBonus: 1.2, attackBonus: 1.0, defenseBonus: 1.0, growthBonus: 0),
        FactionDef(id: 2, name: "Golden Host",
                   blurb: "Prolific recruiters. +1 army growth per hex.",
                   color: HexPalette.gold,
                   goldBonus: 1.0, attackBonus: 1.0, defenseBonus: 1.0, growthBonus: 1),
        FactionDef(id: 3, name: "Verdant Clan",
                   blurb: "Hardened defenders. +20% defensive strength.",
                   color: HexPalette.success,
                   goldBonus: 1.0, attackBonus: 1.0, defenseBonus: 1.2, growthBonus: 0),
        FactionDef(id: 4, name: "Slate Dominion",
                   blurb: "Balanced realm. Modest bonus to all output.",
                   color: Color(red: 0.45, green: 0.42, blue: 0.50),
                   goldBonus: 1.08, attackBonus: 1.05, defenseBonus: 1.05, growthBonus: 0)
    ]
    static func def(_ id: Int) -> FactionDef {
        all.first(where: { $0.id == id }) ?? all[0]
    }
    /// Visual color for an owner id; -1 == neutral.
    static func color(_ owner: Int) -> Color {
        owner < 0 ? HexPalette.neutralFill : def(owner).color
    }
}

// ============================================================================
// Tech / upgrade tree — applied to the active match for the owning player.
// ============================================================================
enum UpgradeKind: Int, Codable, CaseIterable, Identifiable {
    case production, attack, defense, growth, extraAction, cheapReinforce
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .production: return "Mint Reform"
        case .attack: return "Steel Edge"
        case .defense: return "Stone Walls"
        case .growth: return "Conscription"
        case .extraAction: return "War Council"
        case .cheapReinforce: return "Supply Lines"
        }
    }
    var detail: String {
        switch self {
        case .production: return "+25% gold from all owned hexes."
        case .attack: return "+20% attack strength in combat."
        case .defense: return "+20% defensive strength."
        case .growth: return "+1 army growth on every owned hex."
        case .extraAction: return "One extra action per turn."
        case .cheapReinforce: return "Reinforcing costs 1 less gold."
        }
    }
    var cost: Int {
        switch self {
        case .production: return 30
        case .attack: return 35
        case .defense: return 35
        case .growth: return 40
        case .extraAction: return 55
        case .cheapReinforce: return 25
        }
    }
}

// ============================================================================
// Map / match definitions
// ============================================================================
enum MapSize: Int, Codable {
    case small, medium, large
    var radius: Int {
        switch self {
        case .small: return 3
        case .medium: return 4
        case .large: return 5
        }
    }
    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

enum Difficulty: Int, Codable {
    case easy, normal, hard
    var label: String {
        switch self {
        case .easy: return "Easy"
        case .normal: return "Normal"
        case .hard: return "Hard"
        }
    }
    /// AI aggressiveness and combat bias.
    var aiCombatBias: Double {
        switch self {
        case .easy: return 0.90
        case .normal: return 1.0
        case .hard: return 1.12
        }
    }
    var aiStartArmyBonus: Int {
        switch self {
        case .easy: return 0
        case .normal: return 1
        case .hard: return 3
        }
    }
}

/// A single tile in a live match.
struct HexTile: Codable {
    var coord: HexCoord
    var terrain: HexTerrain
    var owner: Int        // -1 neutral, 0..n faction id (player is owner 0 in match context)
    var armies: Int
    var isCapital: Bool
    var building: BuildingKind
}

enum BuildingKind: Int, Codable {
    case none, farm, barracks, fort
    var goldBonus: Int { self == .farm ? 2 : 0 }
    var growthBonus: Int { self == .barracks ? 2 : 0 }
    var defenseBonus: Double { self == .fort ? 1.3 : 1.0 }
    var cost: Int {
        switch self {
        case .none: return 0
        case .farm: return 18
        case .barracks: return 22
        case .fort: return 26
        }
    }
    var title: String {
        switch self {
        case .none: return "None"
        case .farm: return "Farm"
        case .barracks: return "Barracks"
        case .fort: return "Fort"
        }
    }
    var detail: String {
        switch self {
        case .none: return ""
        case .farm: return "+2 gold / turn"
        case .barracks: return "+2 army growth / turn"
        case .fort: return "+30% defense"
        }
    }
}

/// Player-facing definition of a participant in the match.
struct MatchPlayer: Codable {
    var factionId: Int
    var isHuman: Bool
    var gold: Int
    var eliminated: Bool
    var upgrades: [Int]   // raw values of UpgradeKind purchased
    var research: Int     // research currency

    func hasUpgrade(_ k: UpgradeKind) -> Bool { upgrades.contains(k.rawValue) }
}

// A campaign map definition (hand-seeded).
struct CampaignMapDef: Identifiable {
    let id: Int
    let name: String
    let tier: String
    let seed: UInt64
    let size: MapSize
    let aiCount: Int
    let difficulty: Difficulty
    let startGold: Int
    let targetControlPct: Double   // win if controlling >= this fraction
    let parTurns: Int              // for 3-star rating
    let goodTurns: Int             // for 2-star rating
}

enum Campaign {
    static let maps: [CampaignMapDef] = [
        // Tier I — Borderlands (Easy)
        CampaignMapDef(id: 0, name: "First Banner", tier: "Borderlands", seed: 101, size: .small, aiCount: 1, difficulty: .easy, startGold: 14, targetControlPct: 0.75, parTurns: 8, goodTurns: 12),
        CampaignMapDef(id: 1, name: "Riverford", tier: "Borderlands", seed: 202, size: .small, aiCount: 1, difficulty: .easy, startGold: 14, targetControlPct: 0.78, parTurns: 9, goodTurns: 13),
        CampaignMapDef(id: 2, name: "Pinewatch", tier: "Borderlands", seed: 303, size: .small, aiCount: 2, difficulty: .easy, startGold: 16, targetControlPct: 0.80, parTurns: 10, goodTurns: 15),
        CampaignMapDef(id: 3, name: "Stone Pass", tier: "Borderlands", seed: 404, size: .medium, aiCount: 2, difficulty: .easy, startGold: 16, targetControlPct: 0.80, parTurns: 12, goodTurns: 17),
        // Tier II — Heartlands (Normal)
        CampaignMapDef(id: 4, name: "Goldvale", tier: "Heartlands", seed: 505, size: .medium, aiCount: 2, difficulty: .normal, startGold: 15, targetControlPct: 0.82, parTurns: 13, goodTurns: 18),
        CampaignMapDef(id: 5, name: "Twin Crowns", tier: "Heartlands", seed: 606, size: .medium, aiCount: 3, difficulty: .normal, startGold: 16, targetControlPct: 0.82, parTurns: 14, goodTurns: 20),
        CampaignMapDef(id: 6, name: "Ashmoor", tier: "Heartlands", seed: 707, size: .medium, aiCount: 3, difficulty: .normal, startGold: 16, targetControlPct: 0.84, parTurns: 15, goodTurns: 21),
        CampaignMapDef(id: 7, name: "Highreach", tier: "Heartlands", seed: 808, size: .large, aiCount: 3, difficulty: .normal, startGold: 17, targetControlPct: 0.84, parTurns: 17, goodTurns: 24),
        // Tier III — Dominion (Hard)
        CampaignMapDef(id: 8, name: "Bloodfens", tier: "Dominion", seed: 909, size: .large, aiCount: 3, difficulty: .hard, startGold: 16, targetControlPct: 0.85, parTurns: 18, goodTurns: 26),
        CampaignMapDef(id: 9, name: "Ironhold", tier: "Dominion", seed: 1010, size: .large, aiCount: 3, difficulty: .hard, startGold: 16, targetControlPct: 0.86, parTurns: 19, goodTurns: 27),
        CampaignMapDef(id: 10, name: "Stormcrown", tier: "Dominion", seed: 1111, size: .large, aiCount: 3, difficulty: .hard, startGold: 15, targetControlPct: 0.88, parTurns: 20, goodTurns: 29),
        CampaignMapDef(id: 11, name: "The Last Realm", tier: "Dominion", seed: 1212, size: .large, aiCount: 3, difficulty: .hard, startGold: 14, targetControlPct: 0.90, parTurns: 22, goodTurns: 31)
    ]
    static func map(_ id: Int) -> CampaignMapDef? { maps.first(where: { $0.id == id }) }
}
