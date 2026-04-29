import Foundation

struct GameState: Codable {
    var phase: GamePhase
    var player: Player
    var world: WorldState

    // Campaign/Election specific
    var primaryDelegates: Int
    var totalDelegatesNeeded: Int
    var primaryOpponents: [AICandidate]
    var currentPrimaryState: String
    var pollingData: [String: Double] // state -> percentage
    var electoralVotes: Int
    var popularVoteMargin: Double
    var opponentPolling: Double

    // Convention
    var conventionDelegates: [String: Int] // state -> delegate count
    var vpShortlist: [String]
    var chosenVP: String?

    // General Election
    var generalOpponent: AICandidate?
    var debateFinished: Bool
    var campaignMomentum: Double // positive = ahead

    // Presidency
    var currentTerm: Int // 1 or 2
    var billsSigned: Int
    var billsVetoed: Int
    var executiveOrders: Int
    var cabinetSatisfaction: Double

    // Pending decisions
    var pendingDecisions: [Decision]
    var activeEvents: [GameEvent]
    var recentDecisions: [DecisionResult]

    // Exit tracking
    var exitType: ExitType?
    var exitNarrative: String?

    // Player resources
    var resources: PlayerResources = PlayerResources()

    init(
        phase: GamePhase = .preCampaign,
        player: Player = Player(name: "Player", party: .democrat)
    ) {
        self.phase = phase
        self.player = player
        self.world = WorldState()

        self.primaryDelegates = 0
        self.totalDelegatesNeeded = 1991
        self.primaryOpponents = []
        self.currentPrimaryState = "Iowa"
        self.pollingData = [:]
        self.electoralVotes = 0
        self.popularVoteMargin = 0.0
        self.opponentPolling = 45.0

        self.conventionDelegates = [:]
        self.vpShortlist = []
        self.chosenVP = nil

        self.generalOpponent = nil
        self.debateFinished = false
        self.campaignMomentum = 0.0

        self.currentTerm = 1
        self.billsSigned = 0
        self.billsVetoed = 0
        self.executiveOrders = 0
        self.cabinetSatisfaction = 0.7

        self.pendingDecisions = []
        self.activeEvents = []
        self.recentDecisions = []

        self.exitType = nil
        self.exitNarrative = nil
    }

    mutating func transitionToNextPhase() {
        if let next = phase.nextPhase {
            phase = next

            // Phase entry logic
            switch phase {
            case .primaries:
                generatePrimaryOpponents()
            case .generalElection:
                generateGeneralOpponent()
            case .transition:
                handleTransition()
            case .presidency:
                world.currentNarrative = "The inauguration is complete. Your presidency begins."
            default:
                break
            }
        }
    }

    mutating func generatePrimaryOpponents() {
        primaryOpponents = [
            AICandidate(name: "Governor Sarah Mitchell", party: player.party, stance: .centerLeft, baseSupport: 20.0),
            AICandidate(name: "Senator James Crawford", party: player.party, stance: .left, baseSupport: 15.0),
            AICandidate(name: "Mayor David Chen", party: player.party, stance: .moderate, baseSupport: 10.0)
        ]
    }

    mutating func generateGeneralOpponent() {
        let opponentParty: PoliticalParty = player.party == .democrat ? .republican : .democrat
        generalOpponent = AICandidate(
            name: "Senator Robert Williams",
            party: opponentParty,
            stance: .centerRight,
            baseSupport: 45.0
        )
    }

    mutating func handleTransition() {
        world.currentNarrative = "Congratulations, President-elect. The transition begins."
    }

    var isGameOver: Bool {
        phase == .exited
    }

    var turnDescription: String {
        world.turnDescription
    }
}

struct AICandidate: Codable, Identifiable {
    let id: UUID
    let name: String
    let party: PoliticalParty
    let stance: PolicyStance
    var baseSupport: Double
    var currentPolling: Double
    var scandals: [String]
    var funds: Double
    var momentum: Double // positive = rising

    init(
        id: UUID = UUID(),
        name: String,
        party: PoliticalParty,
        stance: PolicyStance,
        baseSupport: Double,
        currentPolling: Double? = nil,
        scandals: [String] = [],
        funds: Double = 50_000_000,
        momentum: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.party = party
        self.stance = stance
        self.baseSupport = baseSupport
        self.currentPolling = currentPolling ?? baseSupport
        self.scandals = scandals
        self.funds = funds
        self.momentum = momentum
    }
}
