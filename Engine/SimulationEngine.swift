import Foundation

// MARK: - Main Simulation Engine
// Coordinates all game systems

@MainActor
class SimulationEngine: ObservableObject {
    @Published var gameState: GameState
    @Published var isProcessing: Bool = false
    @Published var lastError: String?

    private(set) var aiBrain: MiniMaxService?
    private let useAI: Bool
    private let persistence = PersistenceService()
    private var currentSaveName: String?
    private var debugTimer: Timer?

    init(useAI: Bool = true) {
        self.gameState = GameState()
        self.useAI = useAI
    }

    func initializeAI(apiKey: String) {
        self.aiBrain = MiniMaxService(apiKey: apiKey)
    }

    // MARK: - Game Flow

    func startNewGame(player: Player) {
        gameState = GameState(phase: .preCampaign, player: player)
        gameState.world.addLedgerEntry(LedgerEntry(
            turn: 1,
            year: 2025,
            phase: .preCampaign,
            title: "Journey Begins",
            description: "\(player.name) announces presidential candidacy"
        ))
        currentSaveName = nil
        writeDebugSnapshot()
        startDebugMonitoring(interval: 2.0)
    }

    // MARK: - Persistence

    func saveGame() throws {
        let name = currentSaveName ?? "autosave_\(Date().timeIntervalSince1970).json"
        try persistence.save(gameState, filename: name)
        currentSaveName = name
    }

    func saveGameAs(_ filename: String) throws {
        try persistence.save(gameState, filename: filename)
        currentSaveName = filename
    }

    func loadGame(_ filename: String) throws {
        gameState = try persistence.load(filename: filename)
        currentSaveName = filename
    }

    func listSavedGames() -> [SaveMetadata] {
        persistence.listSaves()
    }

    func deleteSave(_ filename: String) throws {
        try persistence.delete(filename: filename)
        if currentSaveName == filename {
            currentSaveName = nil
        }
    }

    func hasSavedGames() -> Bool {
        !persistence.listSaves().isEmpty
    }

    func advanceTurn() async {
        isProcessing = true
        let startTime = Date()

        // 0. Decrement all action cooldowns at start of turn
        for actionId in gameState.actionCooldowns.keys {
            if let remaining = gameState.actionCooldowns[actionId], remaining > 0 {
                gameState.actionCooldowns[actionId] = remaining - 1
            }
        }
        // Remove any zeroed cooldowns
        gameState.actionCooldowns = gameState.actionCooldowns.filter { $0.value > 0 }

        // 0b. Clear pending decisions and events from last turn — fresh slate each turn
        gameState.pendingDecisions = []
        gameState.activeEvents = []

        // 1. Calculate time passage
        gameState.world.advanceTime()

        // 2. AI-driven state updates
        if useAI, let ai = aiBrain {
            await processAIConsequences()
            await possiblyGenerateEvent(using: ai)
        } else {
            // Fallback: simple state updates without AI
            processSimpleStateUpdates()
        }

        // 3. Resolve any pending decisions that expired
        resolveExpiredDecisions()

        // 4. Update political calculations
        updatePolling()

        // Record approval history
        gameState.resources.approvalHistory.append(gameState.world.approvalRating)
        if gameState.resources.approvalHistory.count > 20 {
            gameState.resources.approvalHistory.removeFirst()
        }

        // 5. Sync electoral votes from polling data (general election only)
        if gameState.phase == .generalElection {
            updateElectoralVotesFromPolling()
        }

        // 6. Resolve old events (remove after 10 turns, mark resolved after 5)
        resolveOldEvents()

        // 6. Check for phase transitions
        checkPhaseTransition()

        // 6. Check for game-ending conditions
        checkGameEndConditions()

        // 7. Regenerate political capital (small amount per turn)
        let pcRegen = 3.0  // base regen per turn
        let approvalBonus = gameState.world.approvalRating / 100.0 * 2.0  // 0-2 extra at 0-100% approval
        gameState.resources.politicalCapital = min(100, gameState.resources.politicalCapital + pcRegen + approvalBonus)

        // 8. Clamp all resources to valid ranges (final safety net)
        clampResources()

        // Ensure minimum visible processing time for UX
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed < 0.3 {
            try? await Task.sleep(nanoseconds: UInt64((0.3 - elapsed) * 1_000_000_000))
        }

        isProcessing = false
        writeDebugSnapshot()
    }

