import Foundation

// MARK: - Debate Engine
// Handles debate simulation with AI-generated questions and responses

struct Debate: Codable, Identifiable {
    let id: UUID
    let date: Int // turn
    let type: DebateType
    var questions: [DebateQuestion]
    var isCompleted: Bool
    var viewerCount: Int
    var postDebatePolls: Double // swing in polls after debate

    init(
        id: UUID = UUID(),
        date: Int,
        type: DebateType,
        questions: [DebateQuestion] = [],
        isCompleted: Bool = false,
        viewerCount: Int = 0,
        postDebatePolls: Double = 0
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.questions = questions
        self.isCompleted = isCompleted
        self.viewerCount = viewerCount
        self.postDebatePolls = postDebatePolls
    }
}

enum DebateType: String, Codable, CaseIterable {
    case primary = "Primary Debate"
    case general = "General Election Debate"
    case vp = "Vice Presidential Debate"

    var description: String { rawValue }

    var typicalTopics: [String] {
        switch self {
        case .primary:
            return ["Healthcare", "Economy", "Immigration", "Party Unity", "Electability"]
        case .general:
            return ["Foreign Policy", "Economy", "Healthcare", "National Security", "Immigration"]
        case .vp:
            return ["Domestic Policy", "Economy", "Social Issues", "Readiness to Serve"]
        }
    }
}

struct DebateQuestion: Codable, Identifiable {
    let id: UUID
    let topic: String
    let questionText: String
    let moderator: String
    var playerResponse: String?
    var opponentResponse: String?
    var perceivedWinner: DebateWinner?
    var audienceImpact: Double // -5 to +5 poll points

    init(
        id: UUID = UUID(),
        topic: String,
        questionText: String,
        moderator: String = "Moderator",
        playerResponse: String? = nil,
        opponentResponse: String? = nil,
        perceivedWinner: DebateWinner? = nil,
        audienceImpact: Double = 0
    ) {
        self.id = id
        self.topic = topic
        self.questionText = questionText
        self.moderator = moderator
        self.playerResponse = playerResponse
        self.opponentResponse = opponentResponse
        self.perceivedWinner = perceivedWinner
        self.audienceImpact = audienceImpact
    }
}

enum DebateWinner: String, Codable {
    case player = "Player"
    case opponent = "Opponent"
    case tie = "Tie"
}

struct DebatePerformance: Codable {
    let debate: Debate
    let overallWinner: DebateWinner
    let momentumSwing: Double
    let memorableMoment: String
    let audienceReaction: String
    let fundraisingBump: Double
}

class DebateEngine {
    private let aiBrain: MiniMaxService?
    private let useAI: Bool

    init(aiBrain: MiniMaxService? = nil, useAI: Bool = true) {
        self.aiBrain = aiBrain
        self.useAI = useAI && (aiBrain != nil)
    }

    func generateDebate(type: DebateType, turn: Int) async -> Debate {
        var debate = Debate(date: turn, type: type)

        // Generate questions
        let topics = type.typicalTopics.shuffled().prefix(5)

        for topic in topics {
            let question = DebateQuestion(
                topic: topic,
                questionText: generateQuestionText(topic: topic),
                moderator: pickModerator()
            )
            debate.questions.append(question)
        }

        debate.viewerCount = estimateViewerCount(type: type)

        return debate
    }

    func conductDebate(
        debate: Debate,
        playerAnswers: [UUID: String],
        playerCharisma: Double,
        playerIntelligence: Double,
        opponentStrength: Double
    ) async -> DebatePerformance {
        var updatedDebate = debate
        var totalSwing: Double = 0
        var playerWins = 0
        var opponentWins = 0

        for i in 0..<updatedDebate.questions.count {
            let questionId = updatedDebate.questions[i].id
            if let playerAnswer = playerAnswers[questionId] {
                updatedDebate.questions[i].playerResponse = playerAnswer

                // Simulate opponent response
                updatedDebate.questions[i].opponentResponse = generateOpponentResponse(
                    topic: updatedDebate.questions[i].topic
                )

                // Determine winner based on player stats vs opponent
                let roll = Double.random(in: 0...1)
                let playerStrength = (playerCharisma + playerIntelligence) / 2
                let threshold = opponentStrength / (playerStrength + opponentStrength)

                if roll < threshold * 0.7 {
                    // Player wins
                    updatedDebate.questions[i].perceivedWinner = .player
                    updatedDebate.questions[i].audienceImpact = Double.random(in: 1...3)
                    playerWins += 1
                } else if roll < threshold {
                    // Tie
                    updatedDebate.questions[i].perceivedWinner = .tie
                    updatedDebate.questions[i].audienceImpact = Double.random(in: -0.5...0.5)
                } else {
                    // Opponent wins
                    updatedDebate.questions[i].perceivedWinner = .opponent
                    updatedDebate.questions[i].audienceImpact = Double.random(in: -3...(-1))
                    opponentWins += 1
                }

                totalSwing += updatedDebate.questions[i].audienceImpact
            }
        }

        updatedDebate.isCompleted = true
        updatedDebate.postDebatePolls = totalSwing

        // Determine overall winner
        let overallWinner: DebateWinner
        if playerWins > opponentWins {
            overallWinner = .player
        } else if opponentWins > playerWins {
            overallWinner = .opponent
        } else {
            overallWinner = .tie
        }

        return DebatePerformance(
            debate: updatedDebate,
            overallWinner: overallWinner,
            momentumSwing: totalSwing,
            memorableMoment: generateMemorableMoment(winner: overallWinner, debateType: debate.type),
            audienceReaction: generateAudienceReaction(winner: overallWinner, swing: totalSwing),
            fundraisingBump: calculateFundraisingBump(winner: overallWinner, viewerCount: debate.viewerCount)
        )
    }

