import SwiftUI

// ============================================================================
// HexRealmStore — the single ObservableObject persisting all progress under the
// "hrc." UserDefaults namespace: campaign stars, unlocked achievements, stats,
// settings, and an optional in-progress saved match.
// ============================================================================

struct SavedProgress: Codable {
    var campaignStars: [Int: Int] = [:]      // mapId -> stars (0 if not cleared)
    var unlockedAchievements: [String] = []
    var stats: HexStats = HexStats()
    var soundOn: Bool = true
    var hapticsOn: Bool = true
    var onboardingDone: Bool = false
}

final class HexRealmStore: ObservableObject {
    @Published var progress: SavedProgress
    @Published var activeMatch: MatchState?       // in-progress (campaign or skirmish)
    @Published var activeIsCampaign: Bool = false
    @Published var combatLog: [CombatLogEntry] = []
    @Published var lastUnlocked: [String] = []

    // tracking flags for achievement evaluation within a single match
    private var matchMinHexes: Int = 999
    private var matchCapitalDipped: Bool = false

    private let progressKey = "hrc.progress.v1"
    private let matchKey = "hrc.activeMatch.v1"
    private let matchCampaignKey = "hrc.activeMatchIsCampaign.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: progressKey),
           let p = try? JSONDecoder().decode(SavedProgress.self, from: data) {
            progress = p
        } else {
            progress = SavedProgress()
        }
        // resume saved match if present
        if let data = UserDefaults.standard.data(forKey: matchKey),
           let m = try? JSONDecoder().decode(MatchState.self, from: data),
           m.outcome == .ongoing {
            activeMatch = m
            activeIsCampaign = UserDefaults.standard.bool(forKey: matchCampaignKey)
        }
    }

    // -- Persistence --------------------------------------------------------
    func saveProgress() {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
    }

    func saveActiveMatch() {
        guard let m = activeMatch, m.outcome == .ongoing else {
            UserDefaults.standard.removeObject(forKey: matchKey)
            return
        }
        if let data = try? JSONEncoder().encode(m) {
            UserDefaults.standard.set(data, forKey: matchKey)
            UserDefaults.standard.set(activeIsCampaign, forKey: matchCampaignKey)
        }
    }

    func clearActiveMatch() {
        activeMatch = nil
        combatLog = []
        UserDefaults.standard.removeObject(forKey: matchKey)
    }

    func resetAll() {
        progress = SavedProgress()
        activeMatch = nil
        combatLog = []
        UserDefaults.standard.removeObject(forKey: progressKey)
        UserDefaults.standard.removeObject(forKey: matchKey)
        UserDefaults.standard.removeObject(forKey: matchCampaignKey)
        saveProgress()
    }

    // -- Campaign gating ----------------------------------------------------
    func stars(for mapId: Int) -> Int { progress.campaignStars[mapId] ?? 0 }
    func isCleared(_ mapId: Int) -> Bool { (progress.campaignStars[mapId] ?? 0) > 0 }
    func isUnlocked(_ mapId: Int) -> Bool {
        if mapId == 0 { return true }
        return isCleared(mapId - 1)
    }

    // -- Match lifecycle ----------------------------------------------------
    func startCampaign(_ def: CampaignMapDef, factionId: Int) {
        let m = MatchEngine.newMatch(isCampaign: true,
                                     campaignMapId: def.id,
                                     size: def.size,
                                     aiCount: def.aiCount,
                                     difficulty: def.difficulty,
                                     startGold: def.startGold,
                                     targetControlPct: def.targetControlPct,
                                     playerFactionId: factionId,
                                     seed: def.seed)
        activeMatch = m
        activeIsCampaign = true
        combatLog = []
        matchMinHexes = m.ownedCount(0)
        matchCapitalDipped = false
        saveActiveMatch()
    }

    func startSkirmish(size: MapSize, aiCount: Int, difficulty: Difficulty, factionId: Int) {
        // skirmish seed varies per launch so layouts differ
        let seed = UInt64(Date().timeIntervalSince1970) ^ UInt64(factionId &* 2654435761 &+ aiCount &* 40503)
        let m = MatchEngine.newMatch(isCampaign: false,
                                     campaignMapId: -1,
                                     size: size,
                                     aiCount: aiCount,
                                     difficulty: difficulty,
                                     startGold: 16,
                                     targetControlPct: 0.85,
                                     playerFactionId: factionId,
                                     seed: seed == 0 ? 12345 : seed)
        activeMatch = m
        activeIsCampaign = false
        combatLog = []
        matchMinHexes = m.ownedCount(0)
        matchCapitalDipped = false
        saveActiveMatch()
    }

    /// Mutate the active match safely, then republish + persist + track.
    func mutate(_ block: (inout MatchState) -> Void) {
        guard var m = activeMatch else { return }
        let beforeCaptures = m.ownedCount(0)
        block(&m)
        let afterCaptures = m.ownedCount(0)
        if afterCaptures > beforeCaptures {
            progress.stats.totalCaptures += (afterCaptures - beforeCaptures)
            if !progress.unlockedAchievements.contains("first_capture") {
                unlock("first_capture")
            }
            if progress.stats.totalCaptures >= 200 { unlock("captures_200") }
        }
        // track lowest hex count for comeback achievement
        matchMinHexes = min(matchMinHexes, m.ownedCount(0))
        // track capital army dip
        if let cap = m.tiles.first(where: { $0.owner == 0 && $0.isCapital }) {
            if cap.armies < 5 { matchCapitalDipped = true }
        }
        // big army achievement
        if m.tiles.contains(where: { $0.owner == 0 && $0.armies >= 40 }) {
            unlock("big_army")
        }
        // full map
        if m.controlPct(0) >= 0.999 {
            unlock("full_map")
        }
        activeMatch = m
        if m.outcome == .ongoing {
            saveActiveMatch()
        } else {
            finishMatch(m)
        }
        objectWillChange.send()
    }

    func recordBuilding() {
        progress.stats.buildingsBuilt += 1
        if progress.stats.buildingsBuilt >= 10 { unlock("builder") }
        saveProgress()
    }

    func recordUpgrade() {
        progress.stats.upgradesBought += 1
        if progress.stats.upgradesBought >= 5 { unlock("upgrade_5") }
        saveProgress()
    }

    // -- Resolve a finished match ------------------------------------------
    private func finishMatch(_ m: MatchState) {
        progress.stats.totalMatches += 1
        if m.outcome == .victory {
            progress.stats.totalWins += 1
            progress.stats.currentStreak += 1
            progress.stats.bestStreak = max(progress.stats.bestStreak, progress.stats.currentStreak)
            let factionId = m.players[0].factionId

            unlock("first_win")
            if !progress.stats.factionsWonWith.contains(factionId) {
                progress.stats.factionsWonWith.append(factionId)
            }
            if Set(progress.stats.factionsWonWith).count >= Factions.all.count {
                unlock("all_factions")
            }
            if progress.stats.totalWins >= 10 { unlock("ten_wins") }
            if progress.stats.totalWins >= 25 { unlock("veteran_25") }
            if progress.stats.currentStreak >= 5 { unlock("streak_5") }
            if m.players.count >= 5 { unlock("five_player") }
            if m.turn <= 8 { unlock("fast_win") }
            if progress.stats.fastestWinTurns == 0 || m.turn < progress.stats.fastestWinTurns {
                progress.stats.fastestWinTurns = m.turn
            }
            if m.difficulty == .hard { unlock("hard_win") }
            if !matchCapitalDipped { unlock("no_capital_loss") }
            if matchMinHexes <= 2 { unlock("comeback") }
            if m.controlPct(0) >= 0.999 { unlock("full_map") }

            if !m.isCampaign && m.players.count - 1 >= 3 {
                unlock("skirmish_3ai")
            }

            // campaign stars + unlock chain
            if m.isCampaign, let def = Campaign.map(m.campaignMapId) {
                let s = MatchEngine.stars(turn: m.turn, par: def.parTurns, good: def.goodTurns)
                let existing = progress.campaignStars[def.id] ?? 0
                progress.campaignStars[def.id] = max(existing, s)
                if s >= 3 { unlock("three_star") }
                evaluateCampaignTierAchievements()
            }
        } else {
            // streak ends on any non-victory outcome (defeat / abandoned loss)
            progress.stats.currentStreak = 0
        }
        // Keep `activeMatch` in memory (with its terminal outcome) so MatchView
        // can present the Victory/Defeat overlay; just drop the persisted save so
        // a finished match is never resumed. The overlay's Continue/Retry path
        // calls clearActiveMatch()/startX which fully clears in-memory state.
        UserDefaults.standard.removeObject(forKey: matchKey)
        UserDefaults.standard.removeObject(forKey: matchCampaignKey)
        saveProgress()
    }

    private func evaluateCampaignTierAchievements() {
        let borderlands = [0, 1, 2, 3]
        let heartlands = [4, 5, 6, 7]
        let dominion = [8, 9, 10, 11]
        let conquest = [12, 13, 14, 15]
        if borderlands.allSatisfy({ isCleared($0) }) { unlock("campaign_1") }
        if heartlands.allSatisfy({ isCleared($0) }) { unlock("campaign_2") }
        if dominion.allSatisfy({ isCleared($0) }) { unlock("dominion_clear") }
        if conquest.allSatisfy({ isCleared($0) }) { unlock("conquest_clear") }
        if Campaign.maps.allSatisfy({ isCleared($0.id) }) { unlock("campaign_all") }
        if Campaign.maps.allSatisfy({ (progress.campaignStars[$0.id] ?? 0) >= 3 }) {
            unlock("all_three_star")
        }
    }

    // -- Achievements -------------------------------------------------------
    func unlock(_ id: String) {
        guard !progress.unlockedAchievements.contains(id) else { return }
        progress.unlockedAchievements.append(id)
        lastUnlocked = [id]
        saveProgress()
    }
    func isUnlockedAchievement(_ id: String) -> Bool {
        progress.unlockedAchievements.contains(id)
    }

    // -- Scene phase --------------------------------------------------------
    func handleBackground() {
        saveActiveMatch()
        saveProgress()
    }
}