    // MARK: - Player Actions

    /// Returns true if the action can be performed right now (has resources, not on cooldown)
    func canPerformAction(_ action: GameAction) -> Bool {
        // Check cooldown
        if let remaining = gameState.actionCooldowns[action.id], remaining > 0 {
            return false
        }
        // Check resource costs
        for cost in action.costs {
            switch cost.type {
            case .politicalCapital:
                if gameState.resources.politicalCapital < cost.amount { return false }
            case .money:
                if gameState.resources.campaignFunds < cost.amount { return false }
            case .mediaCycle:
                if gameState.resources.mediaCycles < Int(cost.amount) { return false }
            case .time:
                break
            }
        }
        return true
    }

    /// Remaining cooldown turns for an action (0 if not on cooldown)
    func cooldownRemaining(for action: GameAction) -> Int {
        gameState.actionCooldowns[action.id] ?? 0
    }

    /// Perform an action: deducts costs, applies effects, starts cooldown
    func performAction(_ action: GameAction) {
        // Validate resource costs first
        for cost in action.costs {
            switch cost.type {
            case .politicalCapital:
                if gameState.resources.politicalCapital < cost.amount {
                    gameState.world.currentNarrative = "Not enough Political Capital for: \(action.name)"
                    return
                }
            case .money:
                if gameState.resources.campaignFunds < cost.amount {
                    gameState.world.currentNarrative = "Not enough Campaign Funds for: \(action.name)"
                    return
                }
            case .mediaCycle:
                if gameState.resources.mediaCycles < Int(cost.amount) {
                    gameState.world.currentNarrative = "Not enough Media Cycles for: \(action.name)"
                    return
                }
            case .time:
                break
            }
        }

        // Deduct costs
        for cost in action.costs {
            switch cost.type {
            case .politicalCapital:
                gameState.resources.politicalCapital -= cost.amount
            case .money:
                gameState.resources.campaignFunds -= cost.amount
            case .mediaCycle:
                gameState.resources.mediaCycles -= Int(cost.amount)
            case .time:
                break
            }
        }

        // Apply action effects
        for (key, value) in action.effects {
            switch key {
            case "mediaFavorability":
                gameState.world.mediaFavorability = max(0, min(100, gameState.world.mediaFavorability + value))
            case "approvalRating":
                gameState.world.approvalRating = max(0, min(100, gameState.world.approvalRating + value))
            case "momentum":
                gameState.campaignMomentum = max(-10, min(10, gameState.campaignMomentum + value))
            case "congressionalSupport":
                gameState.world.congressionalSupport = max(0, min(100, gameState.world.congressionalSupport + value))
            case "partyUnityScore":
                gameState.world.partyUnityScore = max(0, min(100, gameState.world.partyUnityScore + value))
            case "campaignFunds":
                gameState.resources.campaignFunds = max(0, gameState.resources.campaignFunds + value)
            case "globalInfluence":
                gameState.world.globalInfluence = max(0, min(100, gameState.world.globalInfluence + value))
            case "statePolling":
                gameState.popularVoteMargin = max(-20, min(20, gameState.popularVoteMargin + value))
            case "opponentPolling":
                gameState.opponentPolling = max(0, min(100, gameState.opponentPolling + value))
            case "cabinetSatisfaction":
                gameState.cabinetSatisfaction = max(0, min(100, gameState.cabinetSatisfaction + value))
            case "relationshipTarget":
                break
            default:
                break
            }
        }

        // Set cooldown if action has one
        if action.cooldown > 0 {
            gameState.actionCooldowns[action.id] = action.cooldown
        }

        // Show feedback
        gameState.world.currentNarrative = "You used: \(action.name)"
    }

