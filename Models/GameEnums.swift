import Foundation

// MARK: - Game Phase
enum GamePhase: String, CaseIterable, Codable {
    case preCampaign = "Pre-Campaign"
    case campaign = "Campaign"
    case primaries = "Primaries"
    case convention = "Convention"
    case generalElection = "General Election"
    case transition = "Transition"
    case presidency = "Presidency"
    case lameDuck = "Lame Duck"
    case exited = "Exited"

    var description: String { rawValue }

    var nextPhase: GamePhase? {
        switch self {
        case .preCampaign: return .campaign
        case .campaign: return .primaries
        case .primaries: return .convention
        case .convention: return .generalElection
        case .generalElection: return .transition
        case .transition: return .presidency
        case .presidency: return .lameDuck
        case .lameDuck: return .exited
        case .exited: return nil
        }
    }
}

// MARK: - Player Party
enum PoliticalParty: String, CaseIterable, Codable {
    case democrat = "Democratic"
    case republican = "Republican"
    case independent = "Independent"

    var abbreviation: String {
        switch self {
        case .democrat: return "D"
        case .republican: return "R"
        case .independent: return "I"
        }
    }

    var color: String {
        switch self {
        case .democrat: return "blue"
        case .republican: return "red"
        case .independent: return "purple"
        }
    }
}

// MARK: - Policy Position
enum PolicyArea: String, CaseIterable, Codable {
    case economy = "Economy"
    case healthcare = "Healthcare"
    case immigration = "Immigration"
    case foreignPolicy = "Foreign Policy"
    case environment = "Environment"
    case education = "Education"
    case criminalJustice = "Criminal Justice"
    case taxes = "Taxes"
    case defense = "Defense"
    case social = "Social Issues"
}

// MARK: - Policy Stance
enum PolicyStance: String, Codable {
    case farLeft = "Far Left"
    case left = "Left"
    case centerLeft = "Center-Left"
    case moderate = "Moderate"
    case centerRight = "Center-Right"
    case right = "Right"
    case farRight = "Far Right"

    var value: Double {
        switch self {
        case .farLeft: return -3.0
        case .left: return -2.0
        case .centerLeft: return -1.0
        case .moderate: return 0.0
        case .centerRight: return 1.0
        case .right: return 2.0
        case .farRight: return 3.0
        }
    }
}

// MARK: - Exit Type
enum ExitType: String, Codable {
    case lostElection = "Lost Re-election"
    case termLimited = "Term Limited"
    case resigned = "Resigned"
    case died = "Died in Office"
    case impeached = "Impeached"
    case naturalCauses = "Natural Causes (Retired)"

    var description: String { rawValue }
}

// MARK: - Decision Outcome
enum DecisionOutcome: Codable {
    case success(probability: Double)
    case mixed(probability: Double)
    case failure(probability: Double)

    var rollNeeded: Double {
        switch self {
        case .success(let prob): return prob
        case .mixed(let prob): return prob
        case .failure(let prob): return prob
        }
    }
}

// MARK: - News Cycle
enum NewsCyclePhase: String, Codable {
    case rising = "Rising"
    case peak = "Peak"
    case falling = "Falling"
    case dormant = "Dormant"
}
