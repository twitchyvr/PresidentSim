import Foundation

struct GameEvent: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String
    let category: EventCategory
    let turnOccurred: Int
    var isResolved: Bool
    var resolution: String?
    var consequences: [EventConsequence]

    // AI-generated events have a special flag
    let isAIGenerated: Bool

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        category: EventCategory,
        turnOccurred: Int,
        isResolved: Bool = false,
        resolution: String? = nil,
        consequences: [EventConsequence] = [],
        isAIGenerated: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.turnOccurred = turnOccurred
        self.isResolved = isResolved
        self.resolution = resolution
        self.consequences = consequences
        self.isAIGenerated = isAIGenerated
    }
}

enum EventCategory: String, Codable, CaseIterable {
    case economic = "Economic"
    case political = "Political"
    case international = "International"
    case social = "Social"
    case crisis = "Crisis"
    case scandal = "Scandal"
    case achievement = "Achievement"
    case personal = "Personal"
}

struct EventConsequence: Codable {
    let affectedArea: String
    let delta: Double
    let narrative: String
}

struct Decision: Codable, Identifiable {
    let id: UUID
    let prompt: String
    let context: String
    let options: [DecisionOption]
    let turn: Int
    let phase: GamePhase
    let isUrgent: Bool
    let deadline: Int? // turn number by which decision must be made

    init(
        id: UUID = UUID(),
        prompt: String,
        context: String,
        options: [DecisionOption],
        turn: Int,
        phase: GamePhase,
        isUrgent: Bool = false,
        deadline: Int? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.context = context
        self.options = options
        self.turn = turn
        self.phase = phase
        self.isUrgent = isUrgent
        self.deadline = deadline
    }
}

struct DecisionOption: Codable, Identifiable {
    let id: UUID
    let text: String
    let isRisky: Bool
    let riskProbability: Double // probability of negative outcome
    let politicalCapitalCost: Double
    let expectedBenefits: [String: Double]

    init(
        id: UUID = UUID(),
        text: String,
        isRisky: Bool = false,
        riskProbability: Double = 0.5,
        politicalCapitalCost: Double = 0,
        expectedBenefits: [String: Double] = [:]
    ) {
        self.id = id
        self.text = text
        self.isRisky = isRisky
        self.riskProbability = riskProbability
        self.politicalCapitalCost = politicalCapitalCost
        self.expectedBenefits = expectedBenefits
    }
}

struct DecisionResult: Codable, Identifiable {
    let id: UUID
    let decision: Decision
    let chosenOption: DecisionOption
    let rollResult: Double // 0.0 to 1.0
    let outcome: DecisionOutcome
    let narrative: String
    let consequences: [EventConsequence]
    let turn: Int

    init(
        id: UUID = UUID(),
        decision: Decision,
        chosenOption: DecisionOption,
        rollResult: Double,
        outcome: DecisionOutcome,
        narrative: String,
        consequences: [EventConsequence],
        turn: Int
    ) {
        self.id = id
        self.decision = decision
        self.chosenOption = chosenOption
        self.rollResult = rollResult
        self.outcome = outcome
        self.narrative = narrative
        self.consequences = consequences
        self.turn = turn
    }
}