    func makeDecision(_ decision: Decision, choiceIndex: Int) async {
        guard choiceIndex < decision.options.count else { return }

        isProcessing = true
        defer { isProcessing = false }

        let chosenOption = decision.options[choiceIndex]
        let rollResult = rollDice()

        // Determine outcome based on roll and risk
        let outcome = determineOutcome(roll: rollResult, option: chosenOption)

        // Get AI-calculated consequences or use fallback
        var narrative: String
        var consequences: [EventConsequence]

        if useAI, let ai = aiBrain {
            let input = MiniMaxService.ConsequenceInput(
                gameState: gameState.toAISummary(),
                playerAction: decision.prompt + " -> " + chosenOption.text,
                context: decision.context
            )

            do {
                let result = try await ai.calculateConsequences(input: input)
                narrative = result.narrative
                consequences = result.cascadingEffects.map {
                    EventConsequence(affectedArea: $0.domain, delta: $0.effect, narrative: $0.explanation)
                }

                // Apply AI-calculated effects
                applyEffects(result.immediateEffects)
            } catch {
                narrative = "The outcome was \(outcome)."
                consequences = []
            }
        } else {
            narrative = calculateSimpleNarrative(decision: decision, option: chosenOption, outcome: outcome)
            consequences = []
            applySimpleEffects(option: chosenOption, outcome: outcome)
        }

        // Record result
        let result = DecisionResult(
            decision: decision,
            chosenOption: chosenOption,
            rollResult: rollResult,
            outcome: outcome,
            narrative: narrative,
            consequences: consequences,
            turn: gameState.world.currentTurn
        )

        gameState.recentDecisions.insert(result, at: 0)
        if gameState.recentDecisions.count > 10 {
            gameState.recentDecisions.removeLast()
        }

        // Remove resolved decision
        gameState.pendingDecisions.removeAll { $0.id == decision.id }

        // Add to ledger
        gameState.world.addLedgerEntry(LedgerEntry(
            turn: gameState.world.currentTurn,
            year: gameState.world.currentYear,
            phase: gameState.phase,
            title: decision.prompt,
            description: narrative,
            effects: chosenOption.expectedBenefits
        ))

        isProcessing = false
        writeDebugSnapshot()
    }

    func declareCandidacy() async {
        // Guard: can't declare if already in campaign or later
        guard gameState.phase == .preCampaign else { return }

        gameState.phase = .campaign
        gameState.world.currentNarrative = "The campaign begins. \(gameState.player.name) officially announces their candidacy."
        await generateInitialDecisions()
    }

    func selectVP(_ name: String) {
        gameState.chosenVP = name
        gameState.world.currentNarrative = "\(name) has been selected as your running mate."
    }

    // MARK: - Private Methods

    private func rollDice() -> Double {
        Double.random(in: 0...1)
    }

    private func determineOutcome(roll: Double, option: DecisionOption) -> DecisionOutcome {
        let threshold = option.riskProbability

        if roll < threshold * 0.6 {
            return .failure(probability: threshold)
        } else if roll < threshold {
            return .mixed(probability: threshold)
        } else {
            return .success(probability: threshold)
        }
    }

    private func applyEffects(_ effects: [String: Double]) {
        for (key, value) in effects {
            switch key.lowercased() {
            case "approval", "approvalrating":
                gameState.world.approvalRating = max(0, min(100, gameState.world.approvalRating + value))
            case "gdp", "gdpgrowth":
                gameState.world.gdpGrowth = max(-10, min(15, gameState.world.gdpGrowth + value))
            case "unemployment":
                gameState.world.unemployment = max(0, min(25, gameState.world.unemployment + value))
            case "inflation":
                gameState.world.inflation = max(0, min(20, gameState.world.inflation + value))
            case "partyunity":
                gameState.world.partyUnityScore = max(0, min(100, gameState.world.partyUnityScore + value))
            case "congressionalsupport":
                gameState.world.congressionalSupport = max(0, min(100, gameState.world.congressionalSupport + value))
            default:
                // Unknown effect - log it
                break
            }
        }
    }

    private func processAIConsequences() async {
        // AI calculates ongoing consequences based on current state
    }

