import Foundation

/// Scoring for the set-, game-, inning- and round-based sports.
extension GameSession {
    var setsToWin: Int { max(1, (regulationPeriods + 1) / 2) }

    // MARK: - Rally sports (volleyball, table tennis, badminton)

    func rallyPoint(for side: TeamSide) {
        guard state.phase != .final, let format = rules.rallyFormat else { return }
        if format.sideOut, let server = state.possession, side != server {
            sideOut(rallyWinner: side, doubles: format.doubles)
            return
        }
        let limit = undoLimit
        let setsNeeded = setsToWin
        let isDecidingSet = state.period >= regulationPeriods && regulationPeriods > 1
        var setWon = false
        var matchWon = false

        update { s in
            s.pushUndo(limit: limit)
            if s.phase == .pregame { s.phase = .live }
            let i = side.rawValue
            let o = side.opponent.rawValue
            s.match.points[i] += 1

            let target = isDecidingSet ? format.decidingSetPoints : format.pointsToWin
            let mine = s.match.points[i]
            let theirs = s.match.points[o]
            let reachedCap = format.cap.map { mine >= $0 } ?? false

            if (mine >= target && mine - theirs >= format.winBy) || reachedCap {
                setWon = true
                s.match.sets.append(SetScore(scores: s.match.points, tiebreak: nil))
                s.scores[i] += 1
                s.match.points = [0, 0]
                if s.scores[i] >= setsNeeded {
                    matchWon = true
                    s.phase = .final
                } else {
                    s.period += 1
                    switch format.nextSetServer {
                    case .alternate: s.match.setFirstServer = s.match.setFirstServer.opponent
                    case .previousWinner: s.match.setFirstServer = side
                    }
                    s.possession = s.match.setFirstServer
                    // Pickleball doubles: each new game starts "0-0-2".
                    s.match.serverNumber = format.sideOut && format.doubles ? 2 : 1
                }
            } else {
                s.possession = Self.rallyServer(format: format, match: s.match, target: target, scorer: side)
            }
        }

        bumpScore(side)
        if setWon { bumpScore(side.opponent) }
        if matchWon {
            showFlash(side: side, text: "MATCH", isPositive: true)
            completeGame(playSound: true)
        } else if setWon {
            showFlash(side: side, text: rules.periodName.uppercased(), isPositive: true)
            environment.feedback(.periodEnd)
        } else {
            showFlash(side: side, text: "+1", isPositive: true)
            environment.feedback(.score(1))
        }
    }

    /// The receiving side won the rally under side-out scoring: no point, the serve moves on.
    private func sideOut(rallyWinner: TeamSide, doubles: Bool) {
        let limit = undoLimit
        let servingSide = rallyWinner.opponent
        var secondServer = false
        update { s in
            s.pushUndo(limit: limit)
            if s.phase == .pregame { s.phase = .live }
            if doubles && s.match.serverNumber == 1 {
                s.match.serverNumber = 2
                secondServer = true
            } else {
                s.possession = rallyWinner
                s.match.serverNumber = 1
            }
        }
        if secondServer {
            showFlash(side: servingSide, text: "2ND SERVER", isPositive: false)
        } else {
            showFlash(side: rallyWinner, text: "SIDE OUT", isPositive: true)
        }
        environment.feedback(.possession)
    }

    /// Pickleball's spoken score: server's score, receiver's score, server number ("4–2–1").
    var pickleballCall: String? {
        guard let format = rules.rallyFormat, format.sideOut, state.phase != .final,
              let server = state.possession else { return nil }
        let p = state.match.points
        let call = "\(p[server.rawValue])–\(p[server.opponent.rawValue])"
        return format.doubles ? "\(call)–\(state.match.serverNumber)" : call
    }

    /// The live call for the center panel (tennis or pickleball).
    var matchCall: String? { tennisCall ?? pickleballCall }

