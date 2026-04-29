import Foundation

// MARK: - International Relations Engine
// Handles global politics, diplomacy, and international events

struct Country: Codable, Identifiable {
    let id: UUID
    let name: String
    let leaderName: String
    var relationship: Double // -100 to +100
    var tradeBalance: Double // in billions
    var militaryTension: Double // 0-100
    var isAlly: Bool
    var isNuclearPower: Bool
    var interests: [String] // economic, military, ideological interests

    init(
        id: UUID = UUID(),
        name: String,
        leaderName: String,
        relationship: Double = 0,
        tradeBalance: Double = 0,
        militaryTension: Double = 0,
        isAlly: Bool = false,
        isNuclearPower: Bool = false,
        interests: [String] = []
    ) {
        self.id = id
        self.name = name
        self.leaderName = leaderName
        self.relationship = relationship
        self.tradeBalance = tradeBalance
        self.militaryTension = militaryTension
        self.isAlly = isAlly
        self.isNuclearPower = isNuclearPower
        self.interests = interests
    }

    var relationshipStatus: RelationshipStatus {
        if relationship >= 75 { return .closeAllies }
        else if relationship >= 50 { return .allies }
        else if relationship >= 25 { return .friendly }
        else if relationship >= 0 { return .neutral }
        else if relationship >= -25 { return .strained }
        else if relationship >= -50 { return .adversarial }
        else { return .hostile }
    }

    /// All countries available for diplomatic interactions in PresidentSim.
    static let presidentSimCountries: [Country] = [
        Country(name: "UK", leaderName: "Prime Minister", relationship: 80, isAlly: true, interests: ["NATO", "Trade", "Climate"]),
        Country(name: "France", leaderName: "President", relationship: 75, isAlly: true, interests: ["EU", "Trade", "Middle East"]),
        Country(name: "Germany", leaderName: "Chancellor", relationship: 72, isAlly: true, interests: ["EU", "Trade", "Energy"]),
        Country(name: "Japan", leaderName: "Prime Minister", relationship: 78, isAlly: true, interests: ["Trade", "Security", "Technology"]),
        Country(name: "Canada", leaderName: "Prime Minister", relationship: 85, isAlly: true, interests: ["Trade", "Energy", "Immigration"]),
        Country(name: "Australia", leaderName: "Prime Minister", relationship: 82, isAlly: true, interests: ["Security", "Trade", "Climate"]),
        Country(name: "China", leaderName: "President", relationship: 40, isNuclearPower: true, interests: ["Trade", "Taiwan", "Technology"]),
        Country(name: "Russia", leaderName: "President", relationship: 35, isNuclearPower: true, interests: ["Ukraine", "Energy", "Security"]),
        Country(name: "North Korea", leaderName: "Supreme Leader", relationship: 20, isNuclearPower: true, interests: ["Nuclear", "Security"]),
        Country(name: "Iran", leaderName: "President", relationship: 30, isNuclearPower: true, interests: ["Nuclear", "Middle East", "Sanctions"]),
        Country(name: "Mexico", leaderName: "President", relationship: 65, isAlly: false, interests: ["Trade", "Immigration", "Drugs"]),
        Country(name: "Brazil", leaderName: "President", relationship: 68, isAlly: false, interests: ["Trade", "Climate", "Amazon"]),
        Country(name: "India", leaderName: "Prime Minister", relationship: 70, isAlly: false, interests: ["Trade", "Security", "Climate"]),
        Country(name: "South Korea", leaderName: "President", relationship: 80, isAlly: true, interests: ["Security", "Trade", "Technology"]),
        Country(name: "Israel", leaderName: "Prime Minister", relationship: 75, isAlly: true, interests: ["Security", "Middle East", "Technology"]),
        Country(name: "Saudi Arabia", leaderName: "Crown Prince", relationship: 55, isAlly: false, interests: ["Oil", "Security", "Human Rights"]),
        Country(name: "Turkey", leaderName: "President", relationship: 50, isAlly: true, interests: ["NATO", "Trade", "Security"])
    ]
}

