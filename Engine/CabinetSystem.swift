import Foundation

// MARK: - Cabinet System
// Manages cabinet appointments during presidency

struct CabinetMember: Codable, Identifiable {
    let id: UUID
    let name: String
    let position: CabinetPosition
    var loyalty: Double // 0-100
    var competence: Double // 0-100
    var scandalRisk: Double // 0-100
    var isActive: Bool
    var hireDate: Int // turn
    var resignationDate: Int?
    var notes: String

    init(
        id: UUID = UUID(),
        name: String,
        position: CabinetPosition,
        loyalty: Double = 70,
        competence: Double = 70,
        scandalRisk: Double = 20,
        isActive: Bool = true,
        hireDate: Int = 1,
        resignationDate: Int? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.position = position
        self.loyalty = loyalty
        self.competence = competence
        self.scandalRisk = scandalRisk
        self.isActive = isActive
        self.hireDate = hireDate
        self.resignationDate = resignationDate
        self.notes = notes
    }
}

enum CabinetPosition: String, Codable, CaseIterable {
    case secretaryOfState = "Secretary of State"
    case secretaryOfTreasury = "Secretary of Treasury"
    case secretaryOfDefense = "Secretary of Defense"
    case attorneyGeneral = "Attorney General"
    case secretaryOfTheInterior = "Secretary of Interior"
    case secretaryOfAgriculture = "Secretary of Agriculture"
    case secretaryOfCommerce = "Secretary of Commerce"
    case secretaryOfLabor = "Secretary of Labor"
    case secretaryOfHealth = "Secretary of Health & Human Services"
    case secretaryOfHousing = "Secretary of Housing & Urban Development"
    case secretaryOfTransportation = "Secretary of Transportation"
    case secretaryOfEnergy = "Secretary of Energy"
    case secretaryOfEducation = "Secretary of Education"
    case secretaryOfVeterans = "Secretary of Veterans Affairs"
    case secretaryOfHomelandSecurity = "Secretary of Homeland Security"
    case whiteHouseChiefOfStaff = "White House Chief of Staff"
    case pressSecretary = "Press Secretary"
    case nationalSecurityAdvisor = "National Security Advisor"

    var importance: Double {
        switch self {
        case .secretaryOfState, .secretaryOfTreasury, .secretaryOfDefense, .attorneyGeneral:
            return 1.0
        case .whiteHouseChiefOfStaff, .nationalSecurityAdvisor:
            return 0.9
        case .secretaryOfHealth, .secretaryOfCommerce, .secretaryOfLabor:
            return 0.7
        case .pressSecretary:
            return 0.6
        default:
            return 0.5
        }
    }

    var typicalBackground: [String] {
        switch self {
        case .secretaryOfState:
            return ["Foreign policy expert", "Former ambassador", "Senator"]
        case .secretaryOfTreasury:
            return ["Banker", "Economist", "Business executive"]
        case .secretaryOfDefense:
            return ["Military general", "Former defense official", "Senator"]
        case .attorneyGeneral:
            return ["Federal judge", "Prosecutor", "State AG"]
        case .pressSecretary:
            return ["Journalist", "PR executive", "Political operative"]
        default:
            return ["Policy expert", "Congressional staffer", "Industry expert"]
        }
    }
}

struct Cabinet {
    var members: [CabinetMember]

    init() {
        members = []
    }

    func member(for position: CabinetPosition) -> CabinetMember? {
        members.first { $0.position == position && $0.isActive }
    }

    var activeMembers: [CabinetMember] {
        members.filter { $0.isActive }
    }

    var averageCompetence: Double {
        guard !activeMembers.isEmpty else { return 0 }
        return activeMembers.reduce(0) { $0 + $1.competence } / Double(activeMembers.count)
    }

    var averageLoyalty: Double {
        guard !activeMembers.isEmpty else { return 0 }
        return activeMembers.reduce(0) { $0 + $1.loyalty } / Double(activeMembers.count)
    }

    var totalScandalRisk: Double {
        activeMembers.reduce(0) { $0 + $1.scandalRisk }
    }
}

class CabinetManager {
    private var cabinet = Cabinet()
    private let useAI: Bool
    private let aiBrain: MiniMaxService?

    init(aiBrain: MiniMaxService? = nil, useAI: Bool = true) {
        self.aiBrain = aiBrain
        self.useAI = useAI && (aiBrain != nil)
    }

