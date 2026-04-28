import Foundation

struct Player: Codable, Identifiable {
    let id: UUID
    var name: String
    var party: PoliticalParty
    var age: Int
    var health: Double // 0.0 to 1.0
    var charisma: Double // 1.0 to 10.0
    var intelligence: Double // 1.0 to 10.0
    var willpower: Double // 1.0 to 10.0
    var luck: Double // 1.0 to 10.0

    var homeState: String
    var occupation: String
    var priorExperience: [String]

    // Campaign specific
    var campaignFunds: Double
    var staffMorale: Double
    var nationalNameRecognition: Double

    // Policy positions
    var policyStances: [PolicyArea: PolicyStance]

    // Personal
    var familyStatus: String
    var scandals: [String]

    init(
        id: UUID = UUID(),
        name: String,
        party: PoliticalParty,
        age: Int = 45,
        health: Double = 0.9,
        charisma: Double = 5.0,
        intelligence: Double = 5.0,
        willpower: Double = 5.0,
        luck: Double = 5.0,
        homeState: String = "California",
        occupation: String = "Governor",
        priorExperience: [String] = [],
        campaignFunds: Double = 0,
        staffMorale: Double = 0.7,
        nationalNameRecognition: Double = 0.1,
        policyStances: [PolicyArea: PolicyStance] = [:],
        familyStatus: String = "Married, 2 children",
        scandals: [String] = []
    ) {
        self.id = id
        self.name = name
        self.party = party
        self.age = age
        self.health = health
        self.charisma = charisma
        self.intelligence = intelligence
        self.willpower = willpower
        self.luck = luck
        self.homeState = homeState
        self.occupation = occupation
        self.priorExperience = priorExperience
        self.campaignFunds = campaignFunds
        self.staffMorale = staffMorale
        self.nationalNameRecognition = nationalNameRecognition
        self.policyStances = policyStances.isEmpty ? Player.defaultStances() : policyStances
        self.familyStatus = familyStatus
        self.scandals = scandals
    }

    static func defaultStances() -> [PolicyArea: PolicyStance] {
        var stances: [PolicyArea: PolicyStance] = [:]
        for area in PolicyArea.allCases {
            stances[area] = .moderate
        }
        return stances
    }

    var displayAge: String {
        "\(age) years old"
    }

    var overallAbility: Double {
        (charisma + intelligence + willpower + luck) / 4.0
    }
}