enum RelationshipStatus: String {
    case closeAllies = "Close Allies"
    case allies = "Allies"
    case friendly = "Friendly"
    case neutral = "Neutral"
    case strained = "Strained"
    case adversarial = "Adversarial"
    case hostile = "Hostile"

    var emoji: String {
        switch self {
        case .closeAllies: return "🤝"
        case .allies: return "👍"
        case .friendly: return "🙂"
        case .neutral: return "😐"
        case .strained: return "😕"
        case .adversarial: return "😠"
        case .hostile: return "⚔️"
        }
    }
}

struct InternationalIncident: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String
    let countriesInvolved: [String]
    let severity: Double // 0-1
    let turnOccurred: Int
    var isResolved: Bool
    var resolution: String?
    var impact: InternationalImpact

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        countriesInvolved: [String],
        severity: Double,
        turnOccurred: Int,
        isResolved: Bool = false,
        resolution: String? = nil,
        impact: InternationalImpact = InternationalImpact()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.countriesInvolved = countriesInvolved
        self.severity = severity
        self.turnOccurred = turnOccurred
        self.isResolved = isResolved
        self.resolution = resolution
        self.impact = impact
    }
}

struct InternationalImpact: Codable {
    var globalInfluenceChange: Double = 0
    var relationshipChanges: [String: Double] = [:]
    var economicEffects: [String: Double] = [:]
    var domesticApprovalChange: Double = 0
}

class InternationalRelationsEngine {
    private var countries: [Country] = []
    private var incidents: [InternationalIncident] = []
    private let aiBrain: MiniMaxService?
    private let useAI: Bool

    init(aiBrain: MiniMaxService? = nil, useAI: Bool = true) {
        self.aiBrain = aiBrain
        self.useAI = useAI && (aiBrain != nil)
        initializeCountries()
    }

    private func initializeCountries() {
        countries = [
            Country(name: "United Kingdom", leaderName: "Prime Minister", relationship: 75, isAlly: true, interests: ["trade", "security", "intelligence"]),
            Country(name: "France", leaderName: "President", relationship: 70, isAlly: true, interests: ["trade", "diplomacy"]),
            Country(name: "Germany", leaderName: "Chancellor", relationship: 65, isAlly: true, interests: ["trade", "economics"]),
            Country(name: "Japan", leaderName: "Prime Minister", relationship: 75, isAlly: true, interests: ["trade", "security"]),
            Country(name: "Canada", leaderName: "Prime Minister", relationship: 85, isAlly: true, interests: ["trade", "border security"]),
            Country(name: "Australia", leaderName: "Prime Minister", relationship: 80, isAlly: true, interests: ["security", "trade"]),
            Country(name: "South Korea", leaderName: "President", relationship: 70, isAlly: true, interests: ["security", "trade"]),
            Country(name: "Israel", leaderName: "Prime Minister", relationship: 60, isAlly: true, interests: ["security", "diplomacy"]),
            Country(name: "Mexico", leaderName: "President", relationship: 30, isAlly: false, interests: ["trade", "immigration", "border"]),
            Country(name: "China", leaderName: "President", relationship: -20, isAlly: false, isNuclearPower: true, interests: ["trade", "territory", "technology"]),
            Country(name: "Russia", leaderName: "President", relationship: -35, isAlly: false, isNuclearPower: true, interests: ["security", "territory", "influence"]),
            Country(name: "Iran", leaderName: "Supreme Leader", relationship: -50, isAlly: false, isNuclearPower: true, interests: ["nuclear", "regional influence"]),
            Country(name: "North Korea", leaderName: "Supreme Leader", relationship: -70, isAlly: false, isNuclearPower: true, interests: ["nuclear", "military"]),
            Country(name: "India", leaderName: "Prime Minister", relationship: 55, isAlly: false, isNuclearPower: true, interests: ["trade", "security", "diplomacy"]),
            Country(name: "Brazil", leaderName: "President", relationship: 45, isAlly: false, interests: ["trade", "diplomacy"]),
            Country(name: "Saudi Arabia", leaderName: "Crown Prince", relationship: 40, isAlly: false, interests: ["oil", "security", "human rights"])
        ]
    }

