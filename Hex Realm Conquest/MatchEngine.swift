import SwiftUI

// ============================================================================
// MatchState — the full serializable state of an in-progress battle. Owner 0
// is always the human player. The engine handles map generation, resource
// income, combat resolution, AI turns, and win/lose detection.
// ============================================================================

enum MatchOutcome: Int, Codable {
    case ongoing, victory, defeat
}

struct CombatLogEntry: Identifiable {
    let id = UUID()
    let text: String
    let positive: Bool
}

struct MatchState: Codable {
    // identity / config
    var isCampaign: Bool
    var campaignMapId: Int       // -1 for skirmish
    var size: MapSize
    var difficulty: Difficulty
    var targetControlPct: Double

    // participants — index 0 is the human
    var players: [MatchPlayer]

    // board
    var tiles: [HexTile]

    // turn bookkeeping
    var turn: Int
    var actionsRemaining: Int
    var outcome: MatchOutcome
    var seed: UInt64
    var rngState: UInt64         // advancing combat RNG

    // ---- derived lookups -------------------------------------------------
    func tileIndex(_ c: HexCoord) -> Int? {
        tiles.firstIndex(where: { $0.coord == c })
    }
    func tile(_ c: HexCoord) -> HexTile? {
        if let i = tileIndex(c) { return tiles[i] }
        return nil
    }
    func ownedCount(_ owner: Int) -> Int {
        tiles.filter { $0.owner == owner }.count
    }
    var landCount: Int {
        tiles.filter { $0.terrain.isPassable }.count
    }
    func controlPct(_ owner: Int) -> Double {
        let land = landCount
        guard land > 0 else { return 0 }
        return Double(tiles.filter { $0.owner == owner && $0.terrain.isPassable }.count) / Double(land)
    }
    func hasCapital(_ owner: Int) -> Bool {
        tiles.contains(where: { $0.owner == owner && $0.isCapital })
    }
    func totalArmies(_ owner: Int) -> Int {
        tiles.filter { $0.owner == owner }.reduce(0) { $0 + $1.armies }
    }
}

// Per-player production yields (used for the HUD preview as well).
struct ProductionPreview {
    var gold: Int
    var armies: Int
}

enum MatchEngine {

    // -- Map generation -----------------------------------------------------
    /// Generate all coords within axial radius (hexagonal map).
    static func coords(radius: Int) -> [HexCoord] {
        var out: [HexCoord] = []
        for q in -radius...radius {
            let r1 = max(-radius, -q - radius)
            let r2 = min(radius, -q + radius)
            for r in r1...r2 {
                out.append(HexCoord(q: q, r: r))
            }
        }
        return out
    }