    private func possiblyGenerateEvent(using ai: MiniMaxService) async {
        let randomFactor = Double.random(in: 0...1)

        // Higher chance of event when approval is low or economy is struggling
        var eventProbability = 0.15 // base 15%
        if gameState.world.approvalRating < 40 { eventProbability += 0.15 }
        if gameState.world.gdpGrowth < 0 { eventProbability += 0.15 }
        if gameState.world.inflation > 8 { eventProbability += 0.1 }

        if randomFactor < eventProbability {
            let input = MiniMaxService.EventGenerationInput(
                gameState: gameState.toAISummary(),
                possibleCategories: ["economic", "political", "international", "crisis", "scandal"],
                randomnessFactor: randomFactor
            )

            do {
                let result = try await ai.generateEvent(input: input)
                if let event = result.generatedEvent {
                    let gameEvent = GameEvent(
                        title: event.title,
                        description: event.description,
                        category: EventCategory(rawValue: event.category) ?? .political,
                        turnOccurred: gameState.world.currentTurn,
                        isAIGenerated: true
                    )
                    gameState.activeEvents.append(gameEvent)
                    gameState.world.currentNarrative = event.description
                }
            } catch {
                // Silent fail - use simple event generation
                generateSimpleEvent()
            }
        }
    }

    private func generateSimpleEvent() {
        // Only generate events appropriate to the current phase
        let possibleEvents = availableEventsForPhase(gameState.phase)
        guard !possibleEvents.isEmpty else { return }

        // Check if we already have this event type active (avoid duplicates)
        let selected = possibleEvents.randomElement()!
        let alreadyHasSimilar = gameState.activeEvents.contains {
            $0.title == selected.0 && !$0.isResolved
        }
        guard !alreadyHasSimilar else { return }

        // Prevent same category from firing more than twice in last 5 turns
        let recentCategoryCount = gameState.activeEvents.filter {
            $0.category == selected.2 && !$0.isResolved &&
            gameState.world.currentTurn - $0.turnOccurred < 5
        }.count
        guard recentCategoryCount < 2 else { return }

        let event = GameEvent(
            title: selected.0,
            description: selected.1,
            category: selected.2,
            turnOccurred: gameState.world.currentTurn
        )
        gameState.activeEvents.append(event)
    }

    private func availableEventsForPhase(_ phase: GamePhase) -> [(String, String, EventCategory)] {
        switch phase {
        case .preCampaign, .campaign:
            // Candidate-phase events: building momentum, name recognition, media
            return [
                ("Media Buzz", "Your campaign is generating buzz in the media.", .political),
                ("Fundraising Spike", "A major donor is considering a large contribution.", .political),
                ("Opponent Stumbles", "A rival candidate faces a gaffe that you could capitalize on.", .political),
                ("Voter Enthusiasm", "Grassroots supporters show unprecedented energy.", .achievement),
                ("Policy Speech", "Your policy team suggests a major address to frame the debate.", .political)
            ]
        case .primaries:
            // Primary-specific events
            return [
                ("State Win", "You win a crucial primary state, momentum is on your side.", .achievement),
                ("Opponent Attack", "A primary rival launches attack ads against you.", .political),
                ("Delegate Drama", "A dispute over delegates emerges in a key state.", .political),
                ("Endorsement", "A prominent party figure endorses your campaign.", .achievement),
                ("Ground Game", "Your organization shows strength in early states.", .political)
            ]
        case .convention:
            return [
                ("Delegates Unite", "Party delegates show unity behind your candidacy.", .achievement),
                ("VP Speculation", "Media speculates about your potential running mate.", .social),
                ("Platform Fight", "A battle over the party platform ensues.", .political),
                ("Prime Time", "Your convention speech receives rave reviews.", .social)
            ]
        case .generalElection:
            return [
                ("Debate Prep", "Your team urges you to focus on debate preparation.", .political),
                ("Opponent Gaffe", "Your opponent makes a campaign-trail mistake.", .political),
                ("Swing State Poll", "A new poll shows movement in a key swing state.", .political),
                ("Foreign Policy Moment", "An international event demands a presidential response.", .international),
                ("Ground Game", "Your field operation shows impressive organization.", .achievement)
            ]
        case .transition:
            return [
                ("Cabinet Interest", "Prospective cabinet members express interest.", .political),
                ("Transition Briefing", "Outgoing administration offers transition cooperation.", .political),
                ("Policy Planning", "Your team begins drafting first 100 days agenda.", .political)
            ]
        case .presidency, .lameDuck:
            // Governing-phase events: actual crises and policy
            return [
                ("Oil Crisis", "Oil prices spike unexpectedly, affecting the economy.", .economic),
                ("Scandal Emerges", "A potential scandal involving your administration is reported.", .scandal),
                ("Foreign Crisis", "A diplomatic crisis erupts requiring presidential attention.", .international),
                ("Economic Report", "The quarterly economic report shows unexpected trends.", .economic),
                ("Party Tension", "Tensions within your party threaten legislative unity.", .political),
                ("Budget Battle", "Congress faces a deadline on spending negotiations.", .political),
                ("Healthcare Debate", "Healthcare policy dominates the national conversation.", .political),
                ("Immigration Issue", "Border situations create pressure for policy action.", .political),
                ("Climate Push", "Environmental groups lobby for executive action.", .political),
                ("Trade Talks", "Trading partners seek to renegotiate terms.", .international)
            ]
        case .exited:
            return []
        }
    }