    func getCountry(_ name: String) -> Country? {
        countries.first { $0.name.lowercased() == name.lowercased() }
    }

    func getAllCountries() -> [Country] {
        countries
    }

    func updateRelationship(country: String, delta: Double) {
        if let index = countries.firstIndex(where: { $0.name.lowercased() == country.lowercased() }) {
            countries[index].relationship = max(-100, min(100, countries[index].relationship + delta))
        }
    }

    func createIncident(
        title: String,
        description: String,
        countriesInvolved: [String],
        severity: Double,
        turn: Int
    ) -> InternationalIncident {
        let incident = InternationalIncident(
            title: title,
            description: description,
            countriesInvolved: countriesInvolved,
            severity: severity,
            turnOccurred: turn
        )
        incidents.append(incident)
        return incident
    }

    func resolveIncident(_ incidentId: UUID, resolution: String, turn: Int) {
        if let index = incidents.firstIndex(where: { $0.id == incidentId }) {
            incidents[index].isResolved = true
            incidents[index].resolution = resolution

            // Apply resolution effects
            let incident = incidents[index]
            for (countryName, change) in incident.impact.relationshipChanges {
                updateRelationship(country: countryName, delta: change)
            }
        }
    }

    func generateRandomIncident(currentTurn: Int) -> InternationalIncident? {
        let roll = Double.random(in: 0...1)

        // 5% chance per turn of significant incident
        if roll > 0.05 { return nil }

        let incidentTypes: [(String, String, [String], Double)] = [
            ("Trade Dispute", "A major trade dispute erupts with \(["China", "EU", "Mexico"].randomElement()!)", ["trade"], 0.4),
            ("Military Tension", "Military tensions increase in \(["South China Sea", "Korean Peninsula", "Middle East"].randomElement()!)", ["military"], 0.6),
            ("Diplomatic Incident", "A diplomatic incident strains relations with \(["Russia", "China", "Iran"].randomElement()!)", ["diplomacy"], 0.3),
            ("Cyber Attack", "A major cyber attack is traced to \(["Russia", "China", "North Korea"].randomElement()!)", ["security"], 0.5),
            ("Human Rights", "Human rights concerns lead to tensions with \(["China", "Saudi Arabia", "Russia"].randomElement()!)", ["diplomacy", "human rights"], 0.3)
        ]

        let selected = incidentTypes.randomElement()!
        return createIncident(
            title: selected.0,
            description: selected.1,
            countriesInvolved: Array(selected.2),
            severity: selected.3,
            turn: currentTurn
        )
    }

    func calculateImpact(for incident: InternationalIncident) -> InternationalImpact {
        var impact = InternationalImpact()

        // Base impact on severity
        impact.globalInfluenceChange = -incident.severity * 10

        // Relationship damage
        for country in incident.countriesInvolved {
            if let countryData = getCountry(country) {
                if countryData.isAlly {
                    impact.relationshipChanges[country] = -incident.severity * 15
                } else {
                    impact.relationshipChanges[country] = incident.severity * 10
                }
            }
        }

        // Economic effects
        if incident.title.contains("Trade") {
            impact.economicEffects["trade"] = -incident.severity * 5
            impact.economicEffects["stockMarket"] = -incident.severity * 3
        }

        // Domestic approval (complexity depends on incident type)
        if incident.title.contains("Military") {
            impact.domesticApprovalChange = incident.severity * 5 // Rally effect
        } else {
            impact.domesticApprovalChange = -incident.severity * 3
        }

        return impact
    }

    func getActiveIncidents() -> [InternationalIncident] {
        incidents.filter { !$0.isResolved }
    }

    func getIncidentsHistory() -> [InternationalIncident] {
        incidents.sorted { $0.turnOccurred > $1.turnOccurred }
    }

