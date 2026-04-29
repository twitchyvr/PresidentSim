import SwiftUI

// MARK: - Tutorial System
// Guides players through the game with contextual help

struct TutorialOverlay: View {
    @EnvironmentObject var engine: SimulationEngine
    @State private var currentStep = 0
    @State private var showTutorial = true
    @State private var selectedTopic: TutorialTopic?

    var body: some View {
        if showTutorial {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "book.fill")
                        .foregroundColor(.playerAccent)
                    Text("How to Play PresidentSim")
                        .font(.headline)
                    Spacer()
                    Button("Skip") {
                        withAnimation {
                            showTutorial = false
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Content
                if let topic = selectedTopic {
                    TutorialTopicView(topic: topic, onBack: {
                        selectedTopic = nil
                    })
                } else {
                    TutorialOverview(onSelectTopic: { topic in
                        withAnimation {
                            selectedTopic = topic
                        }
                    })
                }
            }
            .frame(width: 450, height: 400)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 10)
            .padding(40)
        }
    }
}

struct TutorialOverview: View {
    let onSelectTopic: (TutorialTopic) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Welcome to PresidentSim")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Experience the full arc of American politics - from announcing your candidacy to leaving office. Your choices shape history.")
                    .foregroundColor(.secondary)

                Divider()

                Text("Your Journey")
                    .font(.headline)

                VStack(spacing: 12) {
                    ForEach(TutorialTopic.allCases) { topic in
                        Button(action: { onSelectTopic(topic) }) {
                            HStack {
                                Image(systemName: topic.icon)
                                    .foregroundColor(.playerAccent)
                                    .frame(width: 30)

                                VStack(alignment: .leading) {
                                    Text(topic.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(topic.description_)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding(10)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }
}

struct TutorialTopicView: View {
    let topic: TutorialTopic
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onBack) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.playerAccent)

            Text(topic.title)
                .font(.title2)
                .fontWeight(.bold)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(topic.content)
                        .font(.body)

                    if !topic.tips.isEmpty {
                        Divider()

                        Text("Tips")
                            .font(.headline)

                        ForEach(topic.tips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.tipAccent)
                                    .font(.caption)
                                Text(tip)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
}

enum TutorialTopic: String, CaseIterable, Identifiable {
    case overview = "overview"
    case candidateCreation = "candidate"
    case campaign = "campaign"
    case primaries = "primaries"
    case convention = "convention"
    case election = "election"
    case presidency = "presidency"
    case decisions = "decisions"
    case economy = "economy"
    case diplomacy = "diplomacy"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Game Overview"
        case .candidateCreation: return "Creating Your Candidate"
        case .campaign: return "The Campaign Trail"
        case .primaries: return "Winning the Primary"
        case .convention: return "The Convention"
        case .election: return "General Election"
        case .presidency: return "Your Presidency"
        case .decisions: return "Decision Making"
        case .economy: return "Economic Indicators"
        case .diplomacy: return "Foreign Policy"
        }
    }

    var description_: String {
        switch self {
        case .overview: return "Understanding the game"
        case .candidateCreation: return "Build your candidate"
        case .campaign: return "Phase 1 of your journey"
        case .primaries: return "Defeat your rivals"
        case .convention: return "Secure the nomination"
        case .election: return "Battle for the White House"
        case .presidency: return "Lead the nation"
        case .decisions: return "Make tough choices"
        case .economy: return "Read the indicators"
        case .diplomacy: return "Handle world leaders"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "info.circle"
        case .candidateCreation: return "person.fill"
        case .campaign: return "road.lanes"
        case .primaries: return "person.3.fill"
        case .convention: return "flag.fill"
        case .election: return "checkmark.circle.fill"
        case .presidency: return "building.columns.fill"
        case .decisions: return "questionmark.circle.fill"
        case .economy: return "chart.line.uptrend.xyaxis"
        case .diplomacy: return "globe"
        }
    }

    var content: String {
        switch self {
        case .overview:
            return """
            PresidentSim simulates the complete journey of a presidential candidate - from unknown aspirant to former president.

            THE PHASES:
            1. Pre-Campaign: Announce your candidacy
            2. Campaign: Build momentum and name recognition
            3. Primaries: Win your party's nomination
            4. Convention: Choose a running mate
            5. General Election: Defeat your opponent
            6. Transition: Prepare to govern
            7. Presidency: Make decisions that shape the nation
            8. Lame Duck: Final months in office
            9. Exit: Your legacy is sealed

            THE GOAL:
            Win the election, then govern effectively. Your approval rating, economic management, and diplomatic skill determine your success.
            """

        case .candidateCreation:
            return """
            When creating your candidate, three stats matter:

            CHARISMA (4-8): Your ability to connect with voters, inspire crowds, and win debates. High charisma helps in elections.

            INTELLIGENCE (5-9): Your policy knowledge and decision-making wisdom. Affects how well you understand complex issues.

            WILLPOWER (4-8): Your resilience to scandals, crises, and pressure. High willpower helps you push through opposition.

            LUCK (3-7): Random events and unexpected opportunities. You cannot control this, but it can help or hurt you.

            Each stat is randomly assigned within ranges based on your background occupation.
            """

        case .campaign:
            return """
            The campaign phase is about building momentum. You start with low name recognition and must:
            - Gain media attention (positive or negative)
            - Build a war chest of donations
            - Establish your core positions
            - Travel to early states

            Press "Advance Turn" to move time forward. Each turn represents a week of campaigning. Watch your polling numbers and adjust your strategy.
            """

        case .primaries:
            return """
            Once you announce, you'll face primary opponents from your own party. The goal: accumulate delegates.

            DELEGATES: Win states to earn delegates. First past the post in most states.

            MOMENTUM: Winning states creates momentum, making it easier to win future states.

            STRATEGY: Focus on early states to build momentum, or concentrate resources on larger states later.
            """

        case .convention:
            return """
            If you win enough delegates, you'll face the national convention. Your task: formally secure the nomination and choose a running mate.

            THE VEEP CHOICE: Select a running mate who:
            - Balances your weaknesses (geography, experience, demographics)
            - Can help you win swing states
            - Would be ready to be president

            This choice affects your general election chances.
            """

        case .election:
            return """
            The general election is a two-month battle against your opponent. Unlike primaries, this is a national race.

            ELECTORAL COLLEGE: You need 270 of 538 electoral votes. Most states are winner-take-all.

            THE MAP: Focus on "swing states" where either candidate could win. Ignore safely red or blue states.

            DEBATES: You'll face presidential debates. Your charisma and intelligence stats affect your performance.
            """

        case .presidency:
            return """
            Congratulations, Mr. President. Now the real work begins.

            YOUR POWERS:
            - Sign bills into law or veto them
            - Issue executive orders
            - Appoint cabinet members and judges
            - Conduct foreign diplomacy
            - Command the military

            YOUR CHALLENGES:
            - Maintain approval above 50% to be effective
            - Manage the economy (GDP, unemployment, inflation)
            - Handle international crises
            - Navigate congressional relations
            """

        case .decisions:
            return """
            Each turn, you'll face decisions that shape your presidency.

            DECISIONS have:
            - Options with different approaches
            - Political capital costs
            - Risk levels (marked with ⚠️)
            - Unpredictable outcomes

            THE AI ENGINE:
            When you make unprecedented choices, the AI calculates realistic consequences based on:
            - Your relationship with affected parties
            - Current political climate
            - Your domestic approval
            - Historical precedents
            """

        case .economy:
            return """
            Four key indicators track the nation's economic health:

            GDP GROWTH: How fast the economy is growing. Above 2% is healthy.

            UNEMPLOYMENT: Percentage without jobs. Below 5% is full employment.

            INFLATION: Rising prices. 2-3% is normal, above 5% is concerning.

            STOCK MARKET: Investor confidence. Generally tracks with economic health.

            Your decisions can affect these indicators, and they in turn affect your approval.
            """

        case .diplomacy:
            return """
            As president, you represent America to the world.

            DIPLOMATIC TOOLS:
            - Summits: Informal meetings with leaders
            - State Visits: Formal diplomatic ceremonies
            - Trade Agreements: Economic partnerships
            - Military Aid: Security assistance
            - Sanctions: Economic pressure

            RELATIONSHIPS: Each country has a relationship score (-100 to +100). Your actions affect these relationships and have consequences.
            """
        }
    }

    var tips: [String] {
        switch self {
        case .overview:
            return [
                "Start by clicking 'Announce Candidacy' to begin",
                "Watch your approval rating - it affects everything",
                "Press 'Advance Turn' to move the game forward"
            ]
        case .candidateCreation:
            return [
                "Governors tend to have higher charisma",
                "Senators often have higher intelligence",
                "Higher willpower helps in crisis situations"
            ]
        case .campaign:
            return [
                "Early momentum matters - win the first few states",
                "Don't ignore fundraising - you need resources",
                "Your policy positions affect your base and swing voters"
            ]
        case .primaries:
            return [
                "Focus resources on delegate-rich states",
                "Momentum from wins creates free publicity",
                "Sometimes dropping out early to rally behind a leader is wise (in real life!)"
            ]
        case .convention:
            return [
                "Geography matters - a VP from a swing state helps",
                "Experience gaps can be filled by the VP pick",
                "The VP becomes your partner in governing"
            ]
        case .election:
            return [
                "Watch the swing states - ignore safe states",
                "Debates can shift momentum significantly",
                "Ground game (organizers) matters as much as advertising"
            ]
        case .presidency:
            return [
                "First 100 days set the tone",
                "Cabinet quality affects execution",
                "Crises can make or break a presidency"
            ]
        case .decisions:
            return [
                "No choice is purely good - each has tradeoffs",
                "Risky decisions (⚠️) can have big upsides or downsides",
                "Some decisions are irreversible"
            ]
        case .economy:
            return [
                "Economic cycles mean booms and busts",
                "Your policies have delayed effects",
                "Global events affect the economy too"
            ]
        case .diplomacy:
            return [
                "Allies appreciate cooperation but expect it",
                "Adversaries can be deterred or negotiated with",
                "Nuclear powers require special care"
            ]
        }
    }
}

// MARK: - Guided Tour View

struct GuidedTourView: View {
    @EnvironmentObject var engine: SimulationEngine
    @State private var currentPhaseIndex = 0
    @State private var isComplete = false

    var body: some View {
        VStack(spacing: 20) {
            if !isComplete {
                Text("Quick Tour: \(currentPhase.tourTitle)")
                    .font(.headline)

                Text(currentPhase.tourContent)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 400)

                HStack(spacing: 20) {
                    if currentPhaseIndex > 0 {
                        Button("Previous") {
                            withAnimation {
                                currentPhaseIndex -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(currentPhaseIndex == GuidedTour.phases.count - 1 ? "Get Started" : "Next") {
                        if currentPhaseIndex == GuidedTour.phases.count - 1 {
                            withAnimation {
                                isComplete = true
                            }
                        } else {
                            withAnimation {
                                currentPhaseIndex += 1
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)

                    Text("You're Ready!")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Click 'Announce Candidacy' to begin your journey to the White House.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(30)
    }

    var currentPhase: GuidedTour {
        GuidedTour.phases[currentPhaseIndex]
    }
}

struct GuidedTour {
    let tourTitle: String
    let tourContent: String

    static let phases: [GuidedTour] = [
        GuidedTour(
            tourTitle: "Your Goal",
            tourContent: "Win the presidential election, then govern effectively for two terms. Your choices shape America's future."
        ),
        GuidedTour(
            tourTitle: "Advance Turn",
            tourContent: "Click 'Advance Turn' to progress through time. Each turn represents important developments in your journey."
        ),
        GuidedTour(
            tourTitle: "Your Stats",
            tourContent: "Your candidate has Charisma, Intelligence, Willpower, and Luck. These affect your abilities throughout the game."
        ),
        GuidedTour(
            tourTitle: "Decisions",
            tourContent: "You'll face important decisions with multiple choices. Each has consequences - some predictable, some surprising."
        ),
        GuidedTour(
            tourTitle: "The Economy",
            tourContent: "Economic indicators show how the nation is doing. Manage well to maintain approval and win support."
        ),
        GuidedTour(
            tourTitle: "Begin Your Journey",
            tourContent: "Click 'Announce Candidacy' to start your campaign for the White House. Good luck, future President."
        )
    ]
}

// MARK: - Contextual Help

struct ContextualHelpButton: View {
    @State private var showHelp = false

    var body: some View {
        Button(action: { showHelp = true }) {
            Image(systemName: "questionmark.circle")
                .font(.title3)
        }
        .popover(isPresented: $showHelp, arrowEdge: .bottom) {
            Text("Need help? Click 'How to Play' in the menu bar for guidance.")
                .padding()
                .frame(width: 250)
        }
    }
}