    /// Who serves next. Table tennis: two serves each, then one each from deuce (10-10).
    nonisolated static func rallyServer(format: RallyFormat, match: MatchState, target: Int, scorer: TeamSide) -> TeamSide {
        switch format.serve {
        case .winnerServes:
            return scorer
        case .alternating(let every):
            let p = match.points
            let total = p[0] + p[1]
            let deuceStart = 2 * (target - 1)
            let turns: Int
            if p[0] >= target - 1 && p[1] >= target - 1 {
                turns = deuceStart / max(1, every) + (total - deuceStart)
            } else {
                turns = total / max(1, every)
            }
            return turns % 2 == 0 ? match.setFirstServer : match.setFirstServer.opponent
        }
    }

    // MARK: - Tennis

    func tennisPoint(for side: TeamSide) {
        guard state.phase != .final else { return }
        let limit = undoLimit
        let setsNeeded = setsToWin
        var gameWon = false
        var setWon = false
        var matchWon = false

        update { s in
            s.pushUndo(limit: limit)
            if s.phase == .pregame { s.phase = .live }
            let i = side.rawValue
            let o = side.opponent.rawValue

            if s.match.inTiebreak {
                s.match.points[i] += 1
                let p = s.match.points
                if p[i] >= 7 && p[i] - p[o] >= 2 {
                    gameWon = true
                    setWon = true
                    s.match.games[i] += 1
                    s.match.sets.append(SetScore(scores: s.match.games, tiebreak: p))
                    // Whoever received first in the tiebreak serves the next set.
                    s.possession = s.match.tiebreakFirstServer.opponent
                } else {
                    // First point by one player, then two each.
                    let total = p[0] + p[1]
                    s.possession = ((total + 1) / 2) % 2 == 0 ? s.match.tiebreakFirstServer : s.match.tiebreakFirstServer.opponent
                }
            } else {
                var p = s.match.points
                p[i] += 1
                if p[i] >= 4 && p[i] - p[o] >= 2 {
                    gameWon = true
                    s.match.games[i] += 1
                    s.match.points = [0, 0]
                    s.possession = (s.possession ?? .a).opponent
                    let g = s.match.games
                    if g[i] >= 6 && g[i] - g[o] >= 2 {
                        setWon = true
                        s.match.sets.append(SetScore(scores: g, tiebreak: nil))
                    } else if g[0] == 6 && g[1] == 6 {
                        s.match.inTiebreak = true
                        s.match.tiebreakFirstServer = s.possession ?? .a
                    }
                } else {
                    // Keep deuce at 3-3 so advantage is always "one point ahead".
                    if p[0] >= 3 && p[1] >= 3 && p[0] == p[1] { p = [3, 3] }
                    s.match.points = p
                }
            }

            if setWon {
                s.scores[i] += 1
                s.match.games = [0, 0]
                s.match.points = [0, 0]
                s.match.inTiebreak = false
                if s.scores[i] >= setsNeeded {
                    matchWon = true
                    s.phase = .final
                } else {
                    s.period += 1
                }
            }
        }

        bumpScore(side)
        if gameWon { bumpScore(side.opponent) }
        if matchWon {
            showFlash(side: side, text: "MATCH", isPositive: true)
            completeGame(playSound: true)
        } else if setWon {
            showFlash(side: side, text: "SET", isPositive: true)
            environment.feedback(.periodEnd)
        } else if gameWon {
            showFlash(side: side, text: "GAME", isPositive: true)
            environment.feedback(.periodChange)
        } else {
            environment.feedback(.score(1))
        }
    }

    func tennisPointText(_ side: TeamSide) -> String {
        let p = state.match.points
        let mine = p[side.rawValue]
        let theirs = p[side.opponent.rawValue]
        if state.match.inTiebreak { return "\(mine)" }
        if mine >= 3 && theirs >= 3 { return mine > theirs ? "AD" : "40" }
        return ["0", "15", "30", "40"][min(mine, 3)]
    }