    private func resolveOldEvents() {
        // Events auto-resolve after being active for 5+ turns
        let maxEventAge = 5
        for i in gameState.activeEvents.indices {
            let age = gameState.world.currentTurn - gameState.activeEvents[i].turnOccurred
            if age >= maxEventAge && !gameState.activeEvents[i].isResolved {
                gameState.activeEvents[i].isResolved = true
                gameState.activeEvents[i].resolution = "This situation has naturally subsided over time."
            }
        }

        // Remove old resolved events (keep last 10)
        gameState.activeEvents.removeAll { event in
            event.isResolved &&
            event.turnOccurred < gameState.world.currentTurn - 10
        }
    }

    private func processSimpleStateUpdates() {
        // Simple economic drift
        if Bool.random() {
            gameState.world.gdpGrowth += Double.random(in: -0.5...0.5)
        }
        if Bool.random() {
            gameState.world.unemployment += Double.random(in: -0.2...0.2)
        }

        // Approval drift toward economic reality
        if gameState.world.gdpGrowth > 3 && gameState.world.unemployment < 5 {
            gameState.world.approvalRating += 0.5
        } else if gameState.world.gdpGrowth < 0 || gameState.world.unemployment > 8 {
            gameState.world.approvalRating -= 0.5
        }
    }

    private func resolveExpiredDecisions() {
        gameState.pendingDecisions.removeAll { decision in
            if let deadline = decision.deadline {
                return gameState.world.currentTurn > deadline
            }
            return false
        }
    }

    private func updatePolling() {
        // Primary polling
        if gameState.phase == .primaries {
            var totalPlayerSupport = 30.0 + gameState.world.approvalRating / 10

            for opponent in gameState.primaryOpponents {
                totalPlayerSupport -= opponent.momentum * 2
            }

            totalPlayerSupport = max(15, min(60, totalPlayerSupport))
            // Would update actual polling data here
        }

        // General election polling
        if gameState.phase == .generalElection {
            let momentumEffect = gameState.campaignMomentum * 5
            let approvalEffect = (gameState.world.approvalRating - 50) / 5

            gameState.popularVoteMargin = momentumEffect + approvalEffect

            // Update state polling based on momentum and national environment
            updateStatePolling()
        }
    }

    private func updateStatePolling() {
        // Key swing states that shift most with campaign momentum
        let swingStates = ["PA", "MI", "WI", "AZ", "NV", "GA", "NC", "FL", "OH"]
        let safePlayerStates = ["CA", "NY", "IL", "MA", "WA", "OR", "MD", "NJ", "VT", "RI", "CT", "HI", "ME"]
        let safeOpponentStates = ["TX", "AL", "MS", "LA", "AR", "OK", "WV", "KY", "TN", "IN", "ID", "UT", "WY", "MT", "ND", "SD", "NE"]

        let nationalTrend = gameState.popularVoteMargin / 2 // How player is trending nationally

        for state in swingStates {
            let current = gameState.pollingData[state] ?? 50.0
            let shift = nationalTrend * Double.random(in: 0.5...1.5) + Double.random(in: -2...2)
            let newPolling = max(20, min(80, current + shift))
            gameState.pollingData[state] = newPolling
        }

        for state in safePlayerStates {
            let current = gameState.pollingData[state] ?? 50.0
            let shift = nationalTrend * Double.random(in: 0.2...0.5) + Double.random(in: -1...1)
            gameState.pollingData[state] = max(50, min(85, current + shift))
        }

        for state in safeOpponentStates {
            let current = gameState.pollingData[state] ?? 50.0
            let shift = nationalTrend * Double.random(in: 0.2...0.5) + Double.random(in: -1...1)
            gameState.pollingData[state] = max(15, min(50, current + shift))
        }
    }

