import Foundation

// MARK: - Player Actions

// Forward declarations for cross-file references
@objc enum ActionCategoryRaw: Int, Codable {
    case communication = 0
    case travel = 1
    case diplomatic = 2
    case executive = 3
    case political = 4
    case personnel = 5
}
// Actions the player can take as candidate or president

enum ActionCategory: String, Codable, CaseIterable {
    case communication = "Communication"
    case travel = "Travel"
    case diplomatic = "Diplomatic"
    case executive = "Executive"
    case political = "Political"
    case personnel = "Personnel"
}

enum ActionCostType: String, Codable {
    case politicalCapital = "Political Capital"
    case time = "Time"
    case money = "Money"
    case mediaCycle = "Media Cycle"
}

struct GameAction: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let category: ActionCategory
    let costs: [ActionCost]
    let effects: [String: Double]
    let cooldown: Int // turns before can use again
    let availablePhases: [GamePhase]

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        category: ActionCategory,
        costs: [ActionCost] = [],
        effects: [String: Double] = [:],
        cooldown: Int = 0,
        availablePhases: [GamePhase] = GamePhase.allCases
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.costs = costs
        self.effects = effects
        self.cooldown = cooldown
        self.availablePhases = availablePhases
    }
}

struct ActionCost: Codable {
    let type: ActionCostType
    let amount: Double
}

struct ActionResult: Codable {
    let action: GameAction
    let success: Bool
    let narrative: String
    let effects: [String: Double]
    let turn: Int
}

// MARK: - Action Registry

