import Foundation
import AVFoundation

// MARK: - Diplomatic Conversation Engine
// Enables real conversations with world leaders through text/voice
// AI generates realistic responses and calculates consequences

struct DiplomaticExchange: Codable, Identifiable {
    let id: UUID
    let turn: Int
    let countryName: String
    let leaderName: String
    var playerStatement: String
    var leaderResponse: String
    var leaderEmotion: LeaderEmotion
    var relationshipDelta: Double
    var followUpSuggestions: [String]
    var emergingEvent: String?
    var timestamp: Date

    init(
        id: UUID = UUID(),
        turn: Int,
        countryName: String,
        leaderName: String,
        playerStatement: String,
        leaderResponse: String,
        leaderEmotion: LeaderEmotion = .neutral,
        relationshipDelta: Double = 0,
        followUpSuggestions: [String] = [],
        emergingEvent: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.turn = turn
        self.countryName = countryName
        self.leaderName = leaderName
        self.playerStatement = playerStatement
        self.leaderResponse = leaderResponse
        self.leaderEmotion = leaderEmotion
        self.relationshipDelta = relationshipDelta
        self.followUpSuggestions = followUpSuggestions
        self.emergingEvent = emergingEvent
        self.timestamp = timestamp
    }
}

enum LeaderEmotion: String, Codable {
    case friendly
    case neutral
    case cautious
    case skeptical
    case hostile
    case warm
    case dismissive
    case threatening
    case hopeful
    case desperate

    var speechRate: Float {
        switch self {
        case .friendly, .warm, .hopeful: return 0.52
        case .neutral, .cautious: return 0.5
        case .skeptical, .dismissive: return 0.48
        case .hostile, .threatening: return 0.45
        case .desperate: return 0.55
        }
    }

    var speechPitch: Float {
        switch self {
        case .friendly, .warm: return 1.1
        case .neutral, .cautious: return 1.0
        case .skeptical, .dismissive: return 0.95
        case .hostile: return 0.9
        case .threatening: return 0.85
        case .hopeful: return 1.15
        case .desperate: return 1.2
        }
    }
}

class DiplomacyConversationEngine: ObservableObject {
    @Published var currentConversation: DiplomaticExchange?
    @Published var conversationHistory: [DiplomaticExchange] = []
    @Published var isProcessing: Bool = false
    @Published var isSpeaking: Bool = false

    // MARK: - Main Entry Point

    func initiateConversation(
        with country: Country,
        playerStatement: String,
        relationship: Double,
        currentTurn: Int
    ) -> DiplomaticExchange {
        isProcessing = true
        defer { isProcessing = false }

        return generateResponse(
            country: country,
            statement: playerStatement,
            relationship: relationship,
            turn: currentTurn
        )
    }

    // MARK: - Response Generation