    /// "DEUCE", "ADVANTAGE · NADAL", "TIEBREAK" — the call a chair umpire would make.
    var tennisCall: String? {
        guard model == .tennis, state.phase != .final else { return nil }
        if state.match.inTiebreak { return "TIEBREAK" }
        let p = state.match.points
        guard p[0] >= 3 && p[1] >= 3 else { return nil }
        if p[0] == p[1] { return "DEUCE" }
        let leader: TeamSide = p[0] > p[1] ? .a : .b
        return "ADVANTAGE · \(teamName(leader).uppercased())"
    }

    // MARK: - Baseball

    enum PitchCall {
        case ball, strike, foul, out
    }

    var battingSide: TeamSide { state.match.isBottom ? .b : .a }

    func recordPitch(_ call: PitchCall) {
        guard state.phase != .final, model == .baseball else { return }
        let limit = undoLimit
        let regulation = regulationPeriods
        var message: String?
        var halfOver = false
        var gameOver = false

        update { s in
            s.pushUndo(limit: limit)
            if s.phase == .pregame { s.phase = .live }
            switch call {
            case .ball:
                s.match.balls += 1
                if s.match.balls >= 4 {
                    s.match.balls = 0
                    s.match.strikes = 0
                    message = "WALK"
                }
            case .strike:
                s.match.strikes += 1
                if s.match.strikes >= 3 {
                    Self.recordOut(&s)
                    message = "K"
                }
            case .foul:
                if s.match.strikes < 2 { s.match.strikes += 1 }
            case .out:
                Self.recordOut(&s)
                message = "OUT"
            }
            if s.match.outs >= 3 {
                halfOver = true
                gameOver = Self.finishHalfInning(&s, regulation: regulation)
            }
        }

        if gameOver {
            completeGame(playSound: true)
        } else if halfOver {
            showFlash(side: battingSide.opponent, text: "3 OUTS", isPositive: false)
            environment.feedback(.periodEnd)
        } else {
            if let message { showFlash(side: battingSide, text: message, isPositive: message == "WALK") }
            environment.feedback(message == nil ? .tap : .score(1))
        }
    }

    /// Ends the half-inning by hand (when you're not tracking every out).
    func endHalfInning() {
        guard state.phase != .final, model == .baseball else { return }
        let limit = undoLimit
        let regulation = regulationPeriods
        var gameOver = false
        update { s in
            s.pushUndo(limit: limit)
            if s.phase == .pregame { s.phase = .live }
            gameOver = Self.finishHalfInning(&s, regulation: regulation)
        }
        if gameOver {
            completeGame(playSound: true)
        } else {
            environment.feedback(.periodEnd)
        }
    }

    nonisolated static func recordOut(_ s: inout GameState) {
        s.match.outs += 1
        s.match.balls = 0
        s.match.strikes = 0
    }

    /// Returns true when the half-inning ends the game.
    nonisolated static func finishHalfInning(_ s: inout GameState, regulation: Int) -> Bool {
        s.match.outs = 0
        s.match.balls = 0
        s.match.strikes = 0
        let away = s.scores[0]
        let home = s.scores[1]
        if !s.match.isBottom {
            // Home team already ahead after the top of the last inning: no need to bat.
            if s.period >= regulation && home > away {
                s.phase = .final
                return true
            }
            s.match.isBottom = true
        } else {
            if s.period >= regulation && home != away {
                s.phase = .final
                return true
            }
            s.period += 1
            s.match.isBottom = false
        }
        s.possession = s.match.isBottom ? .b : .a
        let inning = s.period - 1
        for team in 0...1 {
            while s.match.lineScore[team].count <= inning { s.match.lineScore[team].append(0) }
        }
        return false
    }

    nonisolated static func addToLineScore(_ s: inout GameState, side: TeamSide, runs: Int) {
        let inning = max(0, s.period - 1)
        if s.match.lineScore.count != 2 { s.match.lineScore = [[], []] }
        while s.match.lineScore[side.rawValue].count <= inning { s.match.lineScore[side.rawValue].append(0) }
        s.match.lineScore[side.rawValue][inning] = max(0, s.match.lineScore[side.rawValue][inning] + runs)
    }