    private func updateElectoralVotesFromPolling() {
        // Standard state polling thresholds (simplified model)
        let stateEVs: [String: Int] = [
            "CA": 54, "TX": 40, "FL": 30, "NY": 28, "PA": 19, "IL": 19,
            "OH": 17, "GA": 16, "NC": 16, "MI": 15, "NJ": 14, "VA": 13,
            "WA": 12, "AZ": 11, "IN": 11, "MO": 10, "MD": 10, "WI": 10,
            "CO": 10, "MN": 10, "SC": 9, "AL": 9, "LA": 8, "KY": 8,
            "OR": 8, "OK": 7, "CT": 7, "UT": 6, "IA": 6, "NV": 6,
            "AR": 6, "MS": 6, "KS": 6, "NM": 5, "NE": 5, "ID": 4,
            "WV": 4, "HI": 4, "ME": 4, "NH": 4, "RI": 4, "MT": 3,
            "DE": 3, "SD": 3, "ND": 3, "AK": 3, "VT": 3, "WY": 3,
            "DC": 3
        ]

        var playerEVs = 0
        for (state, ev) in stateEVs {
            let polling = gameState.pollingData[state] ?? 50.0
            let margin = polling - 50.0
            // Player wins state if polling > opponent by 5+ points
            if margin > 5 {
                playerEVs += ev
            }
        }

        gameState.electoralVotes = playerEVs
    }

    private func checkPhaseTransition() {
        switch gameState.phase {
        case .campaign:
            if gameState.primaryDelegates >= gameState.totalDelegatesNeeded / 2 {
                gameState.transitionToNextPhase()
            }
        case .primaries:
            // Convention triggered when all primaries finished
            if gameState.primaryDelegates >= gameState.totalDelegatesNeeded {
                gameState.transitionToNextPhase()
            }
        case .generalElection:
            // Auto-win if electoral votes >= 270
            // Note: electoralVotes is synced from UI's computed playerEVs
            if gameState.electoralVotes >= 270 {
                gameState.transitionToNextPhase()
            }
            break
        case .presidency:
            // Move to lame duck after 8 years (assume 8 * 52 turns)
            if gameState.world.currentTurn > 416 { // 8 years
                gameState.transitionToNextPhase()
            }
        default:
            break
        }
    }

    private func checkGameEndConditions() {
        // Lost election: opponent reaches 270 or turn limit exceeded
        if gameState.phase == .generalElection {
            // Opponent wins if player hasn't won and opponent has 270+ EVs
            // We compute opponent EVs as 538 - playerEVs - tossup EVs (approximate)
            let opponentEVs = 538 - gameState.electoralVotes
            if gameState.electoralVotes < 270 && opponentEVs >= 270 {
                gameState.phase = .exited
                gameState.exitType = .lostElection
                gameState.world.currentNarrative = "Your opponent has reached 270 electoral votes. You have lost the election."
            }
        }

        // Impeachment
        if gameState.world.approvalRating < 20 && gameState.phase == .presidency {
            // Chance of impeachment
            if Double.random(in: 0...1) < 0.1 {
                gameState.phase = .exited
                gameState.exitType = .impeached
            }
        }

        // Death in office (low probability but age/health dependent)
        if gameState.phase == .presidency || gameState.phase == .lameDuck {
            let deathChance = (1.0 - gameState.player.health) * 0.001 * Double(gameState.player.age - 60)
            if Double.random(in: 0...1) < deathChance {
                gameState.phase = .exited
                gameState.exitType = .died
            }
        }
    }