    static func newMatch(isCampaign: Bool,
                         campaignMapId: Int,
                         size: MapSize,
                         aiCount: Int,
                         difficulty: Difficulty,
                         startGold: Int,
                         targetControlPct: Double,
                         playerFactionId: Int,
                         seed: UInt64) -> MatchState {
        var rng = HexRNG(seed: seed)
        let allCoords = coords(radius: size.radius)

        // Terrain assignment — deterministic via seeded rng.
        var tiles: [HexTile] = allCoords.map { c in
            let roll = rng.int(100)
            let terrain: HexTerrain
            switch roll {
            case 0..<46: terrain = .plains
            case 46..<66: terrain = .forest
            case 66..<82: terrain = .hills
            case 82..<92: terrain = .mountain
            default: terrain = .water
            }
            return HexTile(coord: c, terrain: terrain, owner: -1, armies: 0,
                           isCapital: false, building: .none)
        }

        // Distinct faction ids: player gets the chosen faction; AIs get the rest.
        var available = Factions.all.map { $0.id }.filter { $0 != playerFactionId }
        // shuffle deterministically
        for i in stride(from: available.count - 1, to: 0, by: -1) {
            let j = rng.int(i + 1)
            available.swapAt(i, j)
        }
        var participantFactions = [playerFactionId]
        participantFactions.append(contentsOf: available.prefix(aiCount))

        // Choose capital sites: spread out, on passable land, far apart.
        let landCoords = tiles.enumerated().filter { $0.element.terrain.isPassable }.map { $0.offset }
        var capitalIdxs: [Int] = []
        let needed = participantFactions.count
        var attempts = 0
        while capitalIdxs.count < needed && attempts < 4000 {
            attempts += 1
            let pick = landCoords[rng.int(landCoords.count)]
            let c = tiles[pick].coord
            let minDist = max(2, size.radius - 1)
            let ok = capitalIdxs.allSatisfy { tiles[$0].coord.distance(to: c) >= minDist }
            if ok && !capitalIdxs.contains(pick) {
                capitalIdxs.append(pick)
            }
        }
        // Fallback if not enough spaced sites found.
        if capitalIdxs.count < needed {
            for idx in landCoords where capitalIdxs.count < needed {
                if !capitalIdxs.contains(idx) { capitalIdxs.append(idx) }
            }
        }

        // Assign capitals + starting territory.
        for (pid, idx) in capitalIdxs.enumerated() {
            tiles[idx].owner = pid
            tiles[idx].isCapital = true
            tiles[idx].terrain = (tiles[idx].terrain == .water) ? .plains : tiles[idx].terrain
            let baseArmy = 8 + (pid == 0 ? 0 : difficulty.aiStartArmyBonus)
            tiles[idx].armies = baseArmy
            // give one adjacent owned tile
            let neigh = tiles[idx].coord.neighbors()
            for nc in neigh {
                if let ni = tiles.firstIndex(where: { $0.coord == nc }),
                   tiles[ni].owner == -1, tiles[ni].terrain.isPassable {
                    tiles[ni].owner = pid
                    tiles[ni].armies = 3
                    break
                }
            }
        }

        // Seed some neutral garrisons on passable, unowned land.
        for i in tiles.indices where tiles[i].owner == -1 && tiles[i].terrain.isPassable {
            if rng.int(100) < 55 {
                tiles[i].armies = rng.range(1, 4)
            }
        }

        var players: [MatchPlayer] = []
        for (pid, fid) in participantFactions.enumerated() {
            players.append(MatchPlayer(factionId: fid,
                                       isHuman: pid == 0,
                                       gold: startGold,
                                       eliminated: false,
                                       upgrades: [],
                                       research: 0))
        }

        let baseActions = 3
        let extra = players[0].hasUpgrade(.extraAction) ? 1 : 0

        return MatchState(isCampaign: isCampaign,
                          campaignMapId: campaignMapId,
                          size: size,
                          difficulty: difficulty,
                          targetControlPct: targetControlPct,
                          players: players,
                          tiles: tiles,
                          turn: 1,
                          actionsRemaining: baseActions + extra,
                          outcome: .ongoing,
                          seed: seed,
                          rngState: seed &* 6364136223846793005 &+ 1442695040888963407)
    }

    // -- Production ---------------------------------------------------------
    static func production(_ state: MatchState, owner: Int) -> ProductionPreview {
        guard owner < state.players.count else { return ProductionPreview(gold: 0, armies: 0) }
        let p = state.players[owner]
        let f = Factions.def(p.factionId)
        var gold = 0
        var armies = 0
        let prodMult = p.hasUpgrade(.production) ? 1.25 : 1.0
        let growthExtra = (p.hasUpgrade(.growth) ? 1 : 0) + f.growthBonus
        for t in state.tiles where t.owner == owner {
            gold += t.terrain.goldYield + t.building.goldBonus
            armies += t.terrain.armyGrowth + t.building.growthBonus + growthExtra
        }
        gold = Int(Double(gold) * prodMult * f.goldBonus)
        return ProductionPreview(gold: max(0, gold), armies: max(0, armies))
    }

