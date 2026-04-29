import SwiftUI

// MARK: - Helper Functions

private func formatCompactCurrency(_ amount: Double) -> String {
    if amount >= 1_000_000_000 {
        return String(format: "%.1fB", amount / 1_000_000_000)
    } else if amount >= 1_000_000 {
        return String(format: "%.1fM", amount / 1_000_000)
    } else if amount >= 1_000 {
        return String(format: "%.0fK", amount / 1_000)
    }
    return String(format: "%.0f", amount)
}

/// Maps camelCase internal effect keys to human-readable labels for UI display
private func humanReadableKey(_ key: String) -> String {
    switch key {
    case "approvalRating": return "Approval"
    case "congressionalSupport": return "Congress"
    case "partyUnityScore": return "Party Unity"
    case "momentum": return "Momentum"
    case "mediaFavorability": return "Media"
    case "campaignFunds": return "Funds"
    case "statePolling": return "State Poll"
    case "opponentPolling": return "Opponent Poll"
    case "globalInfluence": return "Global Influence"
    case "relationshipTarget": return "Diplomatic Relations"
    case "cabinetSatisfaction": return "Cabinet"
    case "donorSatisfaction": return "Donors"
    case "gdpGrowth": return "GDP"
    case "inflation": return "Inflation"
    case "unemployment": return "Jobs"
    case "internationalPrestige": return "Prestige"
    case "politicalCapital": return "Pol. Capital"
    default: return key.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
    }
}

// MARK: - Theme

extension Color {
    /// Player/candidate accent color (Democrat blue)
    static let playerAccent = Color.blue
    /// Opponent party accent (Republican red)
    static let opponentAccent = Color.red
    /// Tossup/swing state indicator
    static let tossupAccent = Color.orange
    /// Unread badge / alert color
    static let unreadBadge = Color.red
    /// Danger/warning badge (e.g., negative action tags)
    static let danger = Color.red
    /// Subtle danger background (cooldown warnings)
    static let dangerBackground = Color.red.opacity(0.1)
    /// Interactive highlight (active toolbar tab)
    static let tabHighlight = Color.orange
    /// Secondary interactive (inactive toolbar tab)
    static let tabDefault = Color.blue
    /// Tip/idea accent (lightbulb icons)
    static let tipAccent = Color.yellow
    /// Positive/good indicator (approval up, gains, success)
    static let positive = Color.green
    /// Special/campaign indicator (AI tag, funds)
    static let special = Color.purple
}

@main
struct PresidentSimApp: App {
    @StateObject private var engine = SimulationEngine()
    @State private var showNewGame = true
    @State private var apiKey: String = ""

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .sheet(isPresented: $showNewGame) {
                    NewGameView(isPresented: $showNewGame)
                        .environmentObject(engine)
                }
                .frame(minWidth: 1000, minHeight: 700)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var engine: SimulationEngine
    @State private var showTutorial = false
    @State private var selectedEvent: GameEvent?
    @State private var newsTickerText = ""
    @State private var showCommandCenter = false
    @State private var showBriefings = false
    @State private var showSaveLoad = false
    @State private var showNewGame = false