    // MARK: - Private Helpers

    private func generateQuestionText(topic: String) -> String {
        let questions: [String: [String]] = [
            "Healthcare": [
                "How would you address the healthcare crisis facing millions of Americans?",
                "What is your plan for reducing healthcare costs while maintaining quality?",
                "Do you support universal healthcare or a market-based approach?"
            ],
            "Economy": [
                "What is your plan to address inflation and economic uncertainty?",
                "How would you create jobs and grow the economy?",
                "What role should government play in regulating business?"
            ],
            "Immigration": [
                "What is your comprehensive immigration reform plan?",
                "How would you handle the situation at the southern border?",
                "What should we do about DACA recipients?"
            ],
            "Foreign Policy": [
                "How would you handle our relationship with China?",
                "What is your stance on NATO and our alliances?",
                "When should America use military force abroad?"
            ],
            "National Security": [
                "How would you keep America safe from terrorism?",
                "What investments would you make in national defense?",
                "How do you balance security with civil liberties?"
            ],
            "Party Unity": [
                "How would you bring the party together after a contentious primary?",
                "What would you do to unify your party's factions?",
                "How do you plan to work with opponents across the aisle?"
            ],
            "Electability": [
                "Why do you believe you are the best candidate to win in November?",
                "How would you appeal to moderate voters?",
                "What makes you different from your primary opponents?"
            ]
        ]

        return questions[topic]?.randomElement() ?? "What is your position on \(topic)?"
    }

    private func pickModerator() -> String {
        let moderators = [
            "Leslie Stahl", "Tim Pfeiffer", "Norah O'Donnell",
            "Kristen Welker", "Jake Tapper", "Dana Bash"
        ]
        return moderators.randomElement() ?? "Moderator"
    }

    private func estimateViewerCount(type: DebateType) -> Int {
        switch type {
        case .primary: return Int.random(in: 10_000_000...20_000_000)
        case .general: return Int.random(in: 60_000_000...80_000_000)
        case .vp: return Int.random(in: 40_000_000...55_000_000)
        }
    }

    private func generateOpponentResponse(topic: String) -> String {
        // Simplified opponent response generation
        let responses = [
            "That's an important issue. My opponent has a different view, but I believe we need to take a common-sense approach that works for hard-working Americans.",
            "Let me be clear about where I stand. Unlike my opponent, I have a concrete plan that will actually deliver results for the American people.",
            "This is exactly the kind of question that shows the contrast in this race. My opponent talks a good game, but their record tells a different story."
        ]
        return responses.randomElement() ?? "I appreciate the question."
    }

    private func generateMemorableMoment(winner: DebateWinner, debateType: DebateType) -> String {
        if winner == .player {
            let moments = [
                "delivered a powerful line that had the crowd on their feet",
                "landed a decisive blow on their opponent's weakest point",
                "showed remarkable composure under hostile questioning"
            ]
            return "You " + moments.randomElement()!
        } else if winner == .opponent {
            let moments = [
                "struggled to defend your position on key issues",
                "appeared rattled by aggressive questioning",
                "failed to land any decisive blows"
            ]
            return "You " + moments.randomElement()!
        } else {
            return "Neither candidate dominated the debate"
        }
    }

    private func generateAudienceReaction(winner: DebateWinner, swing: Double) -> String {
        if swing > 2 {
            return "Enthusiastic - your performance has energized supporters"
        } else if swing > 0 {
            return "Positive - you gained ground in the post-debate polls"
        } else if swing == 0 {
            return "Neutral - the debate was considered a draw"
        } else if swing > -2 {
            return "Mixed - some concerns about your performance"
        } else {
            return "Disappointed - your supporters are worried"
        }
    }

    private func calculateFundraisingBump(winner: DebateWinner, viewerCount: Int) -> Double {
        let baseBump: Double
        switch winner {
        case .player: baseBump = 5_000_000
        case .opponent: baseBump = 3_000_000
        case .tie: baseBump = 1_000_000
        }

        let viewershipFactor = Double(viewerCount) / 50_000_000

        return winner == .player ? baseBump * viewershipFactor : -baseBump * viewershipFactor * 0.5
    }
}