    /// Apply start-of-turn production to a given owner.
    static func applyProduction(_ state: inout MatchState, owner: Int) {
        let prev = production(state, owner: owner)
        state.players[owner].gold += prev.gold
        // distribute army growth across owned hexes (cap per hex 99)
        var remaining = prev.armies
        // give each owned hex its share, capital gets priority
        let idxs = state.tiles.indices.filter { state.tiles[$0].owner == owner }
        let sorted = idxs.sorted { (state.tiles[$0].isCapital ? 1 : 0) > (state.tiles[$1].isCapital ? 1 : 0) }
        // Distribute one army per hex per sweep, capital(s) first. Terminate when
        // either all growth is placed OR a full sweep finds no room (every owned
        // hex is at the 99 cap), so we never spin forever yet always fill any
        // remaining capacity. Each productive sweep places >= 1 army, so the
        // outer loop runs at most `remaining` times.
        while remaining > 0 && !sorted.isEmpty {
            var placedThisSweep = false
            for idx in sorted where remaining > 0 {
                if state.tiles[idx].armies < 99 {
                    state.tiles[idx].armies += 1
                    remaining -= 1
                    placedThisSweep = true
                }
            }
            if !placedThisSweep { break }
        }
    }

    // -- Combat -------------------------------------------------------------
    struct CombatResult {
        var attackerWon: Bool
        var survivors: Int
        var atkRoll: Double
        var defRoll: Double
    }

    static func effectiveAttack(_ state: MatchState, attackerIdx: Int, armies: Int) -> Double {
        let owner = state.tiles[attackerIdx].owner
        let p = state.players[owner]
        let f = Factions.def(p.factionId)
        var mult = f.attackBonus
        if p.hasUpgrade(.attack) { mult *= 1.2 }
        return Double(armies) * mult
    }

    static func effectiveDefense(_ state: MatchState, defenderIdx: Int) -> Double {
        let t = state.tiles[defenderIdx]
        var mult = t.terrain.defenseBonus * t.building.defenseBonus
        if t.owner >= 0 {
            let p = state.players[t.owner]
            let f = Factions.def(p.factionId)
            mult *= f.defenseBonus
            if p.hasUpgrade(.defense) { mult *= 1.2 }
        }
        var def = Double(t.armies) * mult
        if t.isCapital { def *= 1.15 }
        return def
    }

    /// Resolve attack: attacker sends (armies-1 stay? No — sends all but leaves
    /// 1 behind) into an adjacent enemy/neutral tile. Returns updated state via inout.
    /// Returns a log entry string + whether attacker (human=owner index) involved.
    @discardableResult
    static func resolveAttack(_ state: inout MatchState, from: HexCoord, to: HexCoord) -> CombatLogEntry? {
        guard let ai = state.tileIndex(from), let di = state.tileIndex(to) else { return nil }
        let attackerOwner = state.tiles[ai].owner
        guard attackerOwner >= 0 else { return nil }
        guard state.tiles[ai].armies >= 2 else { return nil }
        guard state.tiles[di].terrain.isPassable else { return nil }
        guard from.distance(to: to) == 1 else { return nil }

        let movingArmies = state.tiles[ai].armies - 1   // leave 1 to hold origin
        let defenderOwner = state.tiles[di].owner

        // RNG roll bounded — each side gets a 0.80..1.20 multiplier.
        var rng = HexRNG(seed: state.rngState)
        let atkRoll = 0.80 + rng.double() * 0.40
        let defRoll = 0.80 + rng.double() * 0.40
        state.rngState = state.rngState &+ rng.nextU64()

        var atkPower = effectiveAttack(state, attackerIdx: ai, armies: movingArmies) * atkRoll
        var defPower = effectiveDefense(state, defenderIdx: di) * defRoll
        // AI defending gets a small difficulty bias when defender is AI vs human attack.
        if defenderOwner > 0 && attackerOwner == 0 {
            defPower *= state.difficulty.aiCombatBias
        }
        if attackerOwner > 0 && defenderOwner == 0 {
            atkPower *= state.difficulty.aiCombatBias
        }

        let attackerName = Factions.def(state.players[attackerOwner].factionId).name
        let targetName = defenderOwner < 0 ? "neutral" : Factions.def(state.players[defenderOwner].factionId).name

        if atkPower > defPower {
            // attacker wins — surviving armies = movingArmies scaled by margin
            let ratio = defPower / max(atkPower, 0.001)
            var survivors = Int((Double(movingArmies) * (1.0 - ratio)).rounded())
            survivors = max(1, min(movingArmies, survivors))
            state.tiles[ai].armies = 1
            state.tiles[di].owner = attackerOwner
            state.tiles[di].armies = survivors
            // capturing a non-capital removes capital flag only if it was enemy capital
            let wasCapital = state.tiles[di].isCapital
            let positive = attackerOwner == 0
            let txt = wasCapital
                ? "\(attackerName) seized a CAPITAL from \(targetName)!"
                : "\(attackerName) captured a hex from \(targetName)."
            return CombatLogEntry(text: txt, positive: positive)
        } else {
            // defender holds — attacker loses most of moving force
            let ratio = atkPower / max(defPower, 0.001)
            let defLost = Int((Double(state.tiles[di].armies) * ratio * 0.6).rounded())
            state.tiles[di].armies = max(1, state.tiles[di].armies - defLost)
            // attacker keeps 1 at origin (already), loses the moving force
            state.tiles[ai].armies = 1
            let positive = defenderOwner == 0
            let txt = "\(attackerName)'s assault on \(targetName) was repelled."
            return CombatLogEntry(text: txt, positive: positive)
        }
    }

