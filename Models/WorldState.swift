import Foundation

struct WorldState: Codable {
    // Economic Indicators
    var gdpGrowth: Double // percentage
    var unemployment: Double // percentage
    var inflation: Double // percentage
    var stockMarketIndex: Double // relative to baseline (100)
    var nationalDebt: Double // in trillions
    var consumerConfidence: Double // 0-100

    // Political Indicators
    var approvalRating: Double // 0-100
    var partyUnityScore: Double // 0-100
    var congressionalSupport: Double // 0-100
    var donorSatisfaction: Double // 0-100
    var mediaFavorability: Double // 0-100

    // International Relations
    var globalInfluence: Double // 0-100
    var relationsWithAllies: [String: Double] // country -> 0-100
    var relationsWithAdversaries: [String: Double] // country -> 0-100
    var internationalPrestige: Double // 0-100

    // News & Narrative
    var newsCyclePhase: NewsCyclePhase
    var currentNarrative: String
    var trendingTopic: String

    // Time
    var currentTurn: Int // 1 turn = 1 week
    var currentYear: Int

    // Historical Record
    var historicalLedger: [LedgerEntry]

    init() {
        self.gdpGrowth = 2.5
        self.unemployment = 4.0
        self.inflation = 2.0
        self.stockMarketIndex = 100.0
        self.nationalDebt = 23.0
        self.consumerConfidence = 70.0

        self.approvalRating = 50.0
        self.partyUnityScore = 70.0
        self.congressionalSupport = 50.0
        self.donorSatisfaction = 60.0
        self.mediaFavorability = 50.0

        self.globalInfluence = 50.0
        self.relationsWithAllies = [
            "UK": 80.0, "France": 75.0, "Germany": 72.0,
            "Japan": 78.0, "Canada": 85.0, "Australia": 82.0
        ]
        self.relationsWithAdversaries = [
            "China": 40.0, "Russia": 35.0, "North Korea": 20.0, "Iran": 30.0
        ]
        self.internationalPrestige = 60.0

        self.newsCyclePhase = .rising
        self.currentNarrative = "A new chapter in American politics begins."
        self.trendingTopic = "Election 2028"

        self.currentTurn = 1
        self.currentYear = 2025

        self.historicalLedger = []
    }

    mutating func advanceTime() {
        currentTurn += 1
        if currentTurn % 52 == 0 {
            currentYear += 1
        }
    }

    mutating func addLedgerEntry(_ entry: LedgerEntry) {
        historicalLedger.append(entry)
    }

    var turnDescription: String {
        let month = (currentTurn % 52) / 4 + 1
        let monthName = ["January", "February", "March", "April", "May", "June",
                        "July", "August", "September", "October", "November", "December"][month - 1]
        let week = (currentTurn % 13) + 1
        return "\(monthName), Week \(week), \(currentYear)"
    }
}

struct LedgerEntry: Codable, Identifiable {
    let id: UUID
    let turn: Int
    let year: Int
    let phase: GamePhase
    let title: String
    let description: String
    let effects: [String: Double]

    init(
        id: UUID = UUID(),
        turn: Int,
        year: Int,
        phase: GamePhase,
        title: String,
        description: String,
        effects: [String: Double] = [:]
    ) {
        self.id = id
        self.turn = turn
        self.year = year
        self.phase = phase
        self.title = title
        self.description = description
        self.effects = effects
    }
}