    // MARK: - Diplomatic Actions

    func performDiplomaticAction(
        action: DiplomaticAction,
        targetCountry: String,
        turn: Int
    ) -> DiplomaticResult {
        guard let country = getCountry(targetCountry) else {
            return DiplomaticResult(
                success: false,
                narrative: "Country not found",
                effects: InternationalImpact()
            )
        }

        var impact = InternationalImpact()

        switch action {
        case .summit:
            // High-level meeting
            impact = InternationalImpact(
                relationshipChanges: [targetCountry: Double.random(in: 5...15)]
            )

        case .stateVisit:
            // Formal state visit - significant but costly
            impact = InternationalImpact(
                globalInfluenceChange: 0,
                relationshipChanges: [targetCountry: Double.random(in: 10...20)],
                domesticApprovalChange: Double.random(in: -2...3)
            )

        case .sanctions:
            // Economic pressure
            impact = InternationalImpact(
                globalInfluenceChange: 0,
                relationshipChanges: [targetCountry: Double.random(in: -20...(-5))],
                economicEffects: [targetCountry: Double.random(in: 2...5)]
            )

        case .tradeAgreement:
            // New trade deal
            impact = InternationalImpact(
                globalInfluenceChange: 0,
                relationshipChanges: [targetCountry: Double.random(in: 5...15)],
                economicEffects: ["trade": Double.random(in: 1...3)]
            )

        case .militaryAid:
            // Send military support
            impact = InternationalImpact(
                globalInfluenceChange: Double.random(in: 2...5),
                relationshipChanges: [targetCountry: Double.random(in: 10...20)]
            )

        case .demand:
            // Make demands (high risk)
            let roll = Double.random(in: 0...1)
            if roll > 0.5 && country.relationship < 0 {
                // Failure - relationship worsens
                impact = InternationalImpact(
                    relationshipChanges: [targetCountry: Double.random(in: -15...(-5))]
                )
            } else {
                impact = InternationalImpact(
                    relationshipChanges: [targetCountry: Double.random(in: -5...5)]
                )
            }
        }

        // Apply effects
        for (name, change) in impact.relationshipChanges {
            updateRelationship(country: name, delta: change)
        }

        return DiplomaticResult(
            success: true,
            narrative: generateNarrative(action: action, country: country.name, impact: impact),
            effects: impact
        )
    }

    private func generateNarrative(action: DiplomaticAction, country: String, impact: InternationalImpact) -> String {
        let change = impact.relationshipChanges[country] ?? 0

        if change > 10 {
            return "The \(action.rawValue) with \(country) was highly successful, significantly improving relations."
        } else if change > 0 {
            return "The \(action.rawValue) with \(country) improved bilateral relations."
        } else if change > -10 {
            return "The \(action.rawValue) with \(country) had mixed results."
        } else {
            return "The \(action.rawValue) with \(country) backfired and damaged relations."
        }
    }
}

enum DiplomaticAction: String, CaseIterable {
    case summit = "Summit Meeting"
    case stateVisit = "State Visit"
    case sanctions = "Impose Sanctions"
    case tradeAgreement = "Negotiate Trade Agreement"
    case militaryAid = "Provide Military Aid"
    case demand = "Make Demands"

    var description: String {
        switch self {
        case .summit: return "Informal meeting between leaders"
        case .stateVisit: return "Formal diplomatic ceremony"
        case .sanctions: return "Economic restrictions"
        case .tradeAgreement: return "New commercial treaty"
        case .militaryAid: return "Security assistance"
        case .demand: return "Pressure for concessions (risky)"
        }
    }

    var riskLevel: String {
        switch self {
        case .summit, .stateVisit, .tradeAgreement, .militaryAid:
            return "Low"
        case .sanctions:
            return "Medium"
        case .demand:
            return "High"
        }
    }
}

struct DiplomaticResult {
    let success: Bool
    let narrative: String
    let effects: InternationalImpact
}