    private func generateInitialDecisions() async {
        // Generate campaign-specific decisions
        let decision1 = Decision(
            prompt: "Campaign Strategy Choice",
            context: "Your first major campaign decision looms. Your team presents three paths forward.",
            options: [
                DecisionOption(text: "Focus on economic message - bread and butter issues", isRisky: false, expectedBenefits: ["approvalRating": 2.0]),
                DecisionOption(text: "Go negative on opponent - attack their record", isRisky: true, riskProbability: 0.4, expectedBenefits: ["approvalRating": -1.0]),
                DecisionOption(text: "Run on unity and bipartisan themes", isRisky: false, expectedBenefits: ["partyUnity": 5.0])
            ],
            turn: gameState.world.currentTurn,
            phase: .campaign
        )

        gameState.pendingDecisions.append(decision1)
    }

    private func calculateSimpleNarrative(decision: Decision, option: DecisionOption, outcome: DecisionOutcome) -> String {
        let baseResult: String
        switch outcome {
        case .success:
            baseResult = "Your choice of '\(option.text)' proved successful."
        case .mixed:
            baseResult = "Your choice of '\(option.text)' had mixed results."
        case .failure:
            baseResult = "Your choice of '\(option.text)' backfired."
        }
        return baseResult
    }

    private func applySimpleEffects(option: DecisionOption, outcome: DecisionOutcome) {
        let multiplier: Double
        switch outcome {
        case .success: multiplier = 1.0
        case .mixed: multiplier = 0.5
        case .failure: multiplier = -0.5
        }

        for (key, value) in option.expectedBenefits {
            switch key {
            case "approvalRating":
                gameState.world.approvalRating = max(0, min(100, gameState.world.approvalRating + value * multiplier))
            case "partyUnity":
                gameState.world.partyUnityScore = max(0, min(100, gameState.world.partyUnityScore + value * multiplier))
            case "campaignMomentum":
                gameState.campaignMomentum = max(-10, min(10, gameState.campaignMomentum + value * multiplier))
            default:
                break
            }
        }
    }

    private func clampResources() {
        // Clamp all mutable resources to valid ranges
        gameState.resources.politicalCapital = max(0, min(100, gameState.resources.politicalCapital))
        gameState.resources.campaignFunds = max(0, gameState.resources.campaignFunds)
        gameState.resources.mediaCycles = max(0, min(10, gameState.resources.mediaCycles))
        gameState.campaignMomentum = max(-10, min(10, gameState.campaignMomentum))

        // World state clamps
        gameState.world.approvalRating = max(0, min(100, gameState.world.approvalRating))
        gameState.world.partyUnityScore = max(0, min(100, gameState.world.partyUnityScore))
        gameState.world.congressionalSupport = max(0, min(100, gameState.world.congressionalSupport))
        gameState.world.mediaFavorability = max(0, min(100, gameState.world.mediaFavorability))
        gameState.world.donorSatisfaction = max(0, min(100, gameState.world.donorSatisfaction))
        gameState.world.globalInfluence = max(0, min(100, gameState.world.globalInfluence))
        gameState.world.internationalPrestige = max(0, min(100, gameState.world.internationalPrestige))

        // Economic bounds
        gameState.world.gdpGrowth = max(-10, min(15, gameState.world.gdpGrowth))
        gameState.world.unemployment = max(0, min(25, gameState.world.unemployment))
        gameState.world.inflation = max(0, min(20, gameState.world.inflation))
        gameState.world.stockMarketIndex = max(0, gameState.world.stockMarketIndex)
        gameState.world.consumerConfidence = max(0, min(100, gameState.world.consumerConfidence))

        // Electoral bounds
        gameState.electoralVotes = max(0, min(538, gameState.electoralVotes))
        gameState.popularVoteMargin = max(-20, min(20, gameState.popularVoteMargin))
    }

    // MARK: - Debug State (for AI observability)