    var body: some View {
        VStack(spacing: 0) {
            // News ticker
            if !newsTickerText.isEmpty {
                NewsTickerView(text: newsTickerText, trendingTopic: engine.gameState.world.trendingTopic)
            }

            // Top bar
            HStack {
                Text("PRESIDENT SIM")
                    .font(.title)
                    .fontWeight(.bold)

                // Action buttons
                HStack(spacing: 8) {
                    Button(action: { showCommandCenter.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape.fill")
                            Text(showCommandCenter ? "Hide Actions" : "Actions")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(showCommandCenter ? .tossupAccent : .playerAccent)
                    .accessibilityIdentifier("toolbar.actions")

                    Divider().frame(height: 16)

                    Button(action: { showBriefings.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "tray.fill")
                            Text("Briefings")
                            if unreadBriefingsCount > 0 {
                                Text("(\(unreadBriefingsCount))")
                                    .foregroundColor(.unreadBadge)
                                    .font(.caption)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(showBriefings ? .tossupAccent : .playerAccent)
                    .accessibilityIdentifier("toolbar.briefings")

                    Divider().frame(height: 16)

                    Button(action: { showSaveLoad.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down.on.square")
                            Text("Save/Load")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(showSaveLoad ? .tossupAccent : .playerAccent)
                    .accessibilityIdentifier("toolbar.saveLoad")
                }

                Spacer()

                // Help button
                Button(action: { showTutorial = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                        Text("How to Play")
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.playerAccent)
                .accessibilityIdentifier("toolbar.help")

                Divider()
                    .frame(height: 20)

                Text(engine.gameState.turnDescription)
                    .font(.headline)
                    .foregroundColor(.secondary)

                advanceButton
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main content
            HStack(spacing: 0) {
                // Left sidebar - player info & stats
                PlayerInfoSidebar()

                Divider()

                // Center - main game area
                GameMainView(showNewGame: $showNewGame)

                Divider()

                // Right sidebar - events & decisions
                EventSidebar(selectedEvent: $selectedEvent)
            }
        }
        .sheet(isPresented: $showTutorial) {
            TutorialOverlay()
                .environmentObject(engine)
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
        .sheet(isPresented: $showCommandCenter) {
            CommandCenterView()
                .environmentObject(engine)
        }
        .sheet(isPresented: $showBriefings) {
            BriefingsView()
                .environmentObject(engine)
        }
        .sheet(isPresented: $showSaveLoad) {
            SaveLoadView(engine: engine)
        }
        .onAppear {
            loadAPIKeyIfNeeded()
            updateNewsTicker()
        }
        .onChange(of: engine.gameState.world.actionResultsThisTurn.count) { _, _ in
            updateNewsTicker()
        }
    }

    private var advanceButton: some View {
        Group {
            if engine.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .progressViewStyle(.circular)
                    Text("Processing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            } else if !engine.gameState.pendingDecisions.isEmpty {
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.tossupAccent)
                        Text("Decision Required")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(true)
                .opacity(0.7)
                .accessibilityIdentifier("advance.decisionRequired")
            } else if engine.gameState.phase == .preCampaign && engine.gameState.player.name != "Player" {
                Button("Announce Candidacy") {
                    Task {
                        await engine.declareCandidacy()
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("advance.announceCandidacy")
            } else {
                Button("Advance Turn") {
                    Task {
                        await engine.advanceTurn()
                        // Possibly generate a briefing
                        if Double.random(in: 0...1) < 0.3 {
                            generatePeriodicBriefing()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(" ")
                .accessibilityIdentifier("advance.turn")
            }
        }
    }

    private func updateNewsTicker() {
        let actionResults = engine.gameState.world.actionResultsThisTurn
        let recentEvents = engine.gameState.activeEvents.prefix(2)
        var tickerParts: [String] = []

        if !actionResults.isEmpty {
            tickerParts.append(contentsOf: actionResults)
        }

        for event in recentEvents {
            tickerParts.append("[\(event.category.rawValue)] \(event.title): \(event.description)")
        }

        newsTickerText = tickerParts.joined(separator: " • ")
    }

    private func loadAPIKeyIfNeeded() {
        let envPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".PresidentSim/env").path
        if let content = try? String(contentsOfFile: envPath),
           let keyRange = content.range(of: "MINIMAX_API_KEY=") {

            let start = keyRange.upperBound
            let end = content[start...].firstIndex(of: "\n") ?? content.endIndex
            let key = String(content[start..<end]).trimmingCharacters(in: .whitespaces)

            if !key.isEmpty && engine.aiBrain == nil {
                engine.initializeAI(apiKey: key)
            }
        }
    }

    private func generatePeriodicBriefing() {
        let briefingTypes: [BriefingType] = [.campaign, .legislative, .diplomatic, .media, .administrative]
        let type = briefingTypes.randomElement()!

        let briefingTemplates: [BriefingType: [(String, String, [BriefingOption])]] = [
            .campaign: [
                ("Polling Results", "New internal polling shows movement in key states.", [
                    BriefingOption(label: "Review data", description: "Dive deep into the numbers and adjust your message accordingly.", pros: ["Better targeting", "Informed message"], cons: ["Takes time and resources", "May reveal bad news"]),
                    BriefingOption(label: "Adjust strategy", description: "Shift campaign focus based on the latest numbers.", pros: ["Responsive to voters", "Can seize momentum"], cons: ["May alienate base", "Perceived as flip-flopping"]),
                    BriefingOption(label: "Ignore", description: "Stick with your current plan and trust your instincts.", pros: ["Consistent message", "Saves resources"], cons: ["May miss warning signs", "Strategy could be off-target"]),
                ]),
            ],
            .legislative: [
                ("Congressional Interest", "Bipartisan group wants to meet about shared priorities.", [
                    BriefingOption(label: "Meet with them", description: "Accept the meeting and explore possible collaboration.", pros: ["Builds goodwill", "May produce legislation"], cons: ["Takes time", "May create obligations"]),
                    BriefingOption(label: "Send aide", description: "Send a senior staffer to explore on your behalf.", pros: ["Stays informed", "Keeps options open"], cons: ["May seem dismissive", "No commitment conveyed"]),
                    BriefingOption(label: "Decline", description: "Politely decline and focus on other priorities.", pros: ["Saves time", "Signals priorities"], cons: ["Burns bridges", "Missed opportunity"]),
                ]),
            ],
            .diplomatic: [
                ("Foreign Policy Update", "Allies are seeking clarity on your administration's stance.", [
                    BriefingOption(label: "Schedule call", description: "Arrange a direct call with the foreign leader.", pros: ["Strong relationship signal", "Clear communication"], cons: ["Time-intensive", "May raise expectations"]),
                    BriefingOption(label: "Send statement", description: "Issue a written statement through diplomatic channels.", pros: ["Official record", "Carefully worded"], cons: ["Less personal", "May seem impersonal"]),
                    BriefingOption(label: "Defer", description: "Acknowledge but postpone until after other priorities.", pros: ["Focus on domestic agenda", "No rushed decision"], cons: ["Allies may feel neglected", "Uncertainty creates risk"]),
                ]),
            ],
            .media: [
                ("Interview Request", "Major network requests exclusive interview.", [
                    BriefingOption(label: "Accept", description: "Do the interview and speak directly to voters.", pros: ["Direct message", "Positive press"], cons: ["Risk of missteps", "Time commitment"]),
                    BriefingOption(label: "Decline", description: "Pass on the opportunity.", pros: ["No risk", "Focus elsewhere"], cons: ["Missed coverage", "Seems evasive"]),
                    BriefingOption(label: "Offer surrogate", description: "Send a senior advisor instead.", pros: ["Still in conversation", "Controlled message"], cons: ["Less impactful", "Network may be disappointed"]),
                ]),
            ],
            .administrative: [
                ("Transition Update", "Transition team reports on preparation progress.", [
                    BriefingOption(label: "Review report", description: "Study the full report in detail.", pros: ["Full picture", "Informed decisions"], cons: ["Takes significant time", "May reveal problems"]),
                    BriefingOption(label: "Schedule briefing", description: "Get a verbal briefing from the team lead.", pros: ["Efficient", "Can ask questions"], cons: ["Less thorough", "Dependent on presenter"]),
                    BriefingOption(label: "Delegate", description: "Assign a trusted aide to review and summarize.", pros: ["Frees your time", "Still covered"], cons: ["Secondhand info", "Aide may miss nuance"]),
                ]),
            ]
        ]

        if let templates = briefingTemplates[type], let template = templates.randomElement() {
            let newBriefing = Briefing(
                type: type,
                title: template.0,
                summary: template.1,
                urgency: Int.random(in: 1...5),
                turnReceived: engine.gameState.world.currentTurn,
                deadline: engine.gameState.world.currentTurn + Int.random(in: 2...5),
                options: template.2
            )
            engine.insertBriefing(newBriefing)
        }
    }

    private var unreadBriefingsCount: Int {
        engine.unreadBriefingsCount
    }
}

// MARK: - Player Info Sidebar

struct PlayerInfoSidebar: View {
    @EnvironmentObject var engine: SimulationEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Player card
                SidebarCard(title: "Candidate Profile", icon: "person.fill") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(engine.gameState.player.name)
                                .font(.headline)
                            Spacer()
                            Text(engine.gameState.player.party.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(partyColor)
                                .cornerRadius(4)
                        }

                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(engine.gameState.player.homeState)
                            Text("•")
                            Image(systemName: "briefcase.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(engine.gameState.player.occupation)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)

                        Divider()

                        // Candidate stats with visual bars
                        CandidateStatBar(label: "Charisma", value: engine.gameState.player.charisma, max: 10, color: .tossupAccent)
                        CandidateStatBar(label: "Intelligence", value: engine.gameState.player.intelligence, max: 10, color: .playerAccent)
                        CandidateStatBar(label: "Willpower", value: engine.gameState.player.willpower, max: 10, color: .special)
                    }
                }

                // Approval Rating Gauge
                SidebarCard(title: "Approval Rating", icon: "chart.bar.fill") {
                    VStack(spacing: 12) {
                        ApprovalGaugeView(approval: engine.gameState.world.approvalRating)

                        // Approval Trend
                        ApprovalTrendView(
                            history: engine.gameState.resources.approvalHistory,
                            currentApproval: engine.gameState.world.approvalRating
                        )

                        Divider()

                        VStack(spacing: 6) {
                            StatRow(label: "Congressional Support", value: engine.gameState.world.congressionalSupport, max: 100, color: .playerAccent)
                            StatRow(label: "Party Unity", value: engine.gameState.world.partyUnityScore, max: 100, color: partyColor)
                        }
                    }
                }

                // Political Capital
                SidebarCard(title: "Resources", icon: "bolt.fill") {
                    VStack(spacing: 8) {
                        PoliticalCapitalGauge(capital: engine.gameState.resources.politicalCapital)

                        Divider()

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Funds")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("$\(formatCompactCurrency(Double(engine.gameState.resources.campaignFunds)))")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Media")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(engine.gameState.resources.mediaCycles) cycles")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }

                // Campaign Progress (show during campaign phases)
                if showCampaignProgress {
                    SidebarCard(title: "Campaign Progress", icon: "flag.fill") {
                        VStack(spacing: 8) {
                            // Momentum indicator
                            HStack {
                                Text("Momentum")
                                    .font(.caption)
                                Spacer()
                                MomentumIndicator(momentum: engine.gameState.resources.momentum)
                            }

                            Divider()

                            // Delegates (primaries)
                            if engine.gameState.phase == .primaries || engine.gameState.phase == .campaign {
                                VStack(spacing: 4) {
                                    HStack {
                                        Text("Delegates")
                                            .font(.caption)
                                        Spacer()
                                        Text("\(engine.gameState.primaryDelegates)/\(engine.gameState.totalDelegatesNeeded)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    }

                                    ProgressView(value: Double(engine.gameState.primaryDelegates), total: Double(engine.gameState.totalDelegatesNeeded))
                                        .tint(.blue)

                                    Text("\(Int(Double(engine.gameState.primaryDelegates) / Double(engine.gameState.totalDelegatesNeeded) * 100))% of needed delegates")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            // Electoral votes (general election)
                            if engine.gameState.phase == .generalElection {
                                VStack(spacing: 4) {
                                    HStack {
                                        Text("Electoral Votes")
                                            .font(.caption)
                                        Spacer()
                                        Text("\(engine.gameState.electoralVotes)/270")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    }

                                    ProgressView(value: Double(engine.gameState.electoralVotes), total: 270)
                                        .tint(engine.gameState.electoralVotes >= 270 ? .positive : .tossupAccent)

                                    Text("\(engine.gameState.electoralVotes >= 270 ? "Winner!" : "\(270 - engine.gameState.electoralVotes) needed to win")")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // Policy Stances preview
                GroupBox("Key Issues") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(engine.gameState.player.policyStances.prefix(3)), id: \.key) { stance in
                            HStack {
                                Text(stance.key.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(stance.value.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 220)
    }

    var partyColor: Color {
        switch engine.gameState.player.party {
        case .democrat: return .playerAccent
        case .republican: return .opponentAccent
        case .independent: return .special
        }
    }

    var showCampaignProgress: Bool {
        switch engine.gameState.phase {
        case .campaign, .primaries, .convention, .generalElection:
            return true
        default:
            return false
        }
    }
}

struct CandidateStatBar: View {
    let label: String
    let value: Double
    let max: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .help(statTooltip)
                Spacer()
                Text(String(format: "%.0f", value))
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * (value / max), height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
        }
    }

    private var statTooltip: String {
        switch label {
        case "Charisma": return "Charisma: Ability to connect with voters and inspire crowds. High charisma helps in speeches, debates, and campaign rallies."
        case "Intelligence": return "Intelligence: Mental acuity and policy understanding. Affects negotiation outcomes and crisis decision quality."
        case "Willpower": return "Willpower: Determination and resilience under pressure. Helps resist scandals, survive crises, and push through opposition."
        default: return label
        }
    }
}

struct ApprovalGaugeView: View {
    let approval: Double

    var gaugeColor: Color {
        if approval >= 60 { return .green }
        if approval >= 40 { return .orange }
        return .red
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: approval / 100)
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text(String(format: "%.0f", approval))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, height: 80)
            .help("Approval Rating: Percentage of Americans who approve of your performance. Above 60% is strong; below 40% is weak. Affects electoral prospects, congressional leverage, and media coverage.")

            Text(approvalDescription)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    var approvalDescription: String {
        if approval >= 60 { return "Strong" }
        if approval >= 40 { return "Mixed" }
        return "Weak"
    }
}

struct MomentumIndicator: View {
    let momentum: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: momentumIcon)
                .foregroundColor(momentumColor)
                .font(.caption)

            Text(String(format: "%.1f", abs(momentum)))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(momentumColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(momentumColor.opacity(0.1))
        .cornerRadius(4)
        .help("Campaign Momentum: Positive values mean your campaign is gaining energy and poll movement. Negative values mean you are losing ground. Above 2 or below -2 indicates significant shifts.")
    }

    var momentumIcon: String {
        if momentum > 0.5 { return "arrow.up.right.circle.fill" }
        if momentum < -0.5 { return "arrow.down.right.circle.fill" }
        return "minus.circle.fill"
    }

    var momentumColor: Color {
        if momentum > 0.5 { return .green }
        if momentum < -0.5 { return .red }
        return .gray
    }
}

// MARK: - Approval Trend Chart

struct ApprovalTrendView: View {
    let history: [Double]
    let currentApproval: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Approval Trend")
                .font(.caption2)
                .foregroundColor(.secondary)

            if history.count > 1 {
                GeometryReader { geo in
                    Path { path in
                        let width = geo.size.width
                        let height = geo.size.height
                        let stepX = width / CGFloat(max(history.count - 1, 1))

                        for (index, value) in history.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = height - (CGFloat(value) / 100.0 * height)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.playerAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                .frame(height: 40)

                HStack {
                    Text("\(Int(history.last ?? 0))%")
                        .font(.caption2)
                        .fontWeight(.bold)
                    Spacer()
                    if history.count > 1 {
                        let change = (history.last ?? 0) - (history.first ?? 0)
                        HStack(spacing: 2) {
                            Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption2)
                            Text("\(Int(abs(change))) pts")
                                .font(.caption2)
                        }
                        .foregroundColor(change >= 0 ? .positive : .danger)
                    }
                }
            } else {
                Text("Not enough data")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(height: 40)
            }
        }
    }
}

// MARK: - Political Capital Gauge

struct PoliticalCapitalGauge: View {
    let capital: Double
    let maxCapital: Double = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.tossupAccent)
                Text("Political Capital")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .help("Political Capital: The currency of governance. Used to pass legislation, make appointments, and negotiate with Congress. Regenerates slowly over time. Spent on major actions.")
                Spacer()
                Text("\(Int(capital))/\(Int(maxCapital))")
                    .font(.caption2)
                    .fontWeight(.medium)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .cornerRadius(4)

                    Rectangle()
                        .fill(capitalColor)
                        .frame(width: geo.size.width * CGFloat(capital / maxCapital))
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)

            HStack {
                ForEach(0..<4) { i in
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 8)
                    if i < 3 { Spacer() }
                }
            }
        }
    }

    var capitalColor: Color {
        if capital >= 70 { return .green }
        if capital >= 40 { return .yellow }
        return .red
    }
}

// MARK: - Sidebar Card Helper

struct SidebarCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.playerAccent)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }
            content
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct StatRow: View {
    let label: String
    let value: Double
    let max: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .help(statTooltip)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)
                    Rectangle()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value / max), height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
        }
    }

    private var statTooltip: String {
        switch label {
        case "Congressional Support": return "Congressional Support: How well you work with Congress. Above 60 means easier legislation passage. Below 40 means obstruction and gridlock."
        case "Party Unity": return "Party Unity: How united your party is behind you. High unity helps in elections and legislating. Low unity risks primary challenges and defections."
        default: return label
        }
    }
}

// MARK: - Event Sidebar

struct EventSidebar: View {
    @EnvironmentObject var engine: SimulationEngine
    @Binding var selectedEvent: GameEvent?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Situation Feed
                GroupBox("Situation Feed") {
                    VStack(alignment: .leading, spacing: 8) {
                        // Current narrative with timestamp
                        HStack(alignment: .top) {
                            Circle()
                                .fill(Color.playerAccent)
                                .frame(width: 8, height: 8)
                                .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("This Turn's Actions")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                if engine.gameState.world.actionResultsThisTurn.isEmpty {
                                    Text("No actions taken yet.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(engine.gameState.world.actionResultsThisTurn, id: \.self) { result in
                                        Text(result)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                        }

                        // Recent ledger entries as timeline
                        ForEach(engine.gameState.world.historicalLedger.suffix(5).reversed()) { entry in
                            SituationFeedItem(entry: entry)
                        }
                    }
                }

                // Pending decisions
                if !engine.gameState.pendingDecisions.isEmpty {
                    GroupBox("Decisions Required") {
                        VStack(spacing: 8) {
                            ForEach(engine.gameState.pendingDecisions) { decision in
                                DecisionCard(decision: decision)
                            }
                        }
                    }
                }

                // Active events
                if !engine.gameState.activeEvents.isEmpty {
                    GroupBox("Active Events") {
                        VStack(spacing: 8) {
                            ForEach(engine.gameState.activeEvents) { event in
                                EventCard(event: event) {
                                    selectedEvent = event
                                }
                            }
                        }
                    }
                }

                // Recent decisions
                if !engine.gameState.recentDecisions.isEmpty {
                    GroupBox("Recent History") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(engine.gameState.recentDecisions.prefix(5)) { result in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: outcomeIcon(for: result.outcome))
                                        .font(.caption2)
                                        .foregroundColor(outcomeColor(for: result.outcome))

                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(result.decision.prompt)
                                            .font(.caption2)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)

                                        Text(result.narrative)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    func outcomeIcon(for outcome: DecisionOutcome) -> String {
        switch outcome {
        case .success: return "checkmark.circle.fill"
        case .mixed: return "minus.circle.fill"
        case .failure: return "xmark.circle.fill"
        }
    }

    func outcomeColor(for outcome: DecisionOutcome) -> Color {
        switch outcome {
        case .success: return .green
        case .mixed: return .orange
        case .failure: return .red
        }
    }
}

struct SituationFeedItem: View {
    let entry: LedgerEntry

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Rectangle()
                .fill(phaseColor)
                .frame(width: 2)
                .cornerRadius(1)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(entry.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                if !entry.effects.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(entry.effects.prefix(4)), id: \.key) { effect in
                            Text("\(humanReadableKey(effect.key)): \(effect.value >= 0 ? "+" : "")\(Int(effect.value))")
                                .font(.caption2)
                                .foregroundColor(effect.value >= 0 ? .positive : .danger)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(2)
                        }
                    }
                }
            }
        }
    }

    var phaseColor: Color {
        switch entry.phase {
        case .preCampaign, .campaign: return .playerAccent
        case .primaries: return .special
        case .convention: return .orange
        case .generalElection: return .red
        case .transition: return .cyan
        case .presidency, .lameDuck: return .green
        case .exited: return .gray
        }
    }
}

struct DecisionCard: View {
    @EnvironmentObject var engine: SimulationEngine
    let decision: Decision
    @State private var pendingIndex: Int? = nil
    @State private var showConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(decision.prompt)
                .font(.caption)
                .fontWeight(.medium)

            Text(decision.context)
                .font(.caption2)
                .foregroundColor(.secondary)

            ForEach(Array(decision.options.enumerated()), id: \.element.id) { index, option in
                Button(action: {
                    pendingIndex = index
                    showConfirmation = true
                }) {
                    HStack {
                        Text(option.text)
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                        if option.isRisky {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.tossupAccent)
                                .font(.caption2)
                        }
                    }
                    .padding(6)
                    .background(pendingIndex == index ? Color.accentColor.opacity(0.3) : Color.clear)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("decision.\(decision.id.uuidString.prefix(8)).option.\(index)")
            }

            if showConfirmation, let idx = pendingIndex {
                VStack(spacing: 6) {
                    Text("Are you sure?")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        Button("Confirm") {
                            Task {
                                await engine.makeDecision(decision, choiceIndex: idx)
                            }
                            showConfirmation = false
                            pendingIndex = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .accessibilityIdentifier("decision.\(decision.id.uuidString.prefix(8)).confirm")

                        Button("Cancel", role: .cancel) {
                            showConfirmation = false
                            pendingIndex = nil
                        }
                        .controlSize(.small)
                        .accessibilityIdentifier("decision.\(decision.id.uuidString.prefix(8)).cancel")
                    }
                }
                .padding(8)
                .background(Color(NSColor.selectedContentBackgroundColor).opacity(0.15))
                .cornerRadius(6)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .accessibilityIdentifier("decision.\(decision.id.uuidString.prefix(8))")
    }
}

struct EventCard: View {
    let event: GameEvent
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                // Category indicator bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(categoryColor)
                    .frame(width: 4, height: 35)
                    .help(categoryTooltip)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(event.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(event.isResolved ? .secondary : .primary)

                        if event.isResolved {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.positive)
                        } else if event.isAIGenerated {
                            Text("AI")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.special)
                                .cornerRadius(3)
                        }
                    }

                    Text(event.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(event.isResolved ? Color.positive.opacity(0.08) : Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(categoryColor.opacity(0.3), lineWidth: 1)
                )
        )
        .opacity(event.isResolved ? 0.7 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    var categoryColor: Color {
        switch event.category {
        case .economic: return .positive
        case .political: return .playerAccent
        case .international: return .special
        case .social: return .tossupAccent
        case .crisis: return .danger
        case .scandal: return .danger
        case .achievement: return .tipAccent
        case .personal: return .gray
        }
    }

    var categoryTooltip: String {
        switch event.category {
        case .economic: return "Economic: An event affecting GDP, jobs, inflation, or markets."
        case .political: return "Political: An event related to Congress, elections, or party politics."
        case .international: return "International: A foreign policy event involving other nations or global affairs."
        case .social: return "Social: A cultural or societal event affecting public values and demographics."
        case .crisis: return "Crisis: A urgent event requiring immediate leadership attention."
        case .scandal: return "Scandal: A controversy or damaging revelation about you or your administration."
        case .achievement: return "Achievement: A positive accomplishment that boosts your standing."
        case .personal: return "Personal: A private or biographical event affecting you or your family."
        }
    }
}

// MARK: - Game Main View

struct GameMainView: View {
    @EnvironmentObject var engine: SimulationEngine
    @Binding var showNewGame: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Phase-specific content
            switch engine.gameState.phase {
            case .preCampaign:
                PreCampaignView()
            case .campaign, .primaries:
                CampaignView()
            case .convention:
                ConventionView()
            case .generalElection:
                ElectionView()
            case .transition:
                TransitionView()
            case .presidency, .lameDuck:
                PresidencyView()
            case .exited:
                ExitedView(showNewGame: $showNewGame)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Phase Views

struct PreCampaignView: View {
    @EnvironmentObject var engine: SimulationEngine

    var body: some View {
        VStack(spacing: 24) {
            Text("Your Journey to the White House")
                .font(.title)

            Text("Before you lies the most consequential political journey in American life. Years of planning, millions of dollars, and countless hours of campaigning stand between you and the Oval Office.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 500)

            if engine.gameState.player.name == "Player" {
                Text("Configure your candidate in the New Game setup")
                    .foregroundColor(.secondary)
            } else {
                Button("Announce Candidacy") {
                    Task {
                        await engine.declareCandidacy()
                    }
                }
                .buttonStyle(.borderedProminent)
                .font(.headline)
            }
        }
        .padding()
    }
}

struct CampaignView: View {
    @EnvironmentObject var engine: SimulationEngine

    var body: some View {
        VStack(spacing: 16) {
            // Economic dashboard
            EconomicDashboard()

            Divider()

            // Primary opponents
            if !engine.gameState.primaryOpponents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Primary Opponents")
                        .font(.headline)

                    ForEach(engine.gameState.primaryOpponents) { opponent in
                        HStack {
                            Text(opponent.name)
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(opponent.currentPolling))%")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if opponent.momentum > 0 {
                                Image(systemName: "arrow.up")
                                    .foregroundColor(.positive)
                                    .font(.caption)
                            } else if opponent.momentum < 0 {
                                Image(systemName: "arrow.down")
                                    .foregroundColor(.unreadBadge)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

struct ConventionView: View {
    @EnvironmentObject var engine: SimulationEngine

    var body: some View {
        VStack(spacing: 16) {
            Text("National Convention")
                .font(.title)

            Text("Your party gathers to formally nominate you as their candidate. The choice of running mate is yours to make.")
                .foregroundColor(.secondary)

            if engine.gameState.chosenVP == nil {
                Text("Select a Vice Presidential running mate")
                    .font(.headline)

                VStack(spacing: 8) {
                    ForEach(["Senator Maria Santos", "Governor John Davis", "Mayor Lisa Chen"], id: \.self) { name in
                        Button(name) {
                            engine.selectVP(name)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                Text("Running Mate: \(engine.gameState.chosenVP!)")
                    .font(.headline)
            }
        }
        .padding()
    }
}

struct ElectionView: View {
    @EnvironmentObject var engine: SimulationEngine

    var body: some View {
        VStack(spacing: 16) {
            Text("General Election")
                .font(.title)

            // Electoral Map
            ElectoralMapView()

            // Running mate
            if let vp = engine.gameState.chosenVP {
                Text("Running Mate: \(vp)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Electoral Map View

struct ElectoralMapView: View {
    @EnvironmentObject var engine: SimulationEngine
    @State private var selectedState: ElectoralState?

    // Simplified state data - key states for demonstration
    let states: [ElectoralState] = [
        ElectoralState(name: "California", abbreviation: "CA", electoralVotes: 54, region: .west, isCoastal: true),
        ElectoralState(name: "Texas", abbreviation: "TX", electoralVotes: 40, region: .south, isCoastal: false),
        ElectoralState(name: "Florida", abbreviation: "FL", electoralVotes: 30, region: .south, isCoastal: true),
        ElectoralState(name: "New York", abbreviation: "NY", electoralVotes: 28, region: .northeast, isCoastal: true),
        ElectoralState(name: "Pennsylvania", abbreviation: "PA", electoralVotes: 19, region: .northeast, isCoastal: false),
        ElectoralState(name: "Illinois", abbreviation: "IL", electoralVotes: 19, region: .midwest, isCoastal: false),
        ElectoralState(name: "Ohio", abbreviation: "OH", electoralVotes: 17, region: .midwest, isCoastal: false),
        ElectoralState(name: "Georgia", abbreviation: "GA", electoralVotes: 16, region: .south, isCoastal: false),
        ElectoralState(name: "North Carolina", abbreviation: "NC", electoralVotes: 16, region: .south, isCoastal: true),
        ElectoralState(name: "Michigan", abbreviation: "MI", electoralVotes: 15, region: .midwest, isCoastal: false),
        ElectoralState(name: "New Jersey", abbreviation: "NJ", electoralVotes: 14, region: .northeast, isCoastal: true),
        ElectoralState(name: "Virginia", abbreviation: "VA", electoralVotes: 13, region: .south, isCoastal: true),
        ElectoralState(name: "Washington", abbreviation: "WA", electoralVotes: 12, region: .west, isCoastal: true),
        ElectoralState(name: "Arizona", abbreviation: "AZ", electoralVotes: 11, region: .west, isCoastal: false),
        ElectoralState(name: "Indiana", abbreviation: "IN", electoralVotes: 11, region: .midwest, isCoastal: false),
        ElectoralState(name: "Missouri", abbreviation: "MO", electoralVotes: 10, region: .midwest, isCoastal: false),
        ElectoralState(name: "Maryland", abbreviation: "MD", electoralVotes: 10, region: .northeast, isCoastal: true),
        ElectoralState(name: "Wisconsin", abbreviation: "WI", electoralVotes: 10, region: .midwest, isCoastal: false),
        ElectoralState(name: "Colorado", abbreviation: "CO", electoralVotes: 10, region: .west, isCoastal: false),
        ElectoralState(name: "Minnesota", abbreviation: "MN", electoralVotes: 10, region: .midwest, isCoastal: false),
        ElectoralState(name: "South Carolina", abbreviation: "SC", electoralVotes: 9, region: .south, isCoastal: true),
        ElectoralState(name: "Alabama", abbreviation: "AL", electoralVotes: 9, region: .south, isCoastal: false),
        ElectoralState(name: "Louisiana", abbreviation: "LA", electoralVotes: 8, region: .south, isCoastal: true),
        ElectoralState(name: "Kentucky", abbreviation: "KY", electoralVotes: 8, region: .south, isCoastal: false),
        ElectoralState(name: "Oregon", abbreviation: "OR", electoralVotes: 8, region: .west, isCoastal: true),
        ElectoralState(name: "Oklahoma", abbreviation: "OK", electoralVotes: 7, region: .south, isCoastal: false),
        ElectoralState(name: "Connecticut", abbreviation: "CT", electoralVotes: 7, region: .northeast, isCoastal: true),
        ElectoralState(name: "Utah", abbreviation: "UT", electoralVotes: 6, region: .west, isCoastal: false),
        ElectoralState(name: "Iowa", abbreviation: "IA", electoralVotes: 6, region: .midwest, isCoastal: false),
        ElectoralState(name: "Nevada", abbreviation: "NV", electoralVotes: 6, region: .west, isCoastal: false),
        ElectoralState(name: "Arkansas", abbreviation: "AR", electoralVotes: 6, region: .south, isCoastal: false),
        ElectoralState(name: "Mississippi", abbreviation: "MS", electoralVotes: 6, region: .south, isCoastal: false),
        ElectoralState(name: "Kansas", abbreviation: "KS", electoralVotes: 6, region: .midwest, isCoastal: false),
        ElectoralState(name: "New Mexico", abbreviation: "NM", electoralVotes: 5, region: .west, isCoastal: false),
        ElectoralState(name: "Nebraska", abbreviation: "NE", electoralVotes: 5, region: .midwest, isCoastal: false),
        ElectoralState(name: "Idaho", abbreviation: "ID", electoralVotes: 4, region: .west, isCoastal: false),
        ElectoralState(name: "West Virginia", abbreviation: "WV", electoralVotes: 4, region: .south, isCoastal: false),
        ElectoralState(name: "Hawaii", abbreviation: "HI", electoralVotes: 4, region: .west, isCoastal: true),
        ElectoralState(name: "Maine", abbreviation: "ME", electoralVotes: 4, region: .northeast, isCoastal: true),
        ElectoralState(name: "New Hampshire", abbreviation: "NH", electoralVotes: 4, region: .northeast, isCoastal: true),
        ElectoralState(name: "Rhode Island", abbreviation: "RI", electoralVotes: 4, region: .northeast, isCoastal: true),
        ElectoralState(name: "Montana", abbreviation: "MT", electoralVotes: 3, region: .west, isCoastal: false),
        ElectoralState(name: "Delaware", abbreviation: "DE", electoralVotes: 3, region: .northeast, isCoastal: true),
        ElectoralState(name: "South Dakota", abbreviation: "SD", electoralVotes: 3, region: .midwest, isCoastal: false),
        ElectoralState(name: "North Dakota", abbreviation: "ND", electoralVotes: 3, region: .midwest, isCoastal: false),
        ElectoralState(name: "Alaska", abbreviation: "AK", electoralVotes: 3, region: .west, isCoastal: true),
        ElectoralState(name: "Vermont", abbreviation: "VT", electoralVotes: 3, region: .northeast, isCoastal: false),
        ElectoralState(name: "Wyoming", abbreviation: "WY", electoralVotes: 3, region: .west, isCoastal: false),
        ElectoralState(name: "Washington DC", abbreviation: "DC", electoralVotes: 3, region: .northeast, isCoastal: false, isDC: true),
    ]

    var body: some View {
        VStack(spacing: 12) {
            // Header with counts
            HStack(spacing: 24) {
                VStack {
                    Text("\(playerEVs)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.playerAccent)
                    Text("Your EVs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("270 to win")
                    .font(.headline)
                    .foregroundColor(.secondary)

                VStack {
                    Text("\(opponentEVs)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.opponentAccent)
                    Text("Opponent EVs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("\(swingEVs) Tossup")
                        .font(.caption)
                        .foregroundColor(.tossupAccent)
                    Text("Swing State EVs")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            // State grid
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 70, maximum: 90), spacing: 6)
            ], spacing: 6) {
                ForEach(states) { state in
                    StateCell(state: state, standing: stateStanding(state))
                        .onTapGesture {
                            selectedState = state
                        }
                }
            }
            .padding(.horizontal)

            // Legend
            HStack(spacing: 16) {
                LegendItem(color: .playerAccent, label: "Leaning You")
                    .accessibilityIdentifier("electoral.legend.player")
                LegendItem(color: .opponentAccent, label: "Leaning Opponent")
                    .accessibilityIdentifier("electoral.legend.opponent")
                LegendItem(color: .tossupAccent, label: "Tossup")
                    .accessibilityIdentifier("electoral.legend.tossup")
                Spacer()
            }
            .font(.caption)
            .padding(.horizontal)
        }
        .sheet(item: $selectedState) { state in
            StateDetailView(state: state, standing: stateStanding(state))
                .environmentObject(engine)
        }
    }

    private var playerEVs: Int {
        states.filter { stateStanding($0) == .player }.reduce(0) { $0 + $1.electoralVotes }
    }

    private var opponentEVs: Int {
        states.filter { stateStanding($0) == .opponent }.reduce(0) { $0 + $1.electoralVotes }
    }

    private var swingEVs: Int {
        states.filter { stateStanding($0) == .tossup }.reduce(0) { $0 + $1.electoralVotes }
    }

    private func stateStanding(_ state: ElectoralState) -> StateStanding {
        let polling = engine.gameState.pollingData[state.abbreviation] ?? 50.0
        let margin = polling - 50.0

        if margin > 5 {
            return .player
        } else if margin < -5 {
            return .opponent
        } else {
            return .tossup
        }
    }
}

enum StateStanding {
    case player, opponent, tossup
}

struct ElectoralState: Identifiable {
    let id = UUID()
    let name: String
    let abbreviation: String
    let electoralVotes: Int
    let region: StateRegion
    let isCoastal: Bool
    var isDC: Bool = false
}

enum StateRegion {
    case northeast, south, midwest, west
}

struct StateCell: View {
    let state: ElectoralState
    let standing: StateStanding

    var body: some View {
        VStack(spacing: 2) {
            Text(state.abbreviation)
                .font(.caption2)
                .fontWeight(.bold)
            Text("\(state.electoralVotes)")
                .font(.caption2)
        }
        .frame(width: 50, height: 40)
        .background(standingColor.opacity(0.8))
        .foregroundColor(.white)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(standing == .tossup ? Color.tossupAccent : Color.clear, lineWidth: 2)
        )
        .accessibilityIdentifier("electoral.state.\(state.abbreviation)")
    }

    var standingColor: Color {
        switch standing {
        case .player: return .playerAccent
        case .opponent: return .opponentAccent
        case .tossup: return .tossupAccent
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

struct StateDetailView: View {
    let state: ElectoralState
    let standing: StateStanding
    @EnvironmentObject var engine: SimulationEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(state.name)
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") { dismiss() }
            }

            Divider()

            HStack(spacing: 24) {
                VStack {
                    Text("\(state.electoralVotes)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Electoral Votes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text(standingText)
                        .font(.headline)
                        .foregroundColor(standingColor)
                    Text("Current Standing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text("Polling: \(Int(engine.gameState.pollingData[state.abbreviation] ?? 50))%")
                .font(.subheadline)

            if standing == .tossup {
                Text("This is a swing state - a key battleground!")
                    .font(.caption)
                    .foregroundColor(.tossupAccent)
                    .padding()
                    .background(Color.tossupAccent.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .frame(width: 300, height: 250)
    }

    var standingText: String {
        switch standing {
        case .player: return "Leaning You"
        case .opponent: return "Leaning Opponent"
        case .tossup: return "Tossup"
        }
    }

    var standingColor: Color {
        switch standing {
        case .player: return .playerAccent
        case .opponent: return .opponentAccent
        case .tossup: return .tossupAccent
        }
    }
}

struct TransitionView: View {
    @EnvironmentObject var engine: SimulationEngine

    var body: some View {
        VStack(spacing: 16) {
            Text("Transition Period")
                .font(.title)

            Text("The election is won. For the next two months, you will prepare to take office.")
                .foregroundColor(.secondary)

            Text("Cabinet selections, policy priorities, and the smooth transfer of power await.")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct PresidencyView: View {
    @EnvironmentObject var engine: SimulationEngine

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Term \(engine.gameState.currentTerm)")
                        .font(.headline)
                    Text(engine.gameState.turnDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Bills Signed: \(engine.gameState.billsSigned)")
                        .font(.caption)
                    Text("Executive Orders: \(engine.gameState.executiveOrders)")
                        .font(.caption)
                }
            }

            EconomicDashboard()
        }
        .padding()
    }
}

struct ExitedView: View {
    @EnvironmentObject var engine: SimulationEngine
    @Binding var showNewGame: Bool

    var body: some View {
        VStack(spacing: 24) {
            Text("Your Presidency Has Ended")
                .font(.title)

            if let exitType = engine.gameState.exitType {
                Text(exitType.description)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            Text("Thank you for playing PresidentSim")
                .foregroundColor(.secondary)

            Button("Start New Game") {
                engine.startNewGame()
                showNewGame = true
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("exited.startNewGame")
        }
        .padding()
    }
}

// MARK: - Economic Dashboard

struct EconomicDashboard: View {
    @EnvironmentObject var engine: SimulationEngine

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 24) {
                EconomicIndicator(
                    label: "GDP Growth",
                    value: engine.gameState.world.gdpGrowth,
                    format: "%.1f%%",
                    isPositiveGood: true,
                    trend: engine.gameState.world.gdpGrowth > 2 ? 1 : -1
                )

                EconomicIndicator(
                    label: "Unemployment",
                    value: engine.gameState.world.unemployment,
                    format: "%.1f%%",
                    isPositiveGood: false,
                    trend: engine.gameState.world.unemployment < 5 ? -1 : 1
                )

                EconomicIndicator(
                    label: "Inflation",
                    value: engine.gameState.world.inflation,
                    format: "%.1f%%",
                    isPositiveGood: false,
                    trend: engine.gameState.world.inflation > 3 ? 1 : -1
                )

                EconomicIndicator(
                    label: "Consumer Conf.",
                    value: engine.gameState.world.consumerConfidence,
                    format: "%.0f",
                    isPositiveGood: true
                )
            }

            Divider()

            HStack(spacing: 24) {
                EconomicIndicator(
                    label: "Stock Market",
                    value: engine.gameState.world.stockMarketIndex,
                    format: "%.0f",
                    isPositiveGood: true,
                    trend: engine.gameState.world.stockMarketIndex > 100 ? 1 : -1
                )

                EconomicIndicator(
                    label: "National Debt",
                    value: engine.gameState.world.nationalDebt,
                    format: "$%.1fT",
                    isPositiveGood: true,
                    trend: engine.gameState.world.nationalDebt > 25 ? 1 : -1
                )

                Spacer()

                // Economic sentiment
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Economic Sentiment")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(economicSentiment)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(economicSentimentColor)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    var economicSentiment: String {
        let health = computeEconomicHealth()
        if health > 60 { return "Booming" }
        if health > 45 { return "Growing" }
        if health > 30 { return "Stagnant" }
        if health > 15 { return "Slowing" }
        return "Recession"
    }

    var economicSentimentColor: Color {
        let health = computeEconomicHealth()
        if health > 60 { return .green }
        if health > 45 { return .blue }
        if health > 30 { return .orange }
        return .red
    }

    func computeEconomicHealth() -> Double {
        var health = 50.0
        if engine.gameState.world.gdpGrowth > 2 { health += 15 }
        if engine.gameState.world.gdpGrowth < 0 { health -= 20 }
        if engine.gameState.world.unemployment < 5 { health += 10 }
        if engine.gameState.world.unemployment > 8 { health -= 15 }
        if engine.gameState.world.inflation < 3 { health += 10 }
        if engine.gameState.world.inflation > 6 { health -= 15 }
        if engine.gameState.world.consumerConfidence > 70 { health += 10 }
        if engine.gameState.world.stockMarketIndex > 105 { health += 5 }
        return max(0, min(100, health))
    }
}

struct EconomicIndicator: View {
    let label: String
    let value: Double
    let format: String
    let isPositiveGood: Bool
    var trend: Double = 0

    var isGood: Bool {
        if isPositiveGood {
            return value > 0
        } else {
            return value < 5
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .help(tooltip)

            HStack(spacing: 4) {
                Text(String(format: format, value))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isGood ? .primary : .danger)

                if trend != 0 {
                    let goodTrend: Bool = isPositiveGood ? trend > 0 : trend < 0
                    Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                        .foregroundColor(goodTrend ? .positive : .danger)
                }
            }
        }
        .frame(minWidth: 80)
    }

    private var tooltip: String {
        switch label {
        case "GDP Growth": return "GDP Growth: Annual percentage change in Gross Domestic Product. Above 2% indicates a healthy economy. Negative growth signals recession."
        case "Unemployment": return "Unemployment: Percentage of the workforce seeking a job. Below 5% is full employment. Above 8% is a serious recession."
        case "Inflation": return "Inflation: Annual price increase rate. 2-3% is healthy. Above 6% causes political damage. Above 10% is a crisis."
        case "Consumer Conf.": return "Consumer Confidence: Index measuring public optimism about the economy. Above 70 is strong. Below 50 signals recession."
        case "Stock Market": return "Stock Market: Indexed value of major exchanges. Reflects investor confidence in future economic conditions."
        case "National Debt": return "National Debt: Total federal borrowing in trillions. High debt limits future fiscal flexibility."
        default: return label
        }
    }
}

// MARK: - News Ticker

struct NewsTickerView: View {
    let text: String
    let trendingTopic: String
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Text("LIVE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.danger)
                    .cornerRadius(2)

                Text(text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text("  •  ")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(trendingTopic)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .offset(x: offset)
            .onAppear {
                let fullWidth = (text.count + trendingTopic.count) * 7
                withAnimation(.linear(duration: Double(fullWidth) / 30).repeatForever(autoreverses: false)) {
                    offset = -CGFloat(fullWidth + 100)
                }
            }
        }
        .frame(height: 28)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

// MARK: - Event Detail View

struct EventDetailView: View {
    let event: GameEvent
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(event.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        if event.isAIGenerated {
                            Text("AI")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.special)
                                .cornerRadius(4)
                        }
                    }

                    HStack {
                        Text(event.category.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text("Turn \(event.turnOccurred)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            Divider()

            Text(event.description)
                .font(.body)

            if event.isResolved {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RESOLVED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.positive)

                    Text(event.resolution ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.positive.opacity(0.1))
                .cornerRadius(8)
            }

            if !event.consequences.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Consequences")
                        .font(.headline)

                    ForEach(event.consequences, id: \.affectedArea) { consequence in
                        HStack {
                            Image(systemName: consequence.delta >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .foregroundColor(consequence.delta >= 0 ? .positive : .danger)

                            Text(consequence.affectedArea)
                                .font(.subheadline)

                            Spacer()

                            Text(consequence.delta >= 0 ? "+\(String(format: "%.1f", consequence.delta))" : "\(String(format: "%.1f", consequence.delta))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(consequence.delta >= 0 ? .positive : .danger)
                        }

                        Text(consequence.narrative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 450, height: 400)
    }
}

// MARK: - New Game View

struct NewGameView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var engine: SimulationEngine

    @State private var candidateName = ""
    @State private var selectedParty: PoliticalParty = .democrat
    @State private var homeState = "California"
    @State private var occupation = "Governor"
    @State private var useAI = true

    let states = ["California", "Texas", "Florida", "New York", "Illinois", "Pennsylvania",
                  "Ohio", "Georgia", "North Carolina", "Michigan", "Arizona", "Wisconsin"]
    let occupations = ["Governor", "Senator", "Mayor", "Business Executive", "General"]

    var body: some View {
        VStack(spacing: 20) {
            Text("New Game")
                .font(.title)

            Form {
                TextField("Candidate Name", text: $candidateName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("newGame.name")

                Picker("Party", selection: $selectedParty) {
                    ForEach(PoliticalParty.allCases, id: \.self) { party in
                        Text(party.rawValue).tag(party)
                    }
                }
                .accessibilityIdentifier("newGame.party")

                Picker("Home State", selection: $homeState) {
                    ForEach(states, id: \.self) { state in
                        Text(state).tag(state)
                    }
                }
                .accessibilityIdentifier("newGame.homeState")

                Picker("Prior Experience", selection: $occupation) {
                    ForEach(occupations, id: \.self) { occ in
                        Text(occ).tag(occ)
                    }
                }
                .accessibilityIdentifier("newGame.occupation")

                Toggle("Use AI for consequence calculation", isOn: $useAI)
                    .disabled(engine.aiBrain == nil)
                    .accessibilityIdentifier("newGame.useAI")
            }
            .frame(width: 300)

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("newGame.cancel")

                Button("Start Game") {
                    startGame()
                }
                .buttonStyle(.borderedProminent)
                .disabled(candidateName.isEmpty)
                .accessibilityIdentifier("newGame.start")
            }
        }
        .padding(30)
    }

    private func startGame() {
        let player = Player(
            name: candidateName,
            party: selectedParty,
            age: 50,
            health: 0.9,
            charisma: Double.random(in: 4...8),
            intelligence: Double.random(in: 5...9),
            willpower: Double.random(in: 4...8),
            luck: Double.random(in: 3...7),
            homeState: homeState,
            occupation: occupation,
            priorExperience: [occupation]
        )

        engine.startNewGame(player: player)
        isPresented = false
    }
}

// MARK: - Command Center View

struct CommandCenterView: View {
    @EnvironmentObject var engine: SimulationEngine
    @Environment(\.dismiss) var dismiss
    @State private var selectedCategory: ActionCategory?

    // Speech editing state
    @State private var isEditingSpeech = false
    @State private var speechText = ""
    @State private var isGeneratingSpeech = false
    @State private var selectedSpeechType = "campaign"
    @State private var selectedTone = "soaring"

    private let speechTypes = ["campaign", "inaugural", "state_of_union", "crisis", "press_conference"]
    private let speechTones = ["soaring", "solemn", "urgent", "reassuring"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Command Center")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Resources bar
            HStack(spacing: 20) {
                ResourcePill(icon: "banknote", label: "Political Capital", value: "\(Int(engine.gameState.resources.politicalCapital))", color: .playerAccent)
                ResourcePill(icon: "dollarsign.circle", label: "Campaign Funds", value: "$\(formatMoney(Double(engine.gameState.resources.campaignFunds)))", color: .positive)
                ResourcePill(icon: "tv", label: "Media Cycles", value: "\(engine.gameState.resources.mediaCycles)", color: .special)

                Spacer()

                // Momentum
                HStack(spacing: 4) {
                    Image(systemName: engine.gameState.campaignMomentum >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        .foregroundColor(engine.gameState.campaignMomentum >= 0 ? .positive : .danger)
                    Text("Momentum: \(String(format: "%.1f", engine.gameState.campaignMomentum))")
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Category tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ActionCategory.allCases, id: \.self) { category in
                        CategoryTab(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            // Actions list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredActions) { action in
                        ActionCard(
                            action: action,
                            isDisabled: !isActionAvailable(action),
                            cooldownRemaining: cooldownRemaining(for: action)
                        ) {
                            performAction(action)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
        .sheet(isPresented: $isEditingSpeech) {
            SpeechEditorSheet(
                speechText: $speechText,
                selectedSpeechType: $selectedSpeechType,
                selectedTone: $selectedTone,
                speechTypes: speechTypes,
                speechTones: speechTones,
                isGenerating: isGeneratingSpeech,
                onDeliver: {
                    // Costs and effects already applied when action was selected
                    SpeechService.shared.speakDraftSpeech(speechText)
                    engine.gameState.world.actionResultsThisTurn.append("You delivered a \(selectedSpeechType.replacingOccurrences(of: "_", with: " ")) speech.")
                    isEditingSpeech = false
                },
                onGenerate: {
                    generateAISpeech()
                },
                onCancel: {
                    // Costs already deducted when action was selected — no refund
                    isEditingSpeech = false
                }
            )
        }
    }

    private var filteredActions: [GameAction] {
        let available = ActionRegistry.actionsFor(phase: engine.gameState.phase)
        if let category = selectedCategory {
            return available.filter { $0.category == category }
        }
        return available
    }

    private func performAction(_ action: GameAction) {
        // Guard: check if action can be performed
        if !engine.canPerformAction(action) {
            if engine.cooldownRemaining(for: action) > 0 {
                engine.gameState.world.actionResultsThisTurn.append("\(action.name) is on cooldown.")
            }
            return
        }

        // Let engine handle cost deduction, effects, and cooldown
        engine.performAction(action)

        // Special case: "Make Speech" opens the editor
        if action.name == "Make Speech" {
            speechText = "My fellow Americans, we stand at a pivotal moment in our nation's history. Together, we will build a stronger economy, unite our people, and secure a brighter future for generations to come."
            isEditingSpeech = true
        }
    }

    private func isActionAvailable(_ action: GameAction) -> Bool {
        engine.canPerformAction(action)
    }

    private func cooldownRemaining(for action: GameAction) -> Int {
        engine.cooldownRemaining(for: action)
    }

    private func generateAISpeech() {
        guard let aiBrain = engine.aiBrain else {
            speechText = "AI brain not available. Please enter your speech manually."
            return
        }

        isGeneratingSpeech = true
        speechText = ""

        let gameSummary = engine.gameState.toAISummary()
        let input = MiniMaxService.SpeechInput(
            speechType: selectedSpeechType,
            gameState: gameSummary,
            topic: engine.gameState.world.trendingTopic.isEmpty ? "the state of the nation" : engine.gameState.world.trendingTopic,
            tone: selectedTone
        )

        Task {
            do {
                let output = try await aiBrain.generateSpeech(input: input)
                await MainActor.run {
                    self.speechText = output.draftSpeech
                    self.isGeneratingSpeech = false
                }
            } catch {
                await MainActor.run {
                    self.speechText = "Failed to generate speech: \(error.localizedDescription)\n\nPlease enter your speech manually."
                    self.isGeneratingSpeech = false
                }
            }
        }
    }

    private func formatMoney(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return String(format: "%.1fM", amount / 1_000_000)
        } else if amount >= 1_000 {
            return String(format: "%.0fK", amount / 1_000)
        }
        return String(format: "%.0f", amount)
    }
}

struct ResourcePill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .help(resourceTooltip)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    private var resourceTooltip: String {
        switch label {
        case "Political Capital": return "Political Capital: The currency of governance. Used for major actions. Regenerates over time."
        case "Campaign Funds": return "Campaign Funds: Money available for campaign activities. Raised through donors and events. Spent on rallies, ads, and travel."
        case "Media Cycles": return "Media Cycles: Number of news cycles you can dominate. Each major action consumes a cycle. Refreshes weekly."
        default: return label
        }
    }
}

struct CategoryTab: View {
    let category: ActionCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: categoryIcon)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .help(categoryTooltip)
    }

    private var categoryIcon: String {
        switch category {
        case .communication: return "mic.fill"
        case .travel: return "airplane"
        case .diplomatic: return "globe"
        case .executive: return "building.columns.fill"
        case .political: return "person.3.fill"
        case .personnel: return "person.badge.key.fill"
        }
    }

    private var categoryTooltip: String {
        switch category {
        case .communication: return "Communication: Speeches, interviews, press conferences, and statements. Shapes media narrative and public opinion."
        case .travel: return "Travel: Campaign rallies, swing state visits, and diplomatic trips. Builds momentum and visibility."
        case .diplomatic: return "Diplomatic: Meetings with foreign leaders, state dinners, and summits. Affects international relationships."
        case .executive: return "Executive: Orders, vetoes, legislation signing. High-impact presidential powers but use sparingly."
        case .political: return "Political: Fundraising, negotiations, and base rallying. Essential for campaign and governing."
        case .personnel: return "Personnel: Cabinet meetings, advisor consultations, and staffing decisions. Shapes your administration."
        }
    }
}

// MARK: - Speech Editor Sheet

struct SpeechEditorSheet: View {
    @Binding var speechText: String
    @Binding var selectedSpeechType: String
    @Binding var selectedTone: String
    let speechTypes: [String]
    let speechTones: [String]
    let isGenerating: Bool
    let onDeliver: () -> Void
    let onGenerate: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Compose Speech")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Speech type and tone pickers
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Speech Type")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("", selection: $selectedSpeechType) {
                                ForEach(speechTypes, id: \.self) { type in
                                    Text(type.replacingOccurrences(of: "_", with: " ").capitalized).tag(type)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tone")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("", selection: $selectedTone) {
                                ForEach(speechTones, id: \.self) { tone in
                                    Text(tone.capitalized).tag(tone)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 140)
                        }

                        Button(action: onGenerate) {
                            HStack {
                                if isGenerating {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .fixedSize()
                                } else {
                                    Image(systemName: "wand.and.stars")
                                }
                                Text(isGenerating ? "Generating..." : "AI Generate")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isGenerating)

                        Spacer()
                    }

                    // Speech text editor
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speech Text")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if isGenerating && speechText.isEmpty {
                            HStack {
                                ProgressView()
                                Text("Generating your speech with AI...")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        } else {
                            TextEditor(text: $speechText)
                                .font(.body)
                                .frame(minHeight: 200)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Action buttons
            HStack {
                Text("\(speechText.split(separator: " ").count) words")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Deliver Speech") {
                    onDeliver()
                }
                .buttonStyle(.borderedProminent)
                .disabled(speechText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 580, height: 480)
    }
}

struct ActionCard: View {
    let action: GameAction
    let isDisabled: Bool
    let cooldownRemaining: Int
    let onPerform: () -> Void
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor((isDisabled || isLoading) ? .secondary : .primary)

                    Text(action.category.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action.name == "Make Speech" ? "Write Speech" : "Perform") {
                    guard !isLoading else { return }
                    isLoading = true
                    onPerform()
                    // Brief guard period to prevent double-tap
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isLoading = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isDisabled || isLoading)
            }

            Text(action.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            // Costs
            HStack(spacing: 8) {
                ForEach(action.costs, id: \.type) { cost in
                    HStack(spacing: 2) {
                        Image(systemName: costIcon(cost.type))
                            .font(.caption2)
                        Text("\(Int(cost.amount))")
                            .font(.caption2)
                    }
                    .foregroundColor(.tossupAccent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.tossupAccent.opacity(0.1))
                    .cornerRadius(4)
                    .help(costTooltip(cost.type))
                }

                Spacer()

                if cooldownRemaining > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(cooldownRemaining) turn\(cooldownRemaining == 1 ? "" : "s") left")
                            .font(.caption2)
                    }
                    .foregroundColor(.unreadBadge)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.dangerBackground)
                    .cornerRadius(4)
                    .help("This action is on cooldown and cannot be used again for \(cooldownRemaining) more turn\(cooldownRemaining == 1 ? "" : "s").")
                } else if action.cooldown > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(action.cooldown) turn cooldown")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    .help("Using this action will put it on cooldown for \(action.cooldown) turn\(action.cooldown == 1 ? "" : "s").")
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .opacity(isDisabled ? 0.6 : 1.0)
        .accessibilityIdentifier("action.\(action.name.replacingOccurrences(of: " ", with: "_").lowercased())")
    }

    private func costIcon(_ type: ActionCostType) -> String {
        switch type {
        case .politicalCapital: return "banknote"
        case .time: return "clock"
        case .money: return "dollarsign.circle"
        case .mediaCycle: return "tv"
        }
    }

    private func costTooltip(_ type: ActionCostType) -> String {
        switch type {
        case .politicalCapital: return "Political Capital: The main resource for governing actions. Regenerates over time."
        case .time: return "Time: How many weekly turns this action consumes. Time is limited each week."
        case .money: return "Campaign Funds: Money spent on this action. Fundraising can replenish it."
        case .mediaCycle: return "Media Cycle: News cycle attention. Limited per week. High-value actions consume cycles."
        }
    }
}

// MARK: - Briefings View

struct BriefingsView: View {
    @EnvironmentObject var engine: SimulationEngine
    @Environment(\.dismiss) var dismiss
    @State private var selectedBriefing: Briefing?

    private var briefings: [Briefing] {
        engine.gameState.briefings
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Presidential Briefings")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if briefings.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Briefings")
                        .font(.headline)
                    Text("Your intelligence team has no urgent items at this time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Briefings list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(briefings) { briefing in
                            BriefingCard(briefing: briefing) {
                                selectedBriefing = briefing
                                engine.markBriefingAsRead(briefing.id)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 500, height: 450)
        .sheet(item: $selectedBriefing) { briefing in
            BriefingDetailView(briefing: briefing) { selectedIndex in
                engine.resolveBriefing(briefing.id, selectedOption: selectedIndex)
                selectedBriefing = nil
            }
        }
    }
}

struct BriefingCard: View {
    let briefing: Briefing
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Urgency indicator
                Circle()
                    .fill(urgencyColor)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(briefing.title)
                            .font(.subheadline)
                            .fontWeight(briefing.isRead ? .regular : .semibold)
                            .foregroundColor(.primary)

                        if briefing.requiresResponse {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.tossupAccent)
                                .font(.caption)
                        }
                    }

                    Text(briefing.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    HStack {
                        Text(briefing.type.rawValue)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)

                        if let deadline = briefing.deadline {
                            Text("Due: Turn \(deadline)")
                                .font(.caption2)
                                .foregroundColor(.tossupAccent)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(12)
            .background(briefing.isResolved ? Color.positive.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var urgencyColor: Color {
        switch briefing.urgency {
        case 5: return .red
        case 4: return .orange
        case 3: return .yellow
        default: return .green
        }
    }
}

// MARK: - Save/Load View
struct SaveLoadView: View {
    @ObservedObject var engine: SimulationEngine
    @Environment(\.dismiss) var dismiss
    @State private var saves: [SaveMetadata] = []
    @State private var showLoadError = false
    @State private var loadErrorMessage = ""
    @State private var saveName = ""
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Save / Load Game")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            TabView {
                // Save Tab
                VStack(alignment: .leading, spacing: 16) {
                    Text("Save Current Game")
                        .font(.headline)

                    TextField("Save name (optional)", text: $saveName)
                        .textFieldStyle(.roundedBorder)

                    Button(action: saveGame) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text(isSaving ? "Saving..." : "Save Game")
                        }
                    }
                    .disabled(isSaving)

                    Spacer()
                }
                .padding()
                .tabItem { Label("Save", systemImage: "square.and.arrow.down") }

                // Load Tab
                VStack(alignment: .leading, spacing: 16) {
                    Text("Load Saved Game")
                        .font(.headline)

                    if saves.isEmpty {
                        VStack {
                            Spacer()
                            Text("No saved games found")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        List(saves, id: \.filename) { save in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(save.displayName)
                                        .fontWeight(.medium)
                                    Text(save.formattedDate)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Load") {
                                    loadGame(save.filename)
                                }
                                Button(role: .destructive) {
                                    deleteSave(save.filename)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
                .tabItem { Label("Load", systemImage: "square.and.arrow.up") }
            }
            .padding()
        }
        .frame(width: 450, height: 400)
        .onAppear {
            refreshSaves()
        }
        .alert("Load Error", isPresented: $showLoadError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(loadErrorMessage)
        }
    }

    private func saveGame() {
        isSaving = true
        let name = saveName.isEmpty ? nil : saveName
        do {
            try engine.saveGameAs(name ?? "autosave")
            saveName = ""
            refreshSaves()
        } catch {
            loadErrorMessage = "Failed to save: \(error.localizedDescription)"
        }
        isSaving = false
    }

    private func loadGame(_ filename: String) {
        do {
            try engine.loadGame(filename)
            dismiss()
        } catch {
            loadErrorMessage = "Failed to load: \(error.localizedDescription)"
            showLoadError = true
        }
    }

    private func deleteSave(_ filename: String) {
        do {
            try engine.deleteSave(filename)
            refreshSaves()
        } catch {
            loadErrorMessage = "Failed to delete: \(error.localizedDescription)"
            showLoadError = true
        }
    }

    private func refreshSaves() {
        saves = engine.listSavedGames()
    }
}

struct BriefingDetailView: View {
    let briefing: Briefing
    let onRespond: (Int) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(briefing.title)
                        .font(.title3)
                        .fontWeight(.bold)

                    HStack {
                        Text(briefing.type.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("Urgency: \(briefing.urgency)/5")
                            .font(.caption)
                            .foregroundColor(urgencyColor)
                    }
                }

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            Divider()

            Text(briefing.summary)
                .font(.body)

            if briefing.isResolved {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.positive)
                    Text("Resolved")
                        .font(.caption)
                        .foregroundColor(.positive)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.positive.opacity(0.1))
                .cornerRadius(8)
            } else if !briefing.options.isEmpty {
                Divider()

                Text("Your Options")
                    .font(.headline)

                ForEach(Array(briefing.options.enumerated()), id: \.element.id) { index, option in
                    Button(action: {
                        onRespond(index)
                        dismiss()
                    }) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text(option.label)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                            }

                            if !option.description.isEmpty {
                                Text(option.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 22)
                            }

                            if !option.pros.isEmpty || !option.cons.isEmpty {
                                HStack(alignment: .top, spacing: 12) {
                                    if !option.pros.isEmpty {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 2) {
                                                Image(systemName: "plus.circle.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(.positive)
                                                Text("Pros")
                                                    .font(.caption2)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.positive)
                                            }
                                            ForEach(option.pros, id: \.self) { pro in
                                                Text("• \(pro)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                    .padding(.leading, 14)
                                            }
                                        }
                                    }

                                    if !option.cons.isEmpty {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 2) {
                                                Image(systemName: "minus.circle.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(.unreadBadge)
                                                Text("Cons")
                                                    .font(.caption2)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.unreadBadge)
                                            }
                                            ForEach(option.cons, id: \.self) { con in
                                                Text("• \(con)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                    .padding(.leading, 14)
                                            }
                                        }
                                    }
                                }
                                .padding(.leading, 22)
                            }
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 400, height: 350)
    }

    private var urgencyColor: Color {
        switch briefing.urgency {
        case 5: return .red
        case 4: return .orange
        case 3: return .yellow
        default: return .green
        }
    }
}