    /// Reinforce: move armies from an owned hex into an adjacent owned hex.
    @discardableResult
    static func reinforce(_ state: inout MatchState, from: HexCoord, to: HexCoord) -> Bool {
        guard let ai = state.tileIndex(from), let di = state.tileIndex(to) else { return false }
        guard state.tiles[ai].owner == state.tiles[di].owner, state.tiles[ai].owner >= 0 else { return false }
        guard from.distance(to: to) == 1 else { return false }
        guard state.tiles[ai].armies >= 2 else { return false }
        let move = state.tiles[ai].armies - 1
        state.tiles[ai].armies = 1
        state.tiles[di].armies = min(99, state.tiles[di].armies + move)
        return true
    }

    static func reinforceCost(_ state: MatchState, owner: Int) -> Int {
        state.players[owner].hasUpgrade(.cheapReinforce) ? 1 : 2
    }

    // -- Win / lose detection ----------------------------------------------
    static func updateOutcome(_ state: inout MatchState) {
        // mark eliminated players (no capital AND no hexes)
        for pid in state.players.indices {
            if !state.hasCapital(pid) && state.ownedCount(pid) == 0 {
                state.players[pid].eliminated = true
            } else if !state.hasCapital(pid) {
                // capital lost but still has hexes — still considered defeated for capital-based loss
                state.players[pid].eliminated = state.players[pid].eliminated
            }
        }
        // player (0) loses if capital captured
        if !state.hasCapital(0) {
            state.outcome = .defeat
            return
        }
        // win if all AI capitals gone OR control threshold reached
        let aiCapitalsRemaining = state.players.indices.dropFirst().contains { pid in
            state.hasCapital(pid)
        }
        if !aiCapitalsRemaining {
            state.outcome = .victory
            return
        }
        if state.controlPct(0) >= state.targetControlPct {
            state.outcome = .victory
            return
        }
        state.outcome = .ongoing
    }

    // -- AI turn ------------------------------------------------------------
    /// Runs the full turn for one AI faction (owner id >= 1). Heuristic:
    ///  - spend gold to buy a building or reinforce frontier
    ///  - perform up to N actions: attack the weakest beneficial adjacent hex,
    ///    prioritizing enemy capitals and weak neutrals; otherwise consolidate.
    static func runAITurn(_ state: inout MatchState, owner: Int, log: inout [CombatLogEntry]) {
        guard owner < state.players.count, !state.players[owner].eliminated else { return }
        applyProduction(&state, owner: owner)

        // Buy an upgrade occasionally if affordable (hard AI smarter).
        maybeAIBuy(&state, owner: owner)

        var actions = 3 + (state.players[owner].hasUpgrade(.extraAction) ? 1 : 0)
        var safety = 0
        while actions > 0 && safety < 40 {
            safety += 1
            // find best attack move
            guard let move = bestAIMove(state, owner: owner) else { break }
            if move.isAttack {
                if let entry = resolveAttack(&state, from: move.from, to: move.to) {
                    log.append(entry)
                }
            } else {
                _ = reinforce(&state, from: move.from, to: move.to)
            }
            actions -= 1
            updateOutcome(&state)
            if state.outcome != .ongoing { break }
        }
    }