    private var debugSnapshotURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".president_sim/debug_state.json")
    }

    /// Write a full debug snapshot of the current game state as JSON.
    /// Read by DebugCapture to give the AI full visibility into the app.
    func writeDebugSnapshot() {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".president_sim")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let aiSummary = gameState.toAISummary()
        let debug = DebugSnapshot(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            turn: gameState.world.currentTurn,
            year: gameState.world.currentYear,
            phase: gameState.phase.rawValue,
            turnDescription: gameState.world.turnDescription,
            politicalCapital: gameState.resources.politicalCapital,
            campaignFunds: gameState.resources.campaignFunds,
            mediaCycles: gameState.resources.mediaCycles,
            momentum: gameState.resources.momentum,
            approvalRating: gameState.world.approvalRating,
            approvalHistory: gameState.resources.approvalHistory,
            gdpGrowth: gameState.world.gdpGrowth,
            unemployment: gameState.world.unemployment,
            inflation: gameState.world.inflation,
            partyUnity: gameState.world.partyUnityScore,
            congressionalSupport: gameState.world.congressionalSupport,
            donorSatisfaction: gameState.world.donorSatisfaction,
            mediaFavorability: gameState.world.mediaFavorability,
            globalInfluence: gameState.world.globalInfluence,
            internationalPrestige: gameState.world.internationalPrestige,
            currentNarrative: gameState.world.currentNarrative,
            trendingTopic: gameState.world.trendingTopic,
            pendingDecisions: gameState.pendingDecisions.map { $0.prompt },
            activeEvents: gameState.activeEvents.map { $0.title },
            recentDecisions: gameState.recentDecisions.prefix(5).map { $0.decision.prompt },
            historicalLedger: gameState.world.historicalLedger.suffix(10).map { $0.title },
            aiSummary: aiSummary
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(debug) {
            try? data.write(to: debugSnapshotURL)
        }
    }

    /// Start writing debug snapshots every `interval` seconds.
    func startDebugMonitoring(interval: TimeInterval = 2.0) {
        stopDebugMonitoring()
        debugTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.writeDebugSnapshot()
            }
        }
    }

    /// Stop background debug monitoring.
    func stopDebugMonitoring() {
        debugTimer?.invalidate()
        debugTimer = nil
    }
}

/// Full debug snapshot structure — everything the AI needs to understand the game.
struct DebugSnapshot: Codable {
    let timestamp: String
    let turn: Int
    let year: Int
    let phase: String
    let turnDescription: String
    let politicalCapital: Double
    let campaignFunds: Double
    let mediaCycles: Int
    let momentum: Double
    let approvalRating: Double
    let approvalHistory: [Double]
    let gdpGrowth: Double
    let unemployment: Double
    let inflation: Double
    let partyUnity: Double
    let congressionalSupport: Double
    let donorSatisfaction: Double
    let mediaFavorability: Double
    let globalInfluence: Double
    let internationalPrestige: Double
    let currentNarrative: String
    let trendingTopic: String
    let pendingDecisions: [String]
    let activeEvents: [String]
    let recentDecisions: [String]
    let historicalLedger: [String]
    let aiSummary: MiniMaxService.AIGameStateSummary
}

// MARK: - GameState Extension for AI

extension GameState {
    func toAISummary() -> MiniMaxService.AIGameStateSummary {
        let topIssues: [String]
        if world.unemployment > 6 {
            topIssues = ["Jobs", "Economy", "Healthcare"]
        } else if world.gdpGrowth < 1 {
            topIssues = ["Recession", "Economy", "Stocks"]
        } else {
            topIssues = ["Healthcare", "Immigration", "Climate"]
        }

        let recentEventTitles = activeEvents.prefix(3).map { $0.title }

        let stanceMap = player.policyStances.reduce(into: [String: String]()) { result, pair in
            result[pair.key.rawValue] = pair.value.rawValue
        }

        return MiniMaxService.AIGameStateSummary(
            phase: phase.rawValue,
            turn: world.currentTurn,
            approvalRating: world.approvalRating,
            economyGDPGrowth: world.gdpGrowth,
            economyUnemployment: world.unemployment,
            economyInflation: world.inflation,
            partyUnity: world.partyUnityScore,
            congressionalSupport: world.congressionalSupport,
            globalInfluence: world.globalInfluence,
            topIssues: topIssues,
            recentEvents: recentEventTitles,
            playerPolicyStances: stanceMap
        )
    }
}
