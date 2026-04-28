import Foundation

// MARK: - MiniMax AI Service
// This is the AI BRAIN - NOT a chatbot interface
// All AI calls return structured data, not conversational text

actor MiniMaxService {
    private let apiKey: String
    private let baseURL = "https://api.minimax.io/anthropic/v1"
    private let model = "MiniMax-M2.7"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Consequence Calculation
    // Core use: Player does X → What happens?

    struct ConsequenceInput: Codable {
        let gameState: AIGameStateSummary
        let playerAction: String
        let context: String
    }

    struct ConsequenceOutput: Codable {
        let immediateEffects: [String: Double]
        let cascadingEffects: [EffectChain]
        let triggeredEvents: [AIGeneratedEvent]
        let narrative: String
        let hiddenFactors: [String]
    }

    struct EffectChain: Codable {
        let domain: String
        let effect: Double
        let explanation: String
    }

    struct AIGeneratedEvent: Codable {
        let title: String
        let description: String
        let category: String
        let severity: Double
    }

    struct AIGameStateSummary: Codable {
        let phase: String
        let turn: Int
        let approvalRating: Double
        let economyGDPGrowth: Double
        let economyUnemployment: Double
        let economyInflation: Double
        let partyUnity: Double
        let congressionalSupport: Double
        let globalInfluence: Double
        let topIssues: [String]
        let recentEvents: [String]
        let playerPolicyStances: [String: String]
    }

    func calculateConsequences(input: ConsequenceInput) async throws -> ConsequenceOutput {
        let prompt = buildConsequencePrompt(input: input)
        let response = try await callAI(prompt: prompt)

        // Parse the AI response into structured output
        // In production, we'd use JSON mode for reliable parsing
        return parseConsequenceResponse(response, originalInput: input)
    }

    private func buildConsequencePrompt(input: ConsequenceInput) -> String {
        """
        You are the simulation engine for a presidential strategy game. When the player takes an action, you calculate the realistic consequences.

        CURRENT GAME STATE:
        - Phase: \(input.gameState.phase)
        - Turn: \(input.gameState.turn)
        - Approval Rating: \(String(format: "%.1f", input.gameState.approvalRating))%
        - GDP Growth: \(String(format: "%.1f", input.gameState.economyGDPGrowth))%
        - Unemployment: \(String(format: "%.1f", input.gameState.economyUnemployment))%
        - Inflation: \(String(format: "%.1f", input.gameState.economyInflation))%
        - Party Unity: \(String(format: "%.1f", input.gameState.partyUnity))%
        - Congressional Support: \(String(format: "%.1f", input.gameState.congressionalSupport))%
        - Global Influence: \(String(format: "%.1f", input.gameState.globalInfluence))%

        TOP ISSUES: \(input.gameState.topIssues.joined(separator: ", "))
        RECENT EVENTS: \(input.gameState.recentEvents.joined(separator: "; "))

        PLAYER POLICY STANCES:
        \(input.gameState.playerPolicyStances.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))

        PLAYER ACTION: \(input.playerAction)
        CONTEXT: \(input.context)

        Calculate the consequences of this action. Consider:
        1. Immediate first-order effects (what directly changes)
        2. Cascading second-order effects (ripple through economy, politics, international relations)
        3. Potential events that might be triggered
        4. Hidden factors the player doesn't see

        Return your analysis in this exact JSON format (no markdown, pure JSON):
        {
          "immediateEffects": {"effectName": deltaValue, ...},
          "cascadingEffects": [{"domain": "string", "effect": deltaValue, "explanation": "string"}, ...],
          "triggeredEvents": [{"title": "string", "description": "string", "category": "string", "severity": 0.0-1.0}, ...],
          "narrative": "2-3 sentence narrative description of what happens",
          "hiddenFactors": ["factor1", "factor2", ...]
        }

        Be realistic and historically grounded. This is a non-deterministic simulation.
        """
    }

    // MARK: - Event Generation
    // When random chance + state suggest crisis, AI generates realistic event

    struct EventGenerationInput: Codable {
        let gameState: AIGameStateSummary
        let possibleCategories: [String]
        let randomnessFactor: Double // 0.0 to 1.0, how much randomness to inject
    }

    struct EventGenerationOutput: Codable {
        let generatedEvent: AIGeneratedEvent?
        let noEventProbability: Double
        let narrativeReason: String
    }

    func generateEvent(input: EventGenerationInput) async throws -> EventGenerationOutput {
        let prompt = buildEventGenerationPrompt(input: input)
        let response = try await callAI(prompt: prompt)
        return parseEventGenerationResponse(response)
    }

    private func buildEventGenerationPrompt(input: EventGenerationInput) -> String {
        """
        You are the event generator for a presidential simulation game. Based on the current game state and randomness, determine if a significant event occurs.

        CURRENT STATE:
        - Phase: \(input.gameState.phase)
        - Turn: \(input.gameState.turn)
        - Approval: \(String(format: "%.1f", input.gameState.approvalRating))%
        - Economy: GDP \(String(format: "%.1f", input.gameState.economyGDPGrowth))%, Jobs \(String(format: "%.1f", input.gameState.economyUnemployment))%, Inflation \(String(format: "%.1f", input.gameState.economyInflation))%
        - Party Unity: \(String(format: "%.1f", input.gameState.partyUnity))%
        - Congressional Support: \(String(format: "%.1f", input.gameState.congressionalSupport))%

        POSSIBLE EVENT CATEGORIES: \(input.possibleCategories.joined(separator: ", "))
        RANDOMNESS FACTOR: \(input.randomnessFactor) (higher = more chaos)

        If an event occurs, generate a realistic, historically-grounded event that fits the current state.
        Return JSON:
        {
          "generatedEvent": {"title": "string", "description": "string", "category": "string", "severity": 0.0-1.0} or null if no event,
          "noEventProbability": 0.0-1.0,
          "narrativeReason": "why an event did or didn't occur"
        }
        """
    }

    // MARK: - NPC Behavior Modeling
    // How would Congress, donors, foreign leaders react?

    struct NPCBehaviorInput: Codable {
        let npcType: String // "congress", "donor", "foreign_leader", "media"
        let npcSpecifics: String
        let gameState: AIGameStateSummary
        let playerAction: String
    }

    struct NPCBehaviorOutput: Codable {
        let reaction: String
        let moodChange: Double // positive = happier with player
        let likelyActions: [String]
        let narrative: String
    }

    func modelNPCBehavior(input: NPCBehaviorInput) async throws -> NPCBehaviorOutput {
        let prompt = buildNPCPrompt(input: input)
        let response = try await callAI(prompt: prompt)
        return parseNPCResponse(response)
    }

    private func buildNPCPrompt(input: NPCBehaviorInput) -> String {
        """
        Model how an NPC in a presidential simulation would react to player action.

        NPC TYPE: \(input.npcType)
        NPC DETAILS: \(input.npcSpecifics)

        PLAYER ACTION: \(input.playerAction)

        CURRENT STATE:
        - Approval: \(String(format: "%.1f", input.gameState.approvalRating))%
        - Party Unity: \(String(format: "%.1f", input.gameState.partyUnity))%
        - Congressional Support: \(String(format: "%.1f", input.gameState.congressionalSupport))%

        Return JSON:
        {
          "reaction": "brief description of reaction",
          "moodChange": -10.0 to +10.0,
          "likelyActions": ["action1", "action2"],
          "narrative": "2 sentence narrative"
        }
        """
    }

    // MARK: - Speech Generation
    // Generate draft speeches for player to deliver

    struct SpeechInput: Codable {
        let speechType: String // "campaign", "inaugural", "state_of_union", "crisis", "press_conference"
        let gameState: AIGameStateSummary
        let topic: String
        let tone: String // "soaring", "solemn", "urgent", "reassuring"
    }

    struct SpeechOutput: Codable {
        let draftSpeech: String
        let keyPhrases: [String]
        let estimatedImpact: String
    }

    func generateSpeech(input: SpeechInput) async throws -> SpeechOutput {
        let prompt = buildSpeechPrompt(input: input)
        let response = try await callAI(prompt: prompt)
        return parseSpeechResponse(response)
    }

    private func buildSpeechPrompt(input: SpeechInput) -> String {
        """
        Write a draft political speech for a presidential simulation game.

        SPEECH TYPE: \(input.speechType)
        TOPIC: \(input.topic)
        TONE: \(input.tone)

        GAME STATE:
        - Approval: \(String(format: "%.1f", input.gameState.approvalRating))%
        - Economy: GDP \(String(format: "%.1f", input.gameState.economyGDPGrowth))%, Inflation \(String(format: "%.1f", input.gameState.economyInflation))%
        - Top Issues: \(input.gameState.topIssues.joined(separator: ", "))

        Return JSON:
        {
          "draftSpeech": "full speech text (300-500 words for major speeches)",
          "keyPhrases": ["memorable phrase 1", "memorable phrase 2"],
          "estimatedImpact": "brief description of expected reception"
        }
        """
    }

    // MARK: - Core AI Call

    private func callAI(prompt: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw MiniMaxError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MiniMaxError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw MiniMaxError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = responseJSON?["content"] as? [[String: Any]]
        let text = content?.first?["text"] as? String

        guard let result = text else {
            throw MiniMaxError.parseError
        }

        return result
    }

    // MARK: - Response Parsers
    // These parse AI text responses into structured data

    private func parseConsequenceResponse(_ response: String, originalInput: ConsequenceInput) -> ConsequenceOutput {
        // Try to extract JSON from response
        if let jsonRange = response.range(of: "{", options: .regularExpression),
           let endRange = response.range(of: "}", options: .regularExpression) {
            let jsonString = String(response[jsonRange.lowerBound...endRange.upperBound])
            if let data = jsonString.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(ConsequenceOutput.self, from: data) {
                return decoded
            }
        }

        // Fallback: return a simple parsed version
        return ConsequenceOutput(
            immediateEffects: ["approvalRating": 0.0],
            cascadingEffects: [],
            triggeredEvents: [],
            narrative: response.prefix(200).description,
            hiddenFactors: []
        )
    }

    private func parseEventGenerationResponse(_ response: String) -> EventGenerationOutput {
        if let jsonRange = response.range(of: "{", options: .regularExpression),
           let endRange = response.range(of: "}", options: .regularExpression) {
            let jsonString = String(response[jsonRange.lowerBound...endRange.upperBound])
            if let data = jsonString.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(EventGenerationOutput.self, from: data) {
                return decoded
            }
        }

        return EventGenerationOutput(generatedEvent: nil, noEventProbability: 0.7, narrativeReason: "No significant events occurred.")
    }

    private func parseNPCResponse(_ response: String) -> NPCBehaviorOutput {
        if let jsonRange = response.range(of: "{", options: .regularExpression),
           let endRange = response.range(of: "}", options: .regularExpression) {
            let jsonString = String(response[jsonRange.lowerBound...endRange.upperBound])
            if let data = jsonString.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(NPCBehaviorOutput.self, from: data) {
                return decoded
            }
        }

        return NPCBehaviorOutput(reaction: "No change", moodChange: 0, likelyActions: [], narrative: response.prefix(100).description)
    }

    private func parseSpeechResponse(_ response: String) -> SpeechOutput {
        SpeechOutput(
            draftSpeech: response,
            keyPhrases: [],
            estimatedImpact: "Moderate positive impact expected."
        )
    }
}

enum MiniMaxError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case parseError

    var localizedDescription: String {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .invalidResponse: return "Invalid response from API"
        case .httpError(let code, _): return "HTTP error: \(code)"
        case .parseError: return "Failed to parse AI response"
        }
    }
}
