import SwiftUI

struct HexAchievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let color: Color
}

enum HexAchievements {
    static let all: [HexAchievement] = [
        HexAchievement(id: "first_capture", title: "First Blood", detail: "Capture your first enemy or neutral hex.", color: HexPalette.crimson),
        HexAchievement(id: "first_win", title: "First Conquest", detail: "Win your first match.", color: HexPalette.gold),
        HexAchievement(id: "campaign_1", title: "Borderland Lord", detail: "Clear all Borderlands campaign maps.", color: HexPalette.success),
        HexAchievement(id: "campaign_2", title: "Heartland Sovereign", detail: "Clear all Heartlands campaign maps.", color: HexPalette.research),
        HexAchievement(id: "campaign_all", title: "Realm Emperor", detail: "Clear every campaign map.", color: HexPalette.crimsonDeep),
        HexAchievement(id: "no_capital_loss", title: "Unbroken Throne", detail: "Win without ever losing your capital army below half.", color: HexPalette.gold),
        HexAchievement(id: "fast_win", title: "Lightning War", detail: "Win a match in 8 turns or fewer.", color: HexPalette.crimson),
        HexAchievement(id: "full_map", title: "Total Domination", detail: "Control 100% of the land on any map.", color: HexPalette.goldDeep),
        HexAchievement(id: "all_factions", title: "Many Banners", detail: "Win at least once with all 5 factions.", color: HexPalette.research),
        HexAchievement(id: "three_star", title: "Flawless", detail: "Earn 3 stars on any campaign map.", color: HexPalette.gold),
        HexAchievement(id: "all_three_star", title: "Perfect Campaign", detail: "Earn 3 stars on every campaign map.", color: HexPalette.crimsonDeep),
        HexAchievement(id: "upgrade_5", title: "War Scholar", detail: "Purchase 5 upgrades across your campaigns.", color: HexPalette.research),
        HexAchievement(id: "hard_win", title: "Iron Will", detail: "Win any Hard difficulty match.", color: HexPalette.danger),
        HexAchievement(id: "skirmish_3ai", title: "Outnumbered", detail: "Win a skirmish against 3 AI factions.", color: HexPalette.crimson),
        HexAchievement(id: "ten_wins", title: "Seasoned Warlord", detail: "Win 10 matches total.", color: HexPalette.gold),
        HexAchievement(id: "big_army", title: "Grand Host", detail: "Field a single stack of 40+ armies.", color: HexPalette.success),
        HexAchievement(id: "comeback", title: "Against the Odds", detail: "Win after being reduced to 2 hexes or fewer.", color: HexPalette.crimsonDeep),
        HexAchievement(id: "builder", title: "Master Builder", detail: "Construct 10 buildings across your matches.", color: HexPalette.gold),
        HexAchievement(id: "dominion_clear", title: "Dominion Warlord", detail: "Clear all Dominion campaign maps.", color: HexPalette.danger),
        HexAchievement(id: "conquest_clear", title: "Conquest Crowned", detail: "Clear all Conquest campaign maps.", color: HexPalette.goldDeep),
        HexAchievement(id: "five_player", title: "Last One Standing", detail: "Win a 5-player free-for-all battle.", color: HexPalette.gold),
        HexAchievement(id: "streak_5", title: "Unstoppable", detail: "Win 5 matches in a row.", color: HexPalette.crimson),
        HexAchievement(id: "veteran_25", title: "War Veteran", detail: "Win 25 matches in total.", color: HexPalette.crimsonDeep),
        HexAchievement(id: "captures_200", title: "Land Grabber", detail: "Capture 200 hexes in total.", color: HexPalette.success)
    ]
    static func def(_ id: String) -> HexAchievement? { all.first(where: { $0.id == id }) }
}

/// Aggregate persisted statistics.
struct HexStats: Codable {
    var totalWins: Int = 0
    var totalMatches: Int = 0
    var totalCaptures: Int = 0
    var buildingsBuilt: Int = 0
    var upgradesBought: Int = 0
    var factionsWonWith: [Int] = []      // faction ids
    var bestStreak: Int = 0
    var currentStreak: Int = 0           // active win streak (reset on loss)
    var fastestWinTurns: Int = 0         // 0 == none

    init() {}

    // Resilient decode: every field falls back to its default when absent, so
    // adding new stat fields never invalidates an existing player's save.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalWins       = (try? c.decode(Int.self,   forKey: .totalWins)) ?? 0
        totalMatches    = (try? c.decode(Int.self,   forKey: .totalMatches)) ?? 0
        totalCaptures   = (try? c.decode(Int.self,   forKey: .totalCaptures)) ?? 0
        buildingsBuilt  = (try? c.decode(Int.self,   forKey: .buildingsBuilt)) ?? 0
        upgradesBought  = (try? c.decode(Int.self,   forKey: .upgradesBought)) ?? 0
        factionsWonWith = (try? c.decode([Int].self, forKey: .factionsWonWith)) ?? []
        bestStreak      = (try? c.decode(Int.self,   forKey: .bestStreak)) ?? 0
        currentStreak   = (try? c.decode(Int.self,   forKey: .currentStreak)) ?? 0
        fastestWinTurns = (try? c.decode(Int.self,   forKey: .fastestWinTurns)) ?? 0
    }
}
