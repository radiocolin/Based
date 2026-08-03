import Foundation

// Field shapes documented by hand in WPBL.md by probing stats.womensprobaseballleague.com/v1.
// The API is snake_case JSON; WPBLAPIClient decodes with .convertFromSnakeCase so these
// properties stay plain camelCase (no per-field CodingKeys needed).

// MARK: - Games list (/v1/games, /v1/games/{id})

struct WPBLGamesListResponse: Decodable, Sendable {
    let count: Int
    let games: [WPBLGame]
}

struct WPBLGame: Decodable, Sendable {
    let gameId: String
    let provider: String
    let seasonId: String
    let homeTeamId: String
    let awayTeamId: String
    let homeTeamName: String
    let awayTeamName: String
    let gameType: String
    let venue: String
    let countsInStandings: Bool
    let status: String
    let scheduledStart: String
    let completedAt: String?
    let updatedAt: String
    let state: WPBLGameState
}

struct WPBLGameState: Decodable, Sendable {
    let gameId: String
    let status: String
    let homeScore: Int
    let awayScore: Int
    let inning: Int
    let half: String
    let outs: Int
    let batterId: String
    let updatedAt: String
}

// MARK: - Teams (/v1/teams, /v1/teams/{id})

struct WPBLTeamsListResponse: Decodable, Sendable {
    let count: Int
    let teams: [WPBLTeam]
}

struct WPBLTeam: Decodable, Sendable {
    let teamId: String
    let teamName: String
    let seasonId: String
    let wins: Int
    let losses: Int
    let ties: Int
    let record: String
    let streak: String
    let updatedAt: String
}

// MARK: - Roster (/v1/teams/{id}/players, /v1/players/{id})

struct WPBLPlayersListResponse: Decodable, Sendable {
    let count: Int
    let players: [WPBLRosterPlayer]
}

struct WPBLRosterPlayer: Decodable, Sendable {
    let playerId: String
    let teamId: String
    let firstName: String
    let lastName: String
    let position: String
    let uniform: String
    let height: String
    let weight: String
    let hometown: String
    let dob: String
    let isActive: Bool
    let playerStatus: String
    let hasStats: Bool
    let prestoData: WPBLPrestoPlayerData?
    let updatedAt: String

    /// The top-level bio fields (height/weight/hometown/dob) are blank for every player
    /// observed — the real values, when present, live under presto_data.data instead.
    var bio: WPBLPrestoPlayerBioData? { prestoData?.data }
}

struct WPBLPrestoPlayerData: Decodable, Sendable {
    let data: WPBLPrestoPlayerBioData?
}

struct WPBLPrestoPlayerBioData: Decodable, Sendable {
    let bats: String?
    let throwsHand: String?
    let hometown: String?
    let born: String?
    let height: String?
    let weight: String?

    private enum CodingKeys: String, CodingKey {
        case bats, hometown, born, height, weight
        case throwsHand = "throws"
    }
}

// MARK: - Boxscore (/v1/games/{id}/boxscore)

struct WPBLBoxscoreWrapper: Decodable, Sendable {
    let boxscore: WPBLBoxscore
}

struct WPBLBoxscore: Decodable, Sendable {
    let gameId: String
    let provider: String
    let gameStatus: String
    let sourceUpdatedAt: String
    let fetchedAt: String
    let status: WPBLLiveStatus
    let teams: [WPBLBoxscoreTeam]
    let plays: [WPBLPlay]?
}

struct WPBLLiveStatus: Decodable, Sendable {
    let complete: Bool
    let inning: Int
    let half: String
    let battingTeamId: String
    let outs: Int
    let balls: Int
    let strikes: Int
    let batterName: String
    let pitcherName: String
    let firstBase: String
    let secondBase: String
    let thirdBase: String
    let basesOccupied: [Int]?
    let basesLoaded: Bool
    let awayRuns: Int
    let homeRuns: Int
}

struct WPBLBoxscoreTeam: Decodable, Sendable {
    let side: String
    let id: String
    let code: String
    let name: String
    let record: String
    let line: [WPBLInningLine]?
    let totals: WPBLTeamTotals?
    let players: [WPBLBoxscorePlayer]?
    let starters: [WPBLStarter]?
}

struct WPBLInningLine: Decodable, Sendable {
    let inning: Int
    let runs: Int
}

struct WPBLTeamTotals: Decodable, Sendable {
    let runs: Int
    let hits: Int
    let errors: Int
    let leftOnBase: Int
    let batting: [String: String]?
    let pitching: [String: String]?
    let fielding: [String: String]?
}

struct WPBLStarter: Decodable, Sendable {
    let name: String
    let uniform: String
    let position: String
    let spot: String
}

struct WPBLBoxscorePlayer: Decodable, Sendable {
    let id: String
    let name: String
    let shortName: String
    let uniform: String
    let position: String
    let spot: String
    let bats: String?
    let throwsHand: String?
    let hitting: [String: String]?
    let pitching: [String: String]?
    let fielding: [String: String]?

    private enum CodingKeys: String, CodingKey {
        case id, name, shortName, uniform, position, spot, bats, hitting, pitching, fielding
        case throwsHand = "throws"
    }
}

// MARK: - Play-by-play

struct WPBLPlay: Decodable, Sendable {
    let inning: Int
    let half: String
    let teamId: String
    let sequence: Int
    let batterName: String
    let pitcherName: String
    let outs: Int
    let firstBase: String
    let secondBase: String
    let thirdBase: String
    let basesOccupied: [Int]?
    let basesLoaded: Bool
    let narrative: String
    let eventType: String
    let isHit: Bool
    let isScoringPlay: Bool
    let runsScored: Int
    let pitchSequence: String
    let pitchEvents: [WPBLPitchEvent]?
    let fouls: Int
    let balls: Int
    let strikes: Int
}

struct WPBLPitchEvent: Decodable, Sendable {
    let sequence: Int
    let code: String
    let type: String
    let description: String
}