    // MARK: - Boxing / MMA

    /// Scores the current (or just-finished) round. `winner == nil` is an even 10-10 round.
    func scoreRound(winner: TeamSide?, margin: Int) {
        guard state.phase != .final, model == .combat else { return }
        let round = state.period
        let limit = undoLimit
        update { s in
            s.pushUndo(limit: limit)
            if s.phase == .pregame { s.phase = .live }
            var points = [10, 10]
            if let winner { points[winner.opponent.rawValue] = 10 - max(1, min(margin, 3)) }
            s.match.cards.removeAll { $0.round == round }
            s.match.cards.append(RoundCard(round: round, points: points))
            s.match.cards.sort { $0.round < $1.round }
            s.scores = [
                s.match.cards.reduce(0) { $0 + $1.points[0] },
                s.match.cards.reduce(0) { $0 + $1.points[1] }
            ]
        }
        bumpScore(.a)
        bumpScore(.b)
        if let winner {
            showFlash(side: winner, text: "10-\(10 - max(1, min(margin, 3)))", isPositive: true)
            environment.feedback(.score(margin >= 2 ? 3 : 1))
        } else {
            environment.feedback(.tap)
        }
    }

    var currentRoundCard: RoundCard? {
        state.match.cards.first { $0.round == state.period }
    }

    /// Ends a fight by stoppage (KO / TKO / submission).
    func declareWinner(_ side: TeamSide, method: String) {
        guard state.phase != .final else { return }
        let date = Date()
        let note = "\(method) · \(rules.periodTitle(state.period, regulation: regulationPeriods))"
        update { s in
            s.clock.pause(at: date)
            s.match.resting = false
            s.declaredWinner = side
            s.resultNote = note
            s.phase = .final
        }
        updateTicking()
        completeGame(playSound: true)
    }

    // MARK: - Display helpers

    /// Small non-tappable badges under a team name.
    func badges(for side: TeamSide) -> [TeamBadge] {
        switch model {
        case .rally:
            return [TeamBadge(title: rules.periodNamePlural.uppercased(), value: "\(state.score(side))")]
        case .tennis:
            return [
                TeamBadge(title: "SETS", value: "\(state.score(side))"),
                TeamBadge(title: "GAMES", value: "\(state.match.games[side.rawValue])")
            ]
        case .points, .baseball, .combat:
            return []
        }
    }

    var scoreCaption: String? {
        if model == .tennis { return state.match.inTiebreak ? "Tiebreak" : "Game" }
        return rules.scoreCaption
    }

    /// Finished sets/rounds, e.g. ["25–21", "22–25"] or ["6–4", "7–6 (7–5)"].
    var completedSetLines: [String] {
        switch model {
        case .rally:
            return state.match.sets.map { "\($0.scores[0])–\($0.scores[1])" }
        case .tennis:
            return state.match.sets.map { set in
                var line = "\(set.scores[0])–\(set.scores[1])"
                if let tb = set.tiebreak { line += " (\(tb[0])–\(tb[1]))" }
                return line
            }
        case .combat:
            return state.match.cards.map { "R\($0.round) \($0.points[0])–\($0.points[1])" }
        case .points, .baseball:
            return []
        }
    }

    /// One line for the final screen and history.
    var resultSummary: String? {
        if let note = state.resultNote { return note }
        switch model {
        case .rally, .tennis:
            let lines = completedSetLines
            return lines.isEmpty ? nil : lines.joined(separator: ", ")
        case .baseball:
            let hits = (0...1).map { state.counter("hits", TeamSide(rawValue: $0)!) }
            let errors = (0...1).map { state.counter("errors", TeamSide(rawValue: $0)!) }
            return "Hits \(hits[0])–\(hits[1]) · Errors \(errors[0])–\(errors[1])"
        case .combat:
            return state.match.cards.isEmpty ? nil : "Decision · " + completedSetLines.joined(separator: ", ")
        case .points:
            return nil
        }
    }
}