struct ActionRegistry {
    static let allActions: [GameAction] = [
        // Communication
        GameAction(
            name: "Make Speech",
            description: "Deliver a speech to the nation or a targeted audience. Great for shaping narrative.",
            category: .communication,
            costs: [ActionCost(type: .politicalCapital, amount: 10), ActionCost(type: .time, amount: 1)],
            effects: ["mediaFavorability": 5, "approvalRating": 2],
            cooldown: 1
        ),
        GameAction(
            name: "Press Conference",
            description: "Take questions from the press. High risk, high reward.",
            category: .communication,
            costs: [ActionCost(type: .politicalCapital, amount: 15), ActionCost(type: .time, amount: 1)],
            effects: ["mediaFavorability": 8],
            cooldown: 2
        ),
        GameAction(
            name: "Issue Statement",
            description: "Release a brief written statement. Low cost, moderate impact.",
            category: .communication,
            costs: [ActionCost(type: .politicalCapital, amount: 5)],
            effects: ["mediaFavorability": 2],
            cooldown: 0
        ),
        GameAction(
            name: "Do Interview",
            description: "One-on-one interview with a major network.",
            category: .communication,
            costs: [ActionCost(type: .politicalCapital, amount: 8), ActionCost(type: .time, amount: 1)],
            effects: ["mediaFavorability": 4, "approvalRating": 1],
            cooldown: 1
        ),

        // Travel
        GameAction(
            name: "Campaign Rally",
            description: "Hold a rally in a key state. Great for momentum and name recognition.",
            category: .travel,
            costs: [ActionCost(type: .money, amount: 500000), ActionCost(type: .time, amount: 1)],
            effects: ["momentum": 3, "mediaFavorability": 3],
            cooldown: 1,
            availablePhases: [.campaign, .primaries, .generalElection]
        ),
        GameAction(
            name: "Visit Swing State",
            description: "Focus campaign resources on a competitive state.",
            category: .travel,
            costs: [ActionCost(type: .money, amount: 300000), ActionCost(type: .time, amount: 1)],
            effects: ["statePolling": 5],
            cooldown: 1,
            availablePhases: [.generalElection]
        ),
        GameAction(
            name: "Foreign Diplomatic Visit",
            description: "Visit a world leader to strengthen relations.",
            category: .travel,
            costs: [ActionCost(type: .time, amount: 2)],
            effects: ["globalInfluence": 5],
            cooldown: 3,
            availablePhases: [.presidency, .lameDuck]
        ),

        // Diplomatic
        GameAction(
            name: "Call World Leader",
            description: "Reach out to a foreign leader to discuss issues.",
            category: .diplomatic,
            costs: [ActionCost(type: .politicalCapital, amount: 10), ActionCost(type: .time, amount: 0)],
            effects: ["relationshipTarget": 3],
            cooldown: 1,
            availablePhases: [.presidency, .lameDuck]
        ),
        GameAction(
            name: "Host State Dinner",
            description: "Formal dinner for a foreign leader. Builds goodwill.",
            category: .diplomatic,
            costs: [ActionCost(type: .politicalCapital, amount: 15), ActionCost(type: .money, amount: 100000)],
            effects: ["relationshipTarget": 8, "globalInfluence": 2],
            cooldown: 2,
            availablePhases: [.presidency, .lameDuck]
        ),
        GameAction(
            name: "Summit Meeting",
            description: "Formal summit with multiple leaders. Major diplomatic event.",
            category: .diplomatic,
            costs: [ActionCost(type: .politicalCapital, amount: 25), ActionCost(type: .time, amount: 3)],
            effects: ["globalInfluence": 10, "relationshipTarget": 15],
            cooldown: 5,
            availablePhases: [.presidency, .lameDuck]
        ),

        // Executive
        GameAction(
            name: "Issue Executive Order",
            description: "Presidential directive without congressional approval.",
            category: .executive,
            costs: [ActionCost(type: .politicalCapital, amount: 30), ActionCost(type: .mediaCycle, amount: 1)],
            effects: ["congressionalSupport": -5],
            cooldown: 2,
            availablePhases: [.presidency, .lameDuck]
        ),
        GameAction(
            name: "Sign Legislation",
            description: "Sign a bill passed by Congress into law.",
            category: .executive,
            costs: [ActionCost(type: .time, amount: 1)],
            effects: ["approvalRating": 3, "congressionalSupport": 5],
            cooldown: 0,
            availablePhases: [.presidency, .lameDuck]
        ),
        GameAction(
            name: "Veto Bill",
            description: "Reject legislation from Congress.",
            category: .executive,
            costs: [ActionCost(type: .politicalCapital, amount: 20), ActionCost(type: .mediaCycle, amount: 1)],
            effects: ["congressionalSupport": -10],
            cooldown: 1,
            availablePhases: [.presidency, .lameDuck]
        ),
        GameAction(
            name: "Grant Pardon",
            description: "Executive clemency for a federal offense.",
            category: .executive,
            costs: [ActionCost(type: .politicalCapital, amount: 15)],
            effects: ["mediaFavorability": -3],
            cooldown: 3,
            availablePhases: [.presidency, .lameDuck]
        ),

        // Political
        GameAction(
            name: "Fundraise",
            description: "Call donors to raise campaign funds.",
            category: .political,
            costs: [ActionCost(type: .time, amount: 1)],
            effects: ["campaignFunds": 1000000],
            cooldown: 1
        ),
        GameAction(
            name: "Negotiate with Congress",
            description: "Work with legislators to build support for your agenda.",
            category: .political,
            costs: [ActionCost(type: .politicalCapital, amount: 20), ActionCost(type: .time, amount: 1)],
            effects: ["congressionalSupport": 10],
            cooldown: 2,
            availablePhases: [.presidency, .lameDuck]
        ),
        GameAction(
            name: "Rally Base",
            description: "Speak to party loyalists to boost enthusiasm.",
            category: .political,
            costs: [ActionCost(type: .politicalCapital, amount: 10), ActionCost(type: .time, amount: 1)],
            effects: ["partyUnityScore": 8, "momentum": 2],
            cooldown: 1
        ),
        GameAction(
            name: "Attack Opponent",
            description: "Go on offense against your political rival.",
            category: .political,
            costs: [ActionCost(type: .politicalCapital, amount: 15)],
            effects: ["opponentPolling": -3],
            cooldown: 2,
            availablePhases: [.campaign, .primaries, .generalElection]
        ),

        // Personnel
        GameAction(
            name: "Meet with Cabinet",
            description: "Full cabinet meeting to discuss agenda and get advice.",
            category: .personnel,
            costs: [ActionCost(type: .time, amount: 1)],
            effects: ["cabinetSatisfaction": 5],
            cooldown: 2,
            availablePhases: [.presidency, .lameDuck]
        ),
        GameAction(
            name: "Meet with Advisor",
            description: "Private meeting with a senior advisor for counsel.",
            category: .personnel,
            costs: [ActionCost(type: .time, amount: 0)],
            effects: [:],
            cooldown: 0,
            availablePhases: [.presidency, .lameDuck]
        ),
        GameAction(
            name: "Replace Cabinet Member",
            description: "Remove and replace a cabinet secretary.",
            category: .personnel,
            costs: [ActionCost(type: .politicalCapital, amount: 25), ActionCost(type: .time, amount: 1)],
            effects: ["cabinetSatisfaction": -10],
            cooldown: 5,
            availablePhases: [.presidency, .lameDuck]
        )
    ]