    private func generateResponse(
        country: Country,
        statement: String,
        relationship: Double,
        turn: Int
    ) -> DiplomaticExchange {
        let statementLower = statement.lowercased()

        // Analyze statement tone
        let isPositive = statementLower.contains("peace") || statementLower.contains("trade") ||
                         statementLower.contains("cooperat") || statementLower.contains("ally") ||
                         statementLower.contains("friend") || statementLower.contains("deal") ||
                         statementLower.contains("thank") || statementLower.contains("appreciate")

        let isThreatening = statementLower.contains("war") || statementLower.contains("sanction") ||
                            statementLower.contains("military") || statementLower.contains("force") ||
                            statementLower.contains("threat") || statementLower.contains(" ultimatum")

        let isDemanding = statementLower.contains("must") || statementLower.contains("demand") ||
                         statementLower.contains("require") || statementLower.contains("need to") ||
                         statementLower.contains("should") || statementLower.contains("expect")

        let isQuestion = statementLower.contains("?") || statementLower.contains("can you") ||
                        statementLower.contains("would you") || statementLower.contains("will you")

        let response: String
        let emotion: LeaderEmotion
        var delta: Double = 0

        // Generate response based on relationship and statement type
        if relationship >= 75 {
            // Close allies
            if isPositive {
                response = generateWarmResponse(country: country, statement: statement)
                emotion = .warm
                delta = 3
            } else if isThreatening {
                response = "We are deeply troubled to hear such words from our closest ally. This does not reflect the partnership we have built."
                emotion = .cautious
                delta = -8
            } else if isQuestion {
                response = generateOpenResponse(country: country)
                emotion = .friendly
                delta = 1
            } else {
                response = "We value our friendship deeply. Let us continue working together as we always have."
                emotion = .friendly
                delta = 1
            }
        } else if relationship >= 50 {
            // Allies
            if isPositive {
                response = generatePositiveResponse(country: country)
                emotion = .friendly
                delta = 4
            } else if isThreatening {
                response = "Such language is disappointing between friends. We hope this does not signal a change in our relationship."
                emotion = .skeptical
                delta = -6
            } else if isDemanding {
                response = "We understand your position. We will give it serious consideration, though we have our own perspectives to protect."
                emotion = .neutral
                delta = 0
            } else {
                response = "Thank you for this dialogue. We remain committed to our shared interests."
                emotion = .neutral
                delta = 1
            }
        } else if relationship >= 25 {
            // Friendly
            if isPositive {
                response = "We appreciate your constructive approach. There is much we can accomplish together."
                emotion = .friendly
                delta = 3
            } else if isThreatening {
                response = "Your threats are noted. However, they will not influence our sovereign decisions."
                emotion = .skeptical
                delta = -7
            } else if isDemanding {
                response = "Your demands are not unreasonable in principle, but the specifics require careful negotiation."
                emotion = .cautious
                delta = -1
            } else {
                response = "This is a productive conversation. We look forward to continued dialogue."
                emotion = .neutral
                delta = 1
            }
        } else if relationship >= 0 {
            // Neutral
            if isPositive {
                response = "We are open to exploring these ideas further. Let us see where mutual benefit lies."
                emotion = .cautious
                delta = 2
            } else if isThreatening {
                response = "Your aggressive posture does not create an environment for productive talks. Perhaps you should reconsider."
                emotion = .skeptical
                delta = -5
            } else if isDemanding {
                response = "We find your demands rather presumptuous given our current relationship. What are you prepared to offer in return?"
                emotion = .skeptical
                delta = -3
            } else {
                response = "We hear your position. Further discussions may be beneficial."
                emotion = .neutral
                delta = 0
            }
        } else if relationship >= -25 {
            // Strained
            if isPositive {
                response = "We note your attempt at diplomacy. Actions would speak louder than words."
                emotion = .cautious
                delta = 2
            } else if isThreatening {
                response = "Your threats carry no weight with us. We have faced far greater pressures."
                emotion = .hostile
                delta = -8
            } else if isDemanding {
                response = "You ask much while offering little. This is not how international relations should work."
                emotion = .dismissive
                delta = -4
            } else {
                response = "The situation between our nations is complicated. We remain open to better relations, but conditions must improve."
                emotion = .cautious
                delta = 0
            }
        } else if relationship >= -50 {
            // Adversarial
            if isPositive {
                response = "We are skeptical of sudden warmth. What has changed to prompt this?"
                emotion = .skeptical
                delta = 1
            } else if isThreatening {
                response = "You would be wise to consider the consequences of your threatening behavior. We are not easily intimidated."
                emotion = .hostile
                delta = -10
            } else if isDemanding {
                response = "Your demands are rejected outright. We will not be bullied by anyone."
                emotion = .hostile
                delta = -6
            } else {
                response = "Relations are difficult, but we maintain channels of communication. That is important."
                emotion = .neutral
                delta = 0
            }
        } else {
            // Hostile
            if isPositive {
                response = "We find your overtures hard to believe given the history between us. Prove it through actions."
                emotion = .skeptical
                delta = 3
            } else if isThreatening {
                response = "You push us toward a dangerous path. Remember that we too possess significant capabilities. Think carefully."
                emotion = .threatening
                delta = -12
            } else if isDemanding {
                response = "Your demands are laughable. We will never submit to such pressure. The era of American bullying is over."
                emotion = .threatening
                delta = -8
            } else {
                response = "The current state of affairs is your creation. We did not start this crisis, but we will end it on our terms."
                emotion = .hostile
                delta = -2
            }
        }

        let exchange = DiplomaticExchange(
            turn: turn,
            countryName: country.name,
            leaderName: country.leaderName,
            playerStatement: statement,
            leaderResponse: response,
            leaderEmotion: emotion,
            relationshipDelta: delta,
            followUpSuggestions: generateFollowUpSuggestions(statement: statement, country: country, emotion: emotion, relationship: relationship),
            emergingEvent: nil
        )

        conversationHistory.append(exchange)
        currentConversation = exchange

        return exchange
    }

    private func generateWarmResponse(country: Country, statement: String) -> String {
        let responses = [
            "Our alliance has never been stronger. Your words reflect the deep bonds between our peoples.",
            "Thank you for your kind words. The friendship between \(country.name) and America is a cornerstone of global stability.",
            "We greatly value this partnership. Together, we have achieved remarkable things, and I am confident we will continue to do so."
        ]
        return responses.randomElement() ?? responses[0]
    }

    private func generatePositiveResponse(country: Country) -> String {
        let responses = [
            "We appreciate your constructive approach. There is much we can accomplish together.",
            "This is exactly the kind of dialogue we need. Let us explore ways to strengthen our cooperation.",
            "Your willingness to work together is noted. We are open to new initiatives."
        ]
        return responses.randomElement() ?? responses[0]
    }