    func generateCabinetShortlist(
        for position: CabinetPosition,
        partyBalance: Bool = true
    ) -> [CabinetMember] {
        var candidates: [CabinetMember] = []

        for i in 0..<3 {
            let name = generateName(for: position, index: i)
            let candidate = CabinetMember(
                name: name,
                position: position,
                loyalty: Double.random(in: 50...90),
                competence: Double.random(in: 60...95),
                scandalRisk: Double.random(in: 5...40)
            )
            candidates.append(candidate)
        }

        return candidates
    }

    func appointMember(_ member: CabinetMember) {
        // Remove any existing member in same position
        cabinet.members.removeAll { $0.position == member.position && $0.isActive }

        // Add new member
        var newMember = member
        newMember.isActive = true
        newMember.hireDate = 1 // Would be set to current turn
        cabinet.members.append(newMember)
    }

    func removeMember(at position: CabinetPosition, reason: String) {
        if let index = cabinet.members.firstIndex(where: { $0.position == position && $0.isActive }) {
            cabinet.members[index].isActive = false
            cabinet.members[index].resignationDate = 1 // Would be current turn
            cabinet.members[index].notes = reason
        }
    }

    func checkForScandals(currentTurn: Int) -> [ScandalReport] {
        var scandals: [ScandalReport] = []

        for member in cabinet.activeMembers {
            let roll = Double.random(in: 0...1)
            let scandalThreshold = member.scandalRisk / 100

            if roll < scandalThreshold * 0.1 {
                // Scandal breaks
                let report = ScandalReport(
                    memberId: member.id,
                    memberName: member.name,
                    position: member.position,
                    severity: roll / scandalThreshold,
                    headline: generateScandalHeadline(for: member),
                    turn: currentTurn
                )
                scandals.append(report)
            }
        }

        return scandals
    }

    func evaluatePerformance() -> CabinetPerformanceReport {
        CabinetPerformanceReport(
            activeMembers: cabinet.activeMembers.count,
            averageCompetence: cabinet.averageCompetence,
            averageLoyalty: cabinet.averageLoyalty,
            totalScandalRisk: cabinet.totalScandalRisk,
            recommendations: generateRecommendations()
        )
    }

    func getCabinet() -> Cabinet {
        return cabinet
    }

    // MARK: - Private Helpers

    private func generateName(for position: CabinetPosition, index: Int) -> String {
        let firstNames = ["James", "Sarah", "Michael", "Elizabeth", "David", "Jennifer", "Robert", "Michelle", "William", "Linda"]
        let lastNames = ["Thompson", "Martinez", "Anderson", "Taylor", "Thomas", "Jackson", "White", "Harris", "Clark", "Lewis"]

        let first = firstNames.randomElement() ?? "John"
        let last = lastNames.randomElement() ?? "Smith"
        let suffix = index > 0 ? " (\(position.rawValue.split(separator: " ").last ?? ""))" : ""

        return "\(first) \(last)\(suffix)"
    }

    private func generateScandalHeadline(for member: CabinetMember) -> String {
        let headlines = [
            "\(member.name) under investigation for \(member.position.rawValue.lowercased()) misconduct",
            "Reports surface about \(member.name)'s undisclosed meetings",
            "\(member.position.rawValue) \(member.name) faces questions about past dealings",
            "\(member.name) caught in controversy over policy decisions"
        ]
        return headlines.randomElement() ?? "Cabinet member \(member.name) faces scrutiny"
    }

    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []

        if cabinet.totalScandalRisk > 150 {
            recommendations.append("CRITICAL: Several cabinet members pose high scandal risk. Consider replacements.")
        } else if cabinet.totalScandalRisk > 100 {
            recommendations.append("WARNING: Monitor high-risk cabinet members closely.")
        }

        if cabinet.averageCompetence < 60 {
            recommendations.append("Your cabinet lacks experienced leadership. Consider recruiting experts.")
        }

        if cabinet.averageLoyalty < 50 {
            recommendations.append("Some cabinet members may not be fully loyal. Watch for dissent.")
        }

        return recommendations
    }
}

struct ScandalReport: Identifiable {
    let id = UUID()
    let memberId: UUID
    let memberName: String
    let position: CabinetPosition
    let severity: Double // 0-1
    let headline: String
    let turn: Int

    var severityDescription: String {
        if severity > 0.7 { return "Serious" }
        else if severity > 0.4 { return "Moderate" }
        else { return "Minor" }
    }
}

struct CabinetPerformanceReport {
    let activeMembers: Int
    let averageCompetence: Double
    let averageLoyalty: Double
    let totalScandalRisk: Double
    let recommendations: [String]
}
