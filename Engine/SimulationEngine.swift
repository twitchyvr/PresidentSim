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

    // Wired engine systems
    private var cabinetManager: CabinetManager!
    private var debateEngine: DebateEngine!
    private var diplomacyEngine: DiplomacyConversationEngine!
    private var intlRelationsEngine: InternationalRelationsEngine!

    init(useAI: Bool = true) {
        self.gameState = GameState()
        self.useAI = useAI

        // Initialize all subsystem engines
        self.cabinetManager = CabinetManager()
        self.debateEngine = DebateEngine()
        self.diplomacyEngine = DiplomacyConversationEngine()
        self.intlRelationsEngine = InternationalRelationsEngine()
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

    /// Resets to preCampaign phase with a default player, then opens the NewGameView sheet
    /// so the player can configure their candidate. Used by "Start New Game" in ExitedView.
    func startNewGame() {
        let defaultPlayer = Player(
            name: "Player",
            party: .democrat,
            age: 45,
            health: 0.95,
            homeState: "California",
            occupation: "Governor",
            priorExperience: ["State Legislator"]
        )
        gameState = GameState(phase: .preCampaign, player: defaultPlayer)
        gameState.world.addLedgerEntry(LedgerEntry(
            turn: 1,
            year: 2025,
            phase: .preCampaign,
            title: "Journey Begins",
            description: "\(defaultPlayer.name) announces presidential candidacy"
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

    // MARK: - Briefing Management

    func markBriefingAsRead(_ id: UUID) {
        if let index = gameState.briefings.firstIndex(where: { $0.id == id }) {
            gameState.briefings[index].isRead = true
        }
    }

    func resolveBriefing(_ id: UUID, selectedOption: Int) {
        guard let index = gameState.briefings.firstIndex(where: { $0.id == id }) else { return }
        let briefing = gameState.briefings[index]
        gameState.briefings[index].isResolved = true
        gameState.briefings[index].selectedOptionIndex = selectedOption

        // Apply effects from the selected option
        if selectedOption < briefing.options.count {
            let option = briefing.options[selectedOption]
            applyEffects(option.effects, narrative: "Briefing: \(briefing.title) — \(option.label)")
        }
    }

    var unreadBriefingsCount: Int {
        gameState.briefings.filter { !$0.isRead }.count
    }

    func insertBriefing(_ briefing: Briefing) {
        gameState.briefings.insert(briefing, at: 0)
        // Keep max 20 briefings
        if gameState.briefings.count > 20 {
            gameState.briefings.removeLast()
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

        // 0c. Clear action results from last turn
        gameState.world.actionResultsThisTurn = []

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

        // 3b. Possibly generate a new decision (keeps game moving)
        possiblyGenerateDecision()

        // 4. Update political calculations
        updatePolling()

        // 4b. Cabinet scandal check (presidency only)
        if gameState.phase == .presidency || gameState.phase == .lameDuck {
            let scandals = cabinetManager.checkForScandals(currentTurn: gameState.world.currentTurn)
            for scandal in scandals {
                // Apply scandal effects
                gameState.world.approvalRating = max(0, gameState.world.approvalRating - scandal.severity * 5)
                gameState.world.actionResultsThisTurn.append("[\(scandal.severityDescription) Crisis] \(scandal.headline)")
                // Create an active event for the scandal
                let event = GameEvent(
                    title: "Cabinet Scandal: \(scandal.memberName)",
                    description: scandal.headline,
                    category: .crisis,
                    turnOccurred: gameState.world.currentTurn,
                    isAIGenerated: false
                )
                gameState.activeEvents.append(event)
            }

            // Sync cabinet satisfaction from manager
            let perf = cabinetManager.evaluatePerformance()
            gameState.cabinetSatisfaction = perf.averageLoyalty
        }

        // 4c. International relations: generate random incidents (presidency only)
        if gameState.phase == .presidency || gameState.phase == .lameDuck {
            if let incident = intlRelationsEngine.generateRandomIncident(currentTurn: gameState.world.currentTurn) {
                let impact = intlRelationsEngine.calculateImpact(for: incident)
                gameState.internationalIncidents.append(incident)
                // Apply impact
                gameState.world.globalInfluence = max(0, min(100, gameState.world.globalInfluence + impact.globalInfluenceChange))
                gameState.world.approvalRating = max(0, min(100, gameState.world.approvalRating + impact.domesticApprovalChange))
                // Update relationships in WorldState
                for (country, delta) in impact.relationshipChanges {
                    if let current = gameState.world.relationsWithAllies[country] {
                        gameState.world.relationsWithAllies[country] = max(-100, min(100, current + delta))
                    }
                }
                gameState.world.actionResultsThisTurn.append("[\(incident.title)] \(incident.description)")
                let event = GameEvent(
                    title: incident.title,
                    description: incident.description,
                    category: .international,
                    turnOccurred: gameState.world.currentTurn,
                    isAIGenerated: false
                )
                gameState.activeEvents.append(event)
            }
        }

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
                    gameState.world.actionResultsThisTurn.append("Not enough Political Capital for: \(action.name)")
                    return
                }
            case .money:
                if gameState.resources.campaignFunds < cost.amount {
                    gameState.world.actionResultsThisTurn.append("Not enough Campaign Funds for: \(action.name)")
                    return
                }
            case .mediaCycle:
                if gameState.resources.mediaCycles < Int(cost.amount) {
                    gameState.world.actionResultsThisTurn.append("Not enough Media Cycles for: \(action.name)")
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
                // Diplomatic actions handle this via initiateDiplomacy; this is a fallback
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
        gameState.world.actionResultsThisTurn.append("You used: \(action.name)")

        // Model NPC reactions asynchronously (fire-and-forget)
        applyNPCReactions(for: action)
    }

    // MARK: - NPC Behavior Modeling

    /// Determines which NPC types are relevant to a given action category
    private func relevantNPCTypes(for action: GameAction) -> [String] {
        switch action.category {
        case .communication:
            return ["media", "congress"]
        case .travel:
            return ["donor"]
        case .diplomatic:
            return ["foreign_leader"]
        case .executive:
            return ["congress", "donor"]
        case .political:
            return ["congress", "donor", "media"]
        case .personnel:
            return ["congress", "donor"]
        }
    }

    /// Fires NPC behavior modeling for all relevant NPC types after an action is taken.
    /// Updates world state with mood changes and appends reaction narratives.
    private func applyNPCReactions(for action: GameAction) {
        guard let ai = aiBrain else { return }

        let npcTypes = relevantNPCTypes(for: action)
        let gameSummary = gameState.toAISummary()

        Task { @MainActor [weak self] in
            guard let self = self else { return }

            for npcType in npcTypes {
                let input = MiniMaxService.NPCBehaviorInput(
                    npcType: npcType,
                    npcSpecifics: self.npcSpecifics(for: npcType),
                    gameState: gameSummary,
                    playerAction: action.name
                )

                do {
                    let output = try await ai.modelNPCBehavior(input: input)
                    self.applyNPCMoodChange(npcType: npcType, moodChange: output.moodChange)
                    if !output.narrative.isEmpty {
                        self.gameState.world.actionResultsThisTurn.append(output.narrative)
                    }
                } catch {
                    self.lastError = "NPC behavior modeling failed: \(error.localizedDescription)"
                    print("[SimulationEngine] NPC modeling error: \(error)")
                }
            }
        }
    }

    /// Returns NPC-specific details for the behavior prompt
    private func npcSpecifics(for npcType: String) -> String {
        switch npcType {
        case "congress":
            return "Congressional support: \(Int(gameState.world.congressionalSupport))%, Party unity: \(Int(gameState.world.partyUnityScore))%"
        case "donor":
            return "Donor satisfaction: \(Int(gameState.world.donorSatisfaction))%, Campaign funds available: $\(Int(gameState.resources.campaignFunds))K"
        case "media":
            return "Media favorability: \(Int(gameState.world.mediaFavorability))%, Trending topic: \(gameState.world.trendingTopic)"
        case "foreign_leader":
            return "Global influence: \(Int(gameState.world.globalInfluence))%, Key allies: UK, France, Germany"
        default:
            return ""
        }
    }

    /// Applies an NPC's mood change to the appropriate WorldState field
    private func applyNPCMoodChange(npcType: String, moodChange: Double) {
        let change = moodChange // clamp if needed
        switch npcType {
        case "congress":
            gameState.world.congressionalSupport = max(0, min(100, gameState.world.congressionalSupport + change))
        case "donor":
            gameState.world.donorSatisfaction = max(0, min(100, gameState.world.donorSatisfaction + change))
        case "media":
            gameState.world.mediaFavorability = max(0, min(100, gameState.world.mediaFavorability + change))
        case "foreign_leader":
            gameState.world.globalInfluence = max(0, min(100, gameState.world.globalInfluence + change))
        default:
            break
        }
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
                self.lastError = "AI consequence calculation failed: \(error.localizedDescription)"
                print("[SimulationEngine] Consequence calculation error: \(error)")
                narrative = "Your choice \(outcome.verbPhrase). The political landscape shifts accordingly."
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
        gameState.world.actionResultsThisTurn.append("The campaign begins. \(gameState.player.name) officially announces their candidacy.")
        await generateInitialDecisions()
    }

    func selectVP(_ name: String) {
        gameState.chosenVP = name
        gameState.world.actionResultsThisTurn.append("\(name) has been selected as your running mate.")
        gameState.transitionToNextPhase()
    }

    // MARK: - Diplomacy (DiplomacyConversationEngine wiring)

    /// Initiate a diplomatic conversation with a foreign leader.
    /// - Parameters:
    ///   - country: The country name (e.g. "France", "China")
    ///   - statement: The player's diplomatic statement or action
    /// - Returns: The DiplomaticExchange with leader response and relationship delta
    @discardableResult
    func initiateDiplomacy(country: String, statement: String) -> DiplomaticExchange? {
        // Find the Country object matching the string name
        let countryObject = Country.presidentSimCountries.first { $0.name == country }

        let relationship = gameState.world.relationsWithAllies[country]
            ?? gameState.world.relationsWithAdversaries[country]
            ?? 50.0

        guard let target = countryObject else {
            gameState.world.actionResultsThisTurn.append("Unknown country: \(country)")
            return nil
        }

        let exchange = diplomacyEngine.initiateConversation(
            with: target,
            playerStatement: statement,
            relationship: relationship,
            currentTurn: gameState.world.currentTurn
        )

        // Apply relationship change
        if let current = gameState.world.relationsWithAllies[country] {
            gameState.world.relationsWithAllies[country] = max(-100, min(100, current + exchange.relationshipDelta))
        } else if let current = gameState.world.relationsWithAdversaries[country] {
            gameState.world.relationsWithAdversaries[country] = max(-100, min(100, current + exchange.relationshipDelta))
        }

        // Update global influence based on diplomacy quality
        if exchange.relationshipDelta > 0 {
            gameState.world.globalInfluence = max(0, min(100, gameState.world.globalInfluence + exchange.relationshipDelta * 0.2))
        }

        gameState.world.actionResultsThisTurn.append("[\(country)] \(exchange.playerStatement) — \(exchange.leaderResponse)")

        return exchange
    }

    // MARK: - Debates (DebateEngine wiring)

    /// Start a new debate of the given type, stored in gameState for the UI to present questions.
    func startDebate(type: DebateType) async {
        let debate = await debateEngine.generateDebate(
            type: type,
            turn: gameState.world.currentTurn
        )
        gameState.activeDebate = debate
        gameState.world.actionResultsThisTurn.append("A \(type.description) has been scheduled.")
    }

    /// Submit the player's answer to a specific debate question.
    /// - Parameters:
    ///   - questionId: The ID of the question being answered
    ///   - answer: The player's text response
    func submitDebateAnswer(questionId: UUID, answer: String) async {
        guard var debate = gameState.activeDebate else { return }

        if let index = debate.questions.firstIndex(where: { $0.id == questionId }) {
            debate.questions[index].playerResponse = answer
            gameState.activeDebate = debate
        }
    }

    /// Conclude the active debate and get performance results.
    func concludeDebate(playerCharisma: Double, playerIntelligence: Double) async -> DebatePerformance? {
        guard let debate = gameState.activeDebate else { return nil }

        // Build player answers map
        var playerAnswers: [UUID: String] = [:]
        for question in debate.questions {
            if let response = question.playerResponse {
                playerAnswers[question.id] = response
            }
        }

        let opponentStrength = debate.type == .general ? 65.0 : 50.0

        let performance = await debateEngine.conductDebate(
            debate: debate,
            playerAnswers: playerAnswers,
            playerCharisma: playerCharisma,
            playerIntelligence: playerIntelligence,
            opponentStrength: opponentStrength
        )

        // Apply debate performance effects
        let approvalSwing = performance.momentumSwing * 0.5  // momentum translates partially to approval
        gameState.world.approvalRating = max(0, min(100, gameState.world.approvalRating + approvalSwing))
        gameState.campaignMomentum = max(-10, min(10, gameState.campaignMomentum + performance.momentumSwing))
        gameState.debateFinished = true

        gameState.world.actionResultsThisTurn.append("Debate concluded: \(performance.overallWinner == .player ? "You won the debate!" : "Your opponent won the debate.")")

        gameState.activeDebate = nil
        return performance
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

    private func applyEffects(_ effects: [String: Double], narrative: String = "") {
        if !narrative.isEmpty {
            let entry = LedgerEntry(
                turn: gameState.world.currentTurn,
                year: gameState.world.currentYear,
                phase: gameState.phase,
                title: narrative,
                description: narrative,
                effects: effects
            )
            gameState.world.historicalLedger.insert(entry, at: 0)
            if gameState.world.historicalLedger.count > 50 {
                gameState.world.historicalLedger.removeLast()
            }
        }

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
            case "mediafavorability":
                gameState.world.mediaFavorability = max(0, min(100, gameState.world.mediaFavorability + value))
            case "globalinfluence":
                gameState.world.globalInfluence = max(0, min(100, gameState.world.globalInfluence + value))
            case "campaignfunds":
                gameState.resources.campaignFunds = max(0, gameState.resources.campaignFunds + value)
            case "momentum":
                gameState.resources.momentum = max(-10, min(10, gameState.resources.momentum + value))
            case "politicalcapital":
                gameState.resources.politicalCapital = max(0, min(100, gameState.resources.politicalCapital + value))
            case "internationalprestige":
                gameState.world.internationalPrestige = max(0, min(100, gameState.world.internationalPrestige + value))
            case "donorsatisfaction":
                gameState.world.donorSatisfaction = max(0, min(100, gameState.world.donorSatisfaction + value))
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
                    gameState.world.actionResultsThisTurn.append(event.description)
                }
            } catch {
                self.lastError = "AI event generation failed: \(error.localizedDescription)"
                print("[SimulationEngine] Event generation error: \(error)")
                generateSimpleEvent()
            }
        }
    }

    // MARK: - High-Stakes Events that Create Briefings

    private let briefingEvents: Set<String> = [
        "Media Interview",
        "Endorsement News",
        "Debate Prep Crisis",
        "Opposition Research",
        "Scandal Investigation",
        "Leaked Memo",
        "Press Briefing Tensions",
        "Ethics Investigation",
        "Tariff Shock",
        "Debt Ceiling Deadline",
        "Government Shutdown Threat",
        "Primary Challenge",
        "Filibuster Threat",
        "Supreme Court Nominee"
    ]

    private func createBriefingForEvent(title: String, description: String, category: EventCategory) -> Briefing? {
        let currentTurn = gameState.world.currentTurn
        let deadline = currentTurn + Int.random(in: 2...4)

        switch title {
        case "Media Interview":
            return Briefing(
                type: .media,
                title: "Prime-Time Interview Request",
                summary: description,
                urgency: 3,
                turnReceived: currentTurn,
                deadline: deadline,
                options: [
                    BriefingOption(
                        label: "Accept — Go Bold",
                        description: "Take the prime-time slot and deliver a forceful, memorable performance.",
                        pros: ["High media visibility", "Chance to control the narrative"],
                        cons: ["High risk if you stumble", "Hostile questions could backfire"],
                        effects: ["approval": 5.0, "mediaFavorability": 8.0]
                    ),
                    BriefingOption(
                        label: "Accept — Stay On Message",
                        description: "Take the slot but stick to rehearsed talking points regardless of questions.",
                        pros: ["Safer approach", "Steady message delivery"],
                        cons: ["May seem evasive", "Lower viral potential"],
                        effects: ["approval": 2.0, "mediaFavorability": 3.0]
                    ),
                    BriefingOption(
                        label: "Decline Politely",
                        description: "Thank them but cite a scheduling conflict. Offer an alternative time.",
                        pros: ["Avoid risky exposure", "Maintain dignity"],
                        cons: ["Seen as avoiding scrutiny", "Missed opportunity for momentum"],
                        effects: ["approval": -2.0, "mediaFavorability": -4.0]
                    ),
                    BriefingOption(
                        label: "Send a Surrogate",
                        description: "Send your campaign manager or a senior surrogate instead.",
                        pros: ["Avoid direct risk", "Lets surrogates take the hits"],
                        cons: ["Seen as avoiding accountability", "Weaker impact"],
                        effects: ["approval": -3.0, "partyUnity": 2.0]
                    )
                ]
            )

        case "Endorsement News":
            return Briefing(
                type: .campaign,
                title: "Major Endorsement Secured",
                summary: description,
                urgency: 2,
                turnReceived: currentTurn,
                deadline: deadline,
                options: [
                    BriefingOption(
                        label: "Leverage Aggressively",
                        description: "Broadcast the endorsement everywhere. Make it the centerpiece of your messaging.",
                        pros: ["Maximum momentum", "Energizes supporters"],
                        cons: ["May appear overconfident", "Draws attention to gaps in your coalition"],
                        effects: ["momentum": 5.0, "partyUnity": -2.0]
                    ),
                    BriefingOption(
                        label: "Thank Privately",
                        description: "Issue a measured, gracious statement but don't oversell.",
                        pros: ["Appears dignified", "Doesn't alienate non-supporters"],
                        cons: ["Misses momentum opportunity", "Endorser may feel underutilized"],
                        effects: ["donorSatisfaction": 3.0, "momentum": 1.0]
                    ),
                    BriefingOption(
                        label: "Use to Reach Skeptics",
                        description: "The endorser helps you reach demographics that were skeptical of your campaign.",
                        pros: ["Expands your coalition", "Credibility transfer"],
                        cons: ["Requires coordination", "Message may get diluted"],
                        effects: ["approval": 4.0, "mediaFavorability": 2.0]
                    )
                ]
            )

        case "Debate Prep Crisis":
            return Briefing(
                type: .campaign,
                title: "Debate Prep Intel: Opponent's Strategy Leaked",
                summary: description,
                urgency: 4,
                turnReceived: currentTurn,
                deadline: currentTurn + 1,
                options: [
                    BriefingOption(
                        label: "Use the Information",
                        description: "Knowing their tactics, prepare specific counter-responses.",
                        pros: ["Better prepared", "Neutralizes their advantage"],
                        cons: ["If exposed, looks like dirty tricks", "Distracts from your own message"],
                        effects: ["momentum": 4.0, "approval": -2.0]
                    ),
                    BriefingOption(
                        label: "Stay Above It",
                        description: "Focus purely on your own debate prep. Don't acknowledge what you know.",
                        pros: ["Moral high ground", "Clean narrative"],
                        cons: ["Don't capitalize on the intel", "Opponent may still execute plan"],
                        effects: ["approval": 3.0, "mediaFavorability": 2.0]
                    ),
                    BriefingOption(
                        label: "File a Complaint",
                        description: "Formally protest the polling of supporters for gotcha questions.",
                        pros: ["Sets narrative of fairness", "Draws sympathy"],
                        cons: ["Looks defensive", "Takes focus off your ideas"],
                        effects: ["partyUnity": 3.0, "congressionalSupport": -4.0]
                    ),
                    BriefingOption(
                        label: "Go Public",
                        description: "Announce publicly that your opponent is preparing to use dirty debate tactics.",
                        pros: ["Preemptive narrative control", "Shifts spotlight to opponent's tactics"],
                        cons: ["Looks like sour grapes", "May not be believed without proof"],
                        effects: ["momentum": 5.0, "approval": -4.0]
                    )
                ]
            )

        case "Opposition Research":
            return Briefing(
                type: .campaign,
                title: "Opposition Research: damaging Information Found",
                summary: description,
                urgency: 3,
                turnReceived: currentTurn,
                deadline: deadline,
                options: [
                    BriefingOption(
                        label: "Release Immediately",
                        description: "Get it out now while it's fresh and maximum damage is done.",
                        pros: ["Maximum shock value", "Seizes narrative control"],
                        cons: ["Looks ruthless", "Sets precedent for counter-attacks"],
                        effects: ["momentum": 7.0, "approval": -3.0]
                    ),
                    BriefingOption(
                        label: "Hold for Maximum Impact",
                        description: "Save it for the most damaging moment — near election day.",
                        pros: ["Strategic timing", "Keeps powder dry"],
                        cons: ["May lose news cycle", "Risk of leak dilutes impact"],
                        effects: ["momentum": 3.0, "partyUnity": 3.0]
                    ),
                    BriefingOption(
                        label: "Verify and Caution",
                        description: "Have your team verify every detail before taking any action.",
                        pros: ["Journalistic integrity", "Avoids false narratives"],
                        cons: ["May miss the news window", "Rivals may get wind of your research"],
                        effects: ["approval": 4.0, "momentum": -2.0]
                    )
                ]
            )

        case "Scandal Investigation":
            return Briefing(
                type: .crisis,
                title: "Reporters Inquire About Your Past",
                summary: description,
                urgency: 5,
                turnReceived: currentTurn,
                deadline: currentTurn + 1,
                options: [
                    BriefingOption(
                        label: "Cooperate Fully and Transparency",
                        description: "Answer every question openly. Get ahead of the story with truth.",
                        pros: ["Establishes credibility", "Story dies faster with full cooperation"],
                        cons: ["Every detail becomes public", "Some facts may be taken out of context"],
                        effects: ["approval": 5.0, "mediaFavorability": 3.0]
                    ),
                    BriefingOption(
                        label: "Refuse to Comment",
                        description: "Decline to engage. Let your record speak for itself.",
                        pros: ["Minimizes exposure", "Avoids saying something that could be twisted"],
                        cons: ["Looks evasive", "Reporters fill the void with speculation"],
                        effects: ["approval": -5.0, "mediaFavorability": -5.0]
                    ),
                    BriefingOption(
                        label: "Hire Legal Counsel",
                        description: "Get a legal team involved before making any public statements.",
                        pros: ["Protects your interests", "Signals seriousness"],
                        cons: ["Expensive", "Signals something worth hiding"],
                        effects: ["congressionalSupport": 2.0, "approval": -2.0]
                    )
                ]
            )

        case "Leaked Memo":
            return Briefing(
                type: .crisis,
                title: "Internal Memo Leaked to Press",
                summary: description,
                urgency: 3,
                turnReceived: currentTurn,
                deadline: currentTurn + 2,
                options: [
                    BriefingOption(
                        label: "Distance from the Memo",
                        description: "Claim the memo was a draft that didn't reflect your views.",
                        pros: ["Quick damage control", "Clear separation"],
                        cons: ["Credibility hit if contradicted", "Staff morale suffers"],
                        effects: ["approval": 3.0, "partyUnity": -3.0]
                    ),
                    BriefingOption(
                        label: "Embrace the Content",
                        description: "Own it. Say these were internal deliberations and you stand by the process.",
                        pros: ["Shows authenticity", "Protects staff loyalty"],
                        cons: ["Defends possibly unpopular views", "Keeps story alive longer"],
                        effects: ["partyUnity": 5.0, "approval": -3.0]
                    ),
                    BriefingOption(
                        label: "Demand an Investigation",
                        description: "Call for an internal investigation to find the source of the leak.",
                        pros: ["Shifts narrative to the leaker", "Shows leadership"],
                        cons: ["Looks like covering tracks", "Investigation takes time"],
                        effects: ["partyUnity": 3.0, "mediaFavorability": -2.0]
                    )
                ]
            )

        case "Press Briefing Tensions":
            return Briefing(
                type: .media,
                title: "Press Room Confrontation Brewing",
                summary: description,
                urgency: 3,
                turnReceived: currentTurn,
                deadline: currentTurn + 1,
                options: [
                    BriefingOption(
                        label: "Cancel the Briefing",
                        description: "Pull the plug. Avoid the confrontation entirely.",
                        pros: ["No confrontation", "Staff can regroup"],
                        cons: ["Looks like you're hiding", "Press fills vacuum with speculation"],
                        effects: ["mediaFavorability": -5.0, "approval": -2.0]
                    ),
                    BriefingOption(
                        label: "Proceed — Control the Room",
                        description: "Have your press team firmly but professionally manage the event.",
                        pros: ["Shows confidence", "Opportunity to reset narrative"],
                        cons: ["Risk of confrontation", "Staff may get rattled"],
                        effects: ["mediaFavorability": 4.0, "approval": 2.0]
                    ),
                    BriefingOption(
                        label: "Reschedule with New Format",
                        description: "Offer a different format — smaller group, on-camera only, etc.",
                        pros: ["Avoids chaos", "Gives time to prepare"],
                        cons: ["Press may see it as avoidance", "New format has its own risks"],
                        effects: ["mediaFavorability": 1.0, "approval": 1.0]
                    )
                ]
            )

        case "Ethics Investigation":
            return Briefing(
                type: .crisis,
                title: "Congressional Ethics Inquiry Opened",
                summary: description,
                urgency: 5,
                turnReceived: currentTurn,
                deadline: currentTurn + 1,
                options: [
                    BriefingOption(
                        label: "Cooperate Fully",
                        description: "Open all records, make staff available. Get this over with quickly.",
                        pros: ["Good faith effort", "Reduces penalties if guilt is found"],
                        cons: ["Exposes everything", "Discovery process is painful"],
                        effects: ["approval": 4.0, "congressionalSupport": -3.0]
                    ),
                    BriefingOption(
                        label: "Fight It Politically",
                        description: "Paint the inquiry as partisan overreach. Rally public support.",
                        pros: ["Maintains base enthusiasm", "Makes investigation look political"],
                        cons: ["If guilt is found, looks obstructive", "Uses up political capital"],
                        effects: ["partyUnity": 5.0, "congressionalSupport": -5.0]
                    ),
                    BriefingOption(
                        label: "Hire High-Profile Counsel",
                        description: "Bring in a prestigious lawyer to manage the case.",
                        pros: ["Best legal defense", "Signals serious intent"],
                        cons: ["Very expensive", "Signals severity"],
                        effects: ["congressionalSupport": 2.0, "approval": -2.0]
                    )
                ]
            )

        case "Debt Ceiling Deadline":
            return Briefing(
                type: .crisis,
                title: "Debt Ceiling Deadline Approaching",
                summary: description,
                urgency: 5,
                turnReceived: currentTurn,
                deadline: currentTurn + 1,
                options: [
                    BriefingOption(
                        label: "Negotiate a Deal",
                        description: "Work with congressional leaders to find a compromise.",
                        pros: ["Avoids default", "Shows governing maturity"],
                        cons: ["Requires concessions", "Both sides may be unhappy"],
                        effects: ["approval": 3.0, "congressionalSupport": 4.0]
                    ),
                    BriefingOption(
                        label: "Pressure Your Party",
                        description: "Publicly pressure rank-and-file members to vote your way.",
                        pros: ["Shows strength", "Keeps base energized"],
                        cons: ["Risks default if it fails", "May damage relationships"],
                        effects: ["partyUnity": 4.0, "congressionalSupport": -4.0]
                    ),
                    BriefingOption(
                        label: "Consider the 14th Amendment",
                        description: "Explore using the constitutional option to bypass Congress.",
                        pros: ["Avoids default without Congress", "Tests constitutional limits"],
                        cons: ["Legal uncertainty", "Would be immediately challenged in court"],
                        effects: ["approval": 2.0, "globalInfluence": -3.0]
                    )
                ]
            )

        case "Government Shutdown Threat":
            return Briefing(
                type: .crisis,
                title: "Shutdown Looms Without Budget Deal",
                summary: description,
                urgency: 5,
                turnReceived: currentTurn,
                deadline: currentTurn + 1,
                options: [
                    BriefingOption(
                        label: "Accept a CR",
                        description: "Back a continuing resolution to keep government running temporarily.",
                        pros: ["Avoids shutdown", "Gives more negotiating time"],
                        cons: ["Not a real solution", "Looks like inability to govern"],
                        effects: ["approval": -2.0, "congressionalSupport": 3.0]
                    ),
                    BriefingOption(
                        label: "Push for Full Funding",
                        description: "Insist on a full-year appropriations bill with your priorities.",
                        pros: ["Your priorities funded", "Shows leadership"],
                        cons: ["High chance of shutdown", "Political blame game intensifies"],
                        effects: ["approval": 4.0, "congressionalSupport": -6.0]
                    ),
                    BriefingOption(
                        label: "Blame the Other Party",
                        description: "Go public with exactly who's blocking the budget.",
                        pros: ["Narrative control", "Rally your base"],
                        cons: ["Shutdown may still happen", "Looks partisan"],
                        effects: ["momentum": 4.0, "approval": -3.0]
                    )
                ]
            )

        case "Tariff Shock":
            return Briefing(
                type: .crisis,
                title: "New Tariffs Roil Markets",
                summary: description,
                urgency: 4,
                turnReceived: currentTurn,
                deadline: deadline,
                options: [
                    BriefingOption(
                        label: "Hold Firm",
                        description: "Stay the course. The short-term pain leads to long-term gain.",
                        pros: ["Shows resolve", "Negotiating leverage maintained"],
                        cons: ["Markets mayhem continues", "Political cost in affected states"],
                        effects: ["approval": -3.0, "globalInfluence": 5.0]
                    ),
                    BriefingOption(
                        label: "Signal Flexibility",
                        description: "Let it be known you're open to a deal if trading partners negotiate fairly.",
                        pros: ["Calms markets", "Keeps diplomatic door open"],
                        cons: ["Looks like retreat", "Weakens negotiating position"],
                        effects: ["approval": 3.0, "globalInfluence": -3.0]
                    ),
                    BriefingOption(
                        label: "Double Down",
                        description: "Announce additional tariffs to show you're serious.",
                        pros: ["Maximum pressure", "Keeps allies off-balance"],
                        cons: ["Market chaos intensifies", "Risk of retaliation"],
                        effects: ["approval": -5.0, "globalInfluence": 7.0]
                    )
                ]
            )

        case "Primary Challenge":
            return Briefing(
                type: .campaign,
                title: "Party Member Signals Primary Challenge",
                summary: description,
                urgency: 4,
                turnReceived: currentTurn,
                deadline: deadline,
                options: [
                    BriefingOption(
                        label: "Mobilize Party Leadership",
                        description: "Get party elders to publicly reaffirm their support for you.",
                        pros: ["Shows party unity", "Discourages the challenger"],
                        cons: ["May look desperate", "Some leaders may decline"],
                        effects: ["partyUnity": 5.0, "approval": -2.0]
                    ),
                    BriefingOption(
                        label: "Reach Out Privately",
                        description: "Call the potential challenger. Find common ground before it goes public.",
                        pros: ["May prevent challenge", "Shows maturity"],
                        cons: ["Looks like appeasement", "Challenge may still come"],
                        effects: ["partyUnity": 2.0, "approval": 2.0]
                    ),
                    BriefingOption(
                        label: "Ignore It",
                        description: "Let them announce if they dare. Stay focused on your agenda.",
                        pros: ["Shows strength", "Focus stays on your message"],
                        cons: ["Challenge may gain momentum", "Loses chance to shape narrative"],
                        effects: ["momentum": 3.0, "approval": -3.0]
                    )
                ]
            )

        case "Filibuster Threat":
            return Briefing(
                type: .legislative,
                title: "Opposition Vows to Filibuster",
                summary: description,
                urgency: 3,
                turnReceived: currentTurn,
                deadline: deadline,
                options: [
                    BriefingOption(
                        label: "Bipartisan Outreach",
                        description: "Reach out to moderates in the other party for a compromise.",
                        pros: ["May peel off votes", "Shows governing spirit"],
                        cons: ["Base may feel betrayed", "Requires significant concessions"],
                        effects: ["congressionalSupport": 5.0, "partyUnity": -4.0]
                    ),
                    BriefingOption(
                        label: "Pressure the Moderates",
                        description: "Publicly name which members are blocking progress.",
                        pros: ["Political pressure works", "Keeps base happy"],
                        cons: ["Damages relationships", "May harden opposition"],
                        effects: ["partyUnity": 4.0, "congressionalSupport": -4.0]
                    ),
                    BriefingOption(
                        label: "Go Nuclear",
                        description: "Change Senate rules to eliminate the filibuster for this issue.",
                        pros: ["Eliminates obstacle permanently", "Shows resolve"],
                        cons: ["Sets dangerous precedent", "Future Senates can do same"],
                        effects: ["partyUnity": 6.0, "congressionalSupport": -7.0]
                    )
                ]
            )

        case "Supreme Court Nominee":
            return Briefing(
                type: .legislative,
                title: "Supreme Court Vacancy — Nominate Now",
                summary: "A Supreme Court seat has opened up. You must nominate a candidate and get Senate confirmation.",
                urgency: 5,
                turnReceived: currentTurn,
                deadline: currentTurn + 5,
                options: [
                    BriefingOption(
                        label: "Nominate a Liberal",
                        description: "Choose a clearly progressive judge to satisfy your base.",
                        pros: ["Base enthusiastic", "Lasts decades of precedent"],
                        cons: ["Extreme opposition", "May not get confirmed"],
                        effects: ["approval": 5.0, "congressionalSupport": -6.0]
                    ),
                    BriefingOption(
                        label: "Nominate a Centrist",
                        description: "Pick someone acceptable to both sides to maximize confirmation chances.",
                        pros: ["Best chance of confirmation", "Shows bipartisanship"],
                        cons: ["Base feels betrayed", "Controversial either way"],
                        effects: ["approval": -2.0, "congressionalSupport": 5.0]
                    ),
                    BriefingOption(
                        label: "Nominate a Conservative",
                        description: "Make a bold conservative pick and dare them to reject it.",
                        pros: ["Conservative legacy", "Rally conservative voters"],
                        cons: ["Nearcertain Democratic opposition", "Polarizes confirmation"],
                        effects: ["approval": -4.0, "congressionalSupport": -5.0, "partyUnity": 4.0]
                    )
                ]
            )

        default:
            return nil
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

        // For high-stakes events, create a Briefing with options instead of a plain GameEvent
        if briefingEvents.contains(selected.0),
           let briefing = createBriefingForEvent(title: selected.0, description: selected.1, category: selected.2) {
            gameState.briefings.insert(briefing, at: 0)
            // Keep max 20 briefings
            if gameState.briefings.count > 20 {
                gameState.briefings.removeLast()
            }
        } else {
            // Regular thin event
            let event = GameEvent(
                title: selected.0,
                description: selected.1,
                category: selected.2,
                turnOccurred: gameState.world.currentTurn
            )
            gameState.activeEvents.append(event)
        }
    }

    private func availableEventsForPhase(_ phase: GamePhase) -> [(String, String, EventCategory)] {
        switch phase {
        case .preCampaign, .campaign:
            // Candidate-phase events: building momentum, name recognition, media
            return [
                ("Poll Shows Tight Race", "A new national poll shows a razor-thin margin in your direction.", .political),
                ("Fundraising Surge", "Grassroots donors respond enthusiastically to your campaign message.", .achievement),
                ("Opponent Gaffe", "Your rival stumbles on camera with controversial comments about veterans.", .political),
                ("Viral Moment", "A clip of you addressing a crowd goes viral online.", .achievement),
                ("Policy Platform Launch", "Your campaign releases its formal policy platform to widespread coverage.", .political),
                ("Media Interview", "A major network offers you prime-time interview slot.", .political),
                ("Debate Prep Crisis", "Your debate prep team discovers your opponent has been polling supporters for gotcha questions.", .political),
                ("Endorsement News", "A prominent governor endorses your campaign, boosting your credentials.", .achievement),
                ("Opponent Fundraising", "Your opponent reports record-breaking fundraising numbers.", .political),
                ("Ground Game Success", "Your field operation in early-voting states exceeds turnout projections.", .political)
            ]
        case .primaries:
            // Primary-specific events
            return [
                ("Surprise State Win", "You win an unexpected primary state, shocking political commentators.", .achievement),
                ("Opposition Research", "Your team uncovers damaging information about a rival.", .political),
                ("Delegate Fight", "A dispute erupts over delegate allocation rules in a contested state.", .political),
                ("Party Unity Question", "A prominent party figure publicly questions whether the base will turn out.", .political),
                ("Super Tuesday Momentum", "Strong primary wins on Super Tuesday reshape the race.", .achievement),
                ("Negative Ad Wave", "Rival campaigns flood airwaves with attack ads against you.", .political),
                ("Moderator Clash", "A debate moderator presses you hard on healthcare and immigration.", .political),
                ("Celebrity Endorsement", "A major celebrity publicly backs your campaign.", .achievement),
                ("Scandal Investigation", "Reporters begin asking about a rumor concerning your past business dealings.", .scandal),
                ("Ground Game Pays Off", "Your investments in field organization deliver superior turnout.", .achievement)
            ]
        case .convention:
            return [
                ("Delegates Rally", "Party delegates show unexpected unity heading into the convention.", .achievement),
                ("VP Selection Drama", "Media leaks create speculation around your potential running mate.", .political),
                ("Platform Negotiations", "Factions within your party battle over the final platform language.", .political),
                ("Convention Bounce", "Your convention speech generates overwhelmingly positive coverage.", .achievement),
                ("Floor Fight", "A credentials challenge threatens to split thedelegates.", .political),
                ("unity Message", "Party elders praise your unifying convention performance.", .achievement),
                ("DNC Planning", "Your team begins coordinating with the national party apparatus.", .political)
            ]
        case .generalElection:
            return [
                ("Debate Dominance", "Post-debate polls show you won the presidential debate.", .achievement),
                ("Opponent Scandal", "Your opponent faces new questions about their business dealings abroad.", .scandal),
                ("Electoral Map Shifts", "A historically red state shows surprising polling movement toward you.", .political),
                ("Foreign Policy Crisis", "An overseas crisis demands immediate attention from both campaigns.", .international),
                ("October Surprise", "A late-breaking story threatens to upend your campaign momentum.", .scandal),
                ("Field Operation Edge", "Your ground game proves superior in early-voting state contact rates.", .achievement),
                ("Swing State Rally", "A massive rally in a battleground state energizes your supporters.", .achievement),
                ("Electoral College Math", "Analysts debate whether the electoral map is shifting permanently.", .political),
                ("Get Out The Vote", "Your campaign's final GOTV push shows record-breaking early voting.", .achievement),
                ("Opponent Stumbles", "Your rival makes a high-profile mistake in the final stretch.", .political)
            ]
        case .transition:
            return [
                ("Cabinet Hunters", "Prospective cabinet members begin reaching out to your team.", .political),
                ("Agency Briefings", "Career civil servants offer informational briefings on agency operations.", .political),
                ("Security Clearances", "The transition team encounters delays in obtaining security clearances.", .political),
                ("Budget Review", "Your team discovers the outgoing administration's budget projections were optimistic.", .political),
                ("Transition Donorask", "Major donors await a call asking for transition funds.", .political),
                ("Press Transition", "The press pool begins following your every public move.", .political),
                ("Policy Handoff", "Outgoing officials offer cooperation on the transition of power.", .political)
            ]
        case .presidency, .lameDuck:
            // Governing-phase events: real-world crises and policy from 2024-2026
            return [
                // Economic
                ("Tariff Shock", "New tariff imposed on major trading partners send markets into volatility.", .economic),
                ("Inflation Spike", "Consumer prices rise faster than expected, squeezing household budgets.", .economic),
                ("Jobs Report Surprise", "The monthly jobs report comes in far below projections.", .economic),
                ("Stock Market Dip", "Wall Street experiences its worst week in months over policy uncertainty.", .economic),
                ("Supply Chain Alert", "A key shipping route faces disruption, threatening retail supply.", .economic),
                ("Debt Ceiling Deadline", "Congress must raise the debt ceiling or face default within weeks.", .political),
                ("Government Shutdown Threat", "A budget impasse threatens to shut down non-essential government services.", .political),
                ("Banking System Stress", "Regional banks report mounting stress from commercial real estate losses.", .economic),

                // International
                ("Ukraine Ceasefire Talks", "Diplomatic talks about Ukraine ceasefire terms reach a delicate stage.", .international),
                ("Middle East Tensions", "Escalating hostilities in the Middle East threaten regional stability.", .international),
                ("China Trade Talks", "Chinese officials request emergency trade negotiations amid tariff pressures.", .international),
                ("NATO Summit", "Allies await signals about continued US commitment to collective defense.", .international),
                ("Taiwan Strait Tensions", "Military activity near Taiwan prompts diplomatic concerns.", .international),
                ("EU Tariff Retaliation", "The European Union announces retaliatory tariffs on US goods.", .international),
                ("Iran Nuclear Talks", "Diplomats report progress — or breakdown — in nuclear negotiations with Iran.", .international),
                ("Sudan Humanitarian Crisis", "A massive humanitarian crisis in Sudan draws calls for US involvement.", .international),
                ("Latin America Migration Wave", "A new migration wave at the southern border strains resources.", .international),

                // Domestic Political
                ("SCOTUS Case", "The Supreme Court agrees to hear a case with major implications for your agenda.", .political),
                ("Primary Challenge", "A member of your own party signals a primary challenge to your agenda.", .political),
                ("Filibuster Threat", "The opposition threatens to filibuster a key piece of your legislation.", .political),
                ("Bipartisan Breakthrough", "A bipartisan group of senators reaches agreement on a surprise compromise.", .political),
                ("Party Moderates Push Back", "Moderate members of your party resist progressive elements of your agenda.", .political),
                ("Coalition Cracks", "Your governing coalition shows signs of fraying over spending priorities.", .political),

                // Social / Crisis
                ("AI Regulation Debate", "Congressional hearings on AI safety dominate the news cycle.", .social),
                ("Mass Shooting", "A mass shooting in a major city prompts renewed calls for gun legislation.", .social),
                ("Climate Disaster", "A severe climate-related disaster in a key state draws emergency response.", .social),
                ("Healthcare System Strain", "Hospitals in several states report being at capacity.", .social),
                ("Opioid Crisis Update", "Fentanyl seizures at the border reach record levels.", .social),
                ("Tech Layoffs", "Major tech companies announce significant layoffs, affecting thousands.", .economic),

                // Scandal / Media
                ("Leaked Memo", "A leaked internal memo reveals disagreement within your administration.", .scandal),
                ("Press Briefing Tensions", "A contentious press briefing creates negative headlines for days.", .scandal),
                ("Social Media Firestorm", "A viral post about your administration triggers an online backlash.", .scandal),
                ("Ethics Investigation", "The Office of Congressional Ethics opens an inquiry into an associate.", .scandal),

                // Achievements
                ("Legislative Win", "Your signature bill passes both chambers of Congress.", .achievement),
                ("Diplomatic Breakthrough", "A landmark diplomatic agreement is signed at the White House.", .achievement),
                ("Economic Rally", "A positive economic report boosts confidence in your policies.", .achievement),
                ("Poll Bounce", "Your approval rating rises following a successful public appearance.", .achievement)
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
        // Primary polling & delegate accumulation
        if gameState.phase == .campaign || gameState.phase == .primaries {
            var totalPlayerSupport = 30.0 + gameState.world.approvalRating / 10

            for opponent in gameState.primaryOpponents {
                totalPlayerSupport -= opponent.momentum * 2
            }

            totalPlayerSupport = max(15, min(60, totalPlayerSupport))

            // Award delegates based on polling performance
            // Simulate primary season awarding ~100-150 delegates per turn proportionally
            let remainingDelegates = max(0, gameState.totalDelegatesNeeded - gameState.primaryDelegates)
            if remainingDelegates > 0 {
                let baseDelegatesPerTurn: Double = 120 // Average primary week delegate allocation
                let proportionalShare: Double = totalPlayerSupport / 100.0
                let approvalBonus: Double = (gameState.world.approvalRating - 50) / 500.0 // ±10% based on approval
                let randomness: Double = Double.random(in: 0.8...1.2)

                var delegatesEarned: Double = baseDelegatesPerTurn * proportionalShare
                delegatesEarned *= (1.0 + approvalBonus)
                delegatesEarned *= randomness
                delegatesEarned = min(delegatesEarned, Double(remainingDelegates))
                delegatesEarned = max(1.0, delegatesEarned)

                gameState.primaryDelegates += Int(delegatesEarned)
            }
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
                gameState.world.actionResultsThisTurn.append("Your opponent has reached 270 electoral votes. You have lost the election.")
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

    private func possiblyGenerateDecision() {
        // Don't spam decisions — cap at 2 pending
        guard gameState.pendingDecisions.count < 2 else { return }
        // ~25% chance per turn to generate a new decision
        guard Double.random(in: 0...1) < 0.25 else { return }

        let templates: [Decision] = [
            Decision(
                prompt: "Media Interview Request",
                context: "A major network wants exclusive access. Your team is divided on how to handle it.",
                options: [
                    DecisionOption(text: "Accept the interview", isRisky: false, expectedBenefits: ["approvalRating": 2.0, "campaignMomentum": 0.5]),
                    DecisionOption(text: "Send a surrogate instead", isRisky: false, expectedBenefits: ["approvalRating": 0.5]),
                    DecisionOption(text: "Decline — avoid risk", isRisky: false, expectedBenefits: ["approvalRating": -1.0])
                ],
                turn: gameState.world.currentTurn,
                phase: gameState.phase
            ),
            Decision(
                prompt: "Fundraiser Opportunity",
                context: "A wealthy donor is hosting an exclusive fundraiser, but attendance requires aligning with their interests.",
                options: [
                    DecisionOption(text: "Attend and accept the donor's views", isRisky: true, riskProbability: 0.3, expectedBenefits: ["campaignMomentum": 2.0, "approvalRating": -2.0]),
                    DecisionOption(text: "Attend but keep your distance", isRisky: false, expectedBenefits: ["campaignMomentum": 1.0]),
                    DecisionOption(text: "Skip it — protect your brand", isRisky: false, expectedBenefits: ["approvalRating": 1.0, "partyUnity": 2.0])
                ],
                turn: gameState.world.currentTurn,
                phase: gameState.phase
            ),
            Decision(
                prompt: "Opposition Research Discovery",
                context: "Your team has uncovered damaging information about your opponent. How do you use it?",
                options: [
                    DecisionOption(text: "Go public immediately", isRisky: true, riskProbability: 0.5, expectedBenefits: ["campaignMomentum": 3.0, "approvalRating": -3.0]),
                    DecisionOption(text: "Use it as leverage quietly", isRisky: false, expectedBenefits: ["campaignMomentum": 1.5]),
                    DecisionOption(text: "Ignore it — run a positive campaign", isRisky: false, expectedBenefits: ["approvalRating": 2.0, "partyUnity": 1.0])
                ],
                turn: gameState.world.currentTurn,
                phase: gameState.phase
            ),
            Decision(
                prompt: "Campaign Rally Planning",
                context: "Your strategists propose a major rally in a key swing state.",
                options: [
                    DecisionOption(text: "Go big — large rally with media coverage", isRisky: true, riskProbability: 0.3, expectedBenefits: ["campaignMomentum": 3.0]),
                    DecisionOption(text: "Small targeted event — safer", isRisky: false, expectedBenefits: ["campaignMomentum": 1.0, "approvalRating": 1.0]),
                    DecisionOption(text: "Cancel — save resources", isRisky: false, expectedBenefits: ["partyUnity": 1.0])
                ],
                turn: gameState.world.currentTurn,
                phase: gameState.phase
            ),
            Decision(
                prompt: "Scandal Response Required",
                context: "A minor scandal has surfaced involving a senior staff member. The press is demanding comment.",
                options: [
                    DecisionOption(text: "Fire them immediately", isRisky: false, expectedBenefits: ["approvalRating": 2.0, "partyUnity": -2.0]),
                    DecisionOption(text: "Stand by them publicly", isRisky: true, riskProbability: 0.6, expectedBenefits: ["partyUnity": 3.0, "approvalRating": -4.0]),
                    DecisionOption(text: "No comment — wait it out", isRisky: true, riskProbability: 0.4, expectedBenefits: ["approvalRating": -1.0])
                ],
                turn: gameState.world.currentTurn,
                phase: gameState.phase,
                isUrgent: true,
                deadline: gameState.world.currentTurn + 2
            ),
            Decision(
                prompt: "Debate Prep Offer",
                context: "Your running mate suggests an intensive debate preparation session.",
                options: [
                    DecisionOption(text: "Full debate prep — 3 days", isRisky: false, expectedBenefits: ["campaignMomentum": 2.0]),
                    DecisionOption(text: "Light prep — trust your instincts", isRisky: false, expectedBenefits: ["campaignMomentum": 0.5, "approvalRating": 0.5]),
                    DecisionOption(text: "Skip prep — focus on retail politics", isRisky: true, riskProbability: 0.3, expectedBenefits: ["approvalRating": 1.0])
                ],
                turn: gameState.world.currentTurn,
                phase: gameState.phase
            )
        ]

        if let decision = templates.randomElement() {
            var mutableDecision = decision
            mutableDecision = Decision(
                id: UUID(),
                prompt: decision.prompt,
                context: decision.context,
                options: decision.options,
                turn: gameState.world.currentTurn,
                phase: gameState.phase,
                isUrgent: decision.isUrgent,
                deadline: decision.deadline
            )
            gameState.pendingDecisions.append(mutableDecision)
        }
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
            Task { @MainActor [weak self] in
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