    private func generateOpenResponse(country: Country) -> String {
        let responses = [
            "That is an interesting question. Let me share our perspective on this matter...",
            "We are open to discussing this further. What specific aspects would you like to explore?",
            "An important question. We believe dialogue is the path forward."
        ]
        return responses.randomElement() ?? responses[0]
    }

    // MARK: - Follow-up Suggestions

    private func generateFollowUpSuggestions(statement: String, country: Country, emotion: LeaderEmotion, relationship: Double) -> [String] {
        var suggestions: [String] = []

        let statementLower = statement.lowercased()

        // Based on what player said, suggest continuations
        if statementLower.contains("trade") {
            suggestions.append("Propose specific trade terms")
            suggestions.append("Offer economic cooperation")
        }

        if statementLower.contains("military") || statementLower.contains("security") || statementLower.contains("defense") {
            suggestions.append("Discuss joint defense arrangements")
            suggestions.append("Propose military cooperation")
        }

        if statementLower.contains("sanction") {
            suggestions.append("Offer to lift sanctions in exchange for concessions")
            suggestions.append("Threaten additional sanctions")
        }

        if statementLower.contains("nuclear") {
            suggestions.append("Discuss nuclear non-proliferation")
            suggestions.append("Propose arms control talks")
        }

        if statementLower.contains("climate") || statementLower.contains("environment") {
            suggestions.append("Propose joint environmental initiatives")
            suggestions.append("Discuss carbon emission agreements")
        }

        if emotion == .hostile || emotion == .threatening {
            suggestions.append("De-escalate the conversation")
            suggestions.append("Find common ground")
            suggestions.append("Offer a gesture of goodwill")
        }

        if emotion == .skeptical || emotion == .cautious {
            suggestions.append("Provide concrete examples")
            suggestions.append("Suggest confidence-building measures")
        }

        if emotion == .warm || emotion == .friendly {
            suggestions.append("Propose a formal agreement")
            suggestions.append("Invite them to visit")
            suggestions.append("Discuss future cooperation")
        }

        // Always add some country-specific options
        switch country.name {
        case "China":
            suggestions.append("Discuss Taiwan situation")
            suggestions.append("Address trade imbalances")
            suggestions.append("Talk about South China Sea")
        case "Russia":
            suggestions.append("Talk about Ukraine")
            suggestions.append("Discuss arms control")
            suggestions.append("Address NATO expansion")
        case "Iran":
            suggestions.append("Address nuclear program")
            suggestions.append("Discuss regional security")
            suggestions.append("Talk about sanctions relief")
        case "North Korea":
            suggestions.append("Discuss denuclearization")
            suggestions.append("Address human rights concerns")
            suggestions.append("Propose humanitarian aid")
        case "Mexico":
            suggestions.append("Talk about border security")
            suggestions.append("Discuss immigration reform")
            suggestions.append("Address drug trafficking")
        default:
            suggestions.append("Propose diplomatic initiative")
            suggestions.append("Discuss bilateral agreements")
        }

        return Array(suggestions.prefix(4))
    }

    // MARK: - Text to Speech

    func speakResponse(_ exchange: DiplomaticExchange) {
        isSpeaking = true

        SpeechService.shared.speak(
            exchange.leaderResponse,
            rate: exchange.leaderEmotion.speechRate,
            voice: voiceForCountry(exchange.countryName)
        )

        // Assume speaking lasts roughly as long as the text
        let wordCount = exchange.leaderResponse.split(separator: " ").count
        let secondsToSpeak = Double(wordCount) / 2.5 // average speaking rate

        DispatchQueue.main.asyncAfter(deadline: .now() + secondsToSpeak) { [weak self] in
            self?.isSpeaking = false
        }
    }

    func stopSpeaking() {
        SpeechService.shared.stop()
        isSpeaking = false
    }

    private func voiceForCountry(_ countryName: String) -> AVSpeechSynthesisVoice? {
        let languageCode: String
        switch countryName {
        case "France": languageCode = "fr-FR"
        case "Germany": languageCode = "de-DE"
        case "Japan": languageCode = "ja-JP"
        case "China": languageCode = "zh-CN"
        case "Russia": languageCode = "ru-RU"
        case "Spain", "Mexico": languageCode = "es-ES"
        case "Italy": languageCode = "it-IT"
        case "Brazil": languageCode = "pt-BR"
        case "India": languageCode = "hi-IN"
        case "South Korea": languageCode = "ko-KR"
        default: languageCode = "en-US"
        }
        return AVSpeechSynthesisVoice(language: languageCode)
    }

    // MARK: - Conversation Management

    func clearHistory() {
        conversationHistory.removeAll()
        currentConversation = nil
    }

    func getRecentHistory(for country: String, limit: Int = 5) -> [DiplomaticExchange] {
        conversationHistory
            .filter { $0.countryName == country }
            .suffix(limit)
            .map { $0 }
    }
}