    private static func maybeAIBuy(_ state: inout MatchState, owner: Int) {
        var rng = HexRNG(seed: state.rngState &+ UInt64(owner * 7919))
        state.rngState = state.rngState &+ rng.nextU64()
        let gold = state.players[owner].gold
        // chance to invest scales with difficulty
        let invest = state.difficulty == .hard ? 70 : (state.difficulty == .normal ? 50 : 30)
        if rng.int(100) < invest {
            // try to fortify the capital or a frontier hex
            if let capIdx = state.tiles.indices.first(where: { state.tiles[$0].owner == owner && state.tiles[$0].isCapital }) {
                if state.tiles[capIdx].building == .none && gold >= BuildingKind.fort.cost {
                    state.tiles[capIdx].building = .fort
                    state.players[owner].gold -= BuildingKind.fort.cost
                    return
                }
            }
            // otherwise build a farm on a safe interior plains hex
            if let farmIdx = state.tiles.indices.first(where: {
                state.tiles[$0].owner == owner && state.tiles[$0].building == .none && state.tiles[$0].terrain == .plains
            }), gold >= BuildingKind.farm.cost {
                state.tiles[farmIdx].building = .farm
                state.players[owner].gold -= BuildingKind.farm.cost
            }
        }
    }

    struct AIMove { var from: HexCoord; var to: HexCoord; var isAttack: Bool; var score: Double }

    private static func bestAIMove(_ state: MatchState, owner: Int) -> AIMove? {
        var best: AIMove?
        for t in state.tiles where t.owner == owner && t.armies >= 2 {
            let moving = t.armies - 1
            for nc in t.coord.neighbors() {
                guard let ni = state.tileIndex(nc) else { continue }
                let target = state.tiles[ni]
                guard target.terrain.isPassable else { continue }
                if target.owner == owner {
                    // reinforce candidate: push toward a frontier hex (adjacent to enemy)
                    let isFrontier = nc.neighbors().contains { neighbor in
                        if let idx = state.tileIndex(neighbor) {
                            let o = state.tiles[idx].owner
                            return o != owner
                        }
                        return false
                    }
                    if isFrontier && t.armies > 4 {
                        let score = 0.5 + Double(moving) * 0.02
                        if best == nil || score > best!.score {
                            best = AIMove(from: t.coord, to: nc, isAttack: false, score: score)
                        }
                    }
                } else {
                    // attack candidate — estimate win odds
                    var fakeAtk = MatchEngine.effectiveAttack(state, attackerIdx: state.tileIndex(t.coord)!, armies: moving)
                    let def = MatchEngine.effectiveDefense(state, defenderIdx: ni)
                    fakeAtk *= state.difficulty.aiCombatBias
                    let margin = fakeAtk - def
                    if margin > 0 {
                        var score = 1.0 + margin * 0.05
                        if target.isCapital { score += 5.0 }     // prize capitals
                        if target.owner < 0 { score += 0.5 }     // easy neutral expansion
                        if best == nil || score > best!.score {
                            best = AIMove(from: t.coord, to: nc, isAttack: true, score: score)
                        }
                    }
                }
            }
        }
        return best
    }

    // -- End the player's turn (run all AI, then start new turn) ------------
    static func endPlayerTurn(_ state: inout MatchState, log: inout [CombatLogEntry]) {
        updateOutcome(&state)
        if state.outcome != .ongoing { return }
        // AI turns
        for pid in state.players.indices.dropFirst() {
            if state.players[pid].eliminated { continue }
            runAITurn(&state, owner: pid, log: &log)
            updateOutcome(&state)
            if state.outcome != .ongoing { return }
        }
        // begin player's new turn
        state.turn += 1
        applyProduction(&state, owner: 0)
        state.actionsRemaining = 3 + (state.players[0].hasUpgrade(.extraAction) ? 1 : 0)
        updateOutcome(&state)
    }

    // -- Star rating --------------------------------------------------------
    static func stars(turn: Int, par: Int, good: Int) -> Int {
        if turn <= par { return 3 }
        if turn <= good { return 2 }
        return 1
    }
}