    static func actionsFor(phase: GamePhase) -> [GameAction] {
        allActions.filter { $0.availablePhases.contains(phase) }
    }
}

// MARK: - Briefing / Inbox Items

enum BriefingType: String, Codable {
    case crisis = "Crisis"
    case intelligence = "Intelligence"
    case legislative = "Legislative"
    case diplomatic = "Diplomatic"
    case media = "Media Request"
    case campaign = "Campaign"
    case administrative = "Administrative"
}

struct BriefingOption: Codable, Identifiable {
    let id: UUID
    let label: String
    let description: String
    let pros: [String]
    let cons: [String]
    let effects: [String: Double] // stat -> delta

    init(
        id: UUID = UUID(),
        label: String,
        description: String = "",
        pros: [String] = [],
        cons: [String] = [],
        effects: [String: Double] = [:]
    ) {
        self.id = id
        self.label = label
        self.description = description
        self.pros = pros
        self.cons = cons
        self.effects = effects
    }
}

struct Briefing: Codable, Identifiable {
    let id: UUID
    let type: BriefingType
    let title: String
    let summary: String
    let urgency: Int // 1-5, 5 being most urgent
    let turnReceived: Int
    let deadline: Int? // turn by which to respond
    var isRead: Bool
    var isResolved: Bool
    var selectedOptionIndex: Int? // which option the player chose
    let options: [BriefingOption]
    var requiresResponse: Bool { deadline != nil && !isResolved }

    init(
        id: UUID = UUID(),
        type: BriefingType,
        title: String,
        summary: String,
        urgency: Int = 1,
        turnReceived: Int,
        deadline: Int? = nil,
        isRead: Bool = false,
        isResolved: Bool = false,
        selectedOptionIndex: Int? = nil,
        options: [BriefingOption] = []
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.summary = summary
        self.urgency = urgency
        self.turnReceived = turnReceived
        self.deadline = deadline
        self.isRead = isRead
        self.isResolved = isResolved
        self.selectedOptionIndex = selectedOptionIndex
        self.options = options
    }
}

// MARK: - Political Capital & Resources

struct PlayerResources: Codable {
    var politicalCapital: Double // max 100, regenerates over time
    var campaignFunds: Double // in dollars
    var mediaCycles: Int // turns of media attention
    var approvalHistory: [Double] // last 20 turns
    var momentum: Double // -10 to +10

    init() {
        self.politicalCapital = 50
        self.campaignFunds = 10_000_000
        self.mediaCycles = 3
        self.approvalHistory = []
        self.momentum = 0
    }
}
