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
    @State private var briefings: [Briefing] = []

    var body: some View {
        VStack(spacing: 0) {
            // News ticker
            if !newsTickerText.isEmpty {
                NewsTickerView(text: newsTickerText)
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
                    .foregroundColor(showCommandCenter ? .orange : .blue)

                    Divider().frame(height: 16)

                    Button(action: { showBriefings.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "tray.fill")
                            Text("Briefings")
                            if unreadBriefingsCount > 0 {
                                Text("(\(unreadBriefingsCount))")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(showBriefings ? .orange : .blue)

                    Divider().frame(height: 16)

                    Button(action: { showSaveLoad.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down.on.square")
                            Text("Save/Load")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(showSaveLoad ? .orange : .blue)
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
                .foregroundColor(.blue)

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
                GameMainView()

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
            BriefingsView(briefings: $briefings)
                .environmentObject(engine)
        }
        .sheet(isPresented: $showSaveLoad) {
            SaveLoadView(engine: engine)
        }
        .onAppear {
            loadAPIKeyIfNeeded()
            updateNewsTicker()
        }
        .onChange(of: engine.gameState.world.currentNarrative) { _, _ in
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
                            .foregroundColor(.orange)
                        Text("Decision Required")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(true)
                .opacity(0.7)
            } else if engine.gameState.phase == .preCampaign && engine.gameState.player.name != "Player" {
                Button("Announce Candidacy") {
                    Task {
                        await engine.declareCandidacy()
                    }
                }
                .buttonStyle(.borderedProminent)
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
            }
        }
    }

    private func updateNewsTicker() {
        let narrative = engine.gameState.world.currentNarrative
        let recentEvents = engine.gameState.activeEvents.prefix(2)
        var tickerParts: [String] = []

        if !narrative.isEmpty && narrative != "Your journey awaits..." {
            tickerParts.append(narrative)
        }

        for event in recentEvents {
            tickerParts.append("[\(event.category.rawValue)] \(event.title): \(event.description)")
        }

        newsTickerText = tickerParts.joined(separator: " • ")
    }

    private func loadAPIKeyIfNeeded() {
        if let envPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("GitRepos/Overlord-v2/.env").path as String?,
           let content = try? String(contentsOfFile: envPath),
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

        let briefingTemplates: [BriefingType: [(String, String, [String])]] = [
            .campaign: [
                ("Polling Results", "New internal polling shows movement in key states.", ["Review data", "Adjust strategy", "Ignore"]),
            ],
            .legislative: [
                ("Congressional Interest", "Bipartisan group wants to meet about shared priorities.", ["Meet with them", "Send aide", "Decline"]),
            ],
            .diplomatic: [
                ("Foreign Policy Update", "Allies are seeking clarity on your administration's stance.", ["Schedule call", "Send statement", "Defer"]),
            ],
            .media: [
                ("Interview Request", "Major network requests exclusive interview.", ["Accept", "Decline", "Offer surrogate"]),
            ],
            .administrative: [
                ("Transition Update", "Transition team reports on preparation progress.", ["Review report", "Schedule briefing", "Delegate"]),
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
                responseOptions: template.2
            )
            briefings.insert(newBriefing, at: 0)
            // Keep max 20 briefings
            if briefings.count > 20 {
                briefings.removeLast()
            }
        }
    }

    private var unreadBriefingsCount: Int {
        briefings.filter { !$0.isRead }.count
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
                        CandidateStatBar(label: "Charisma", value: engine.gameState.player.charisma, max: 10, color: .orange)
                        CandidateStatBar(label: "Intelligence", value: engine.gameState.player.intelligence, max: 10, color: .blue)
                        CandidateStatBar(label: "Willpower", value: engine.gameState.player.willpower, max: 10, color: .purple)
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
                            StatRow(label: "Congressional Support", value: engine.gameState.world.congressionalSupport, max: 100, color: .blue)
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
                                MomentumIndicator(momentum: engine.gameState.campaignMomentum)
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
                                        .tint(engine.gameState.electoralVotes >= 270 ? .green : .orange)

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
        case .democrat: return .blue
        case .republican: return .red
        case .independent: return .purple
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
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
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
                        .foregroundColor(change >= 0 ? .green : .red)
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
                    .foregroundColor(.yellow)
                Text("Political Capital")
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
                    .foregroundColor(.blue)
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
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                                .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Current Situation")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(engine.gameState.world.currentNarrative)
                                    .font(.caption)
                                    .foregroundColor(.primary)
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
                        ForEach(Array(entry.effects.prefix(2)), id: \.key) { effect in
                            Text("\(effect.key): \(effect.value >= 0 ? "+" : "")\(Int(effect.value))")
                                .font(.caption2)
                                .foregroundColor(effect.value >= 0 ? .green : .red)
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
        case .preCampaign, .campaign: return .blue
        case .primaries: return .purple
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
    @State private var selectedIndex: Int? = nil

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
                    selectedIndex = index
                    Task {
                        await engine.makeDecision(decision, choiceIndex: index)
                    }
                }) {
                    HStack {
                        Text(option.text)
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                        if option.isRisky {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.caption2)
                        }
                    }
                    .padding(6)
                    .background(selectedIndex == index ? Color.accentColor.opacity(0.3) : Color.clear)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
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

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(event.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(event.isResolved ? .secondary : .primary)

                        if event.isResolved {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else if event.isAIGenerated {
                            Text("AI")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.purple)
                                .cornerRadius(3)
                        }
                    }

                    Text(event.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
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
                .fill(event.isResolved ? Color.green.opacity(0.08) : Color(NSColor.controlBackgroundColor))
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
        case .economic: return .green
        case .political: return .blue
        case .international: return .purple
        case .social: return .orange
        case .crisis: return .red
        case .scandal: return .pink
        case .achievement: return .yellow
        case .personal: return .gray
        }
    }
}

// MARK: - Game Main View

struct GameMainView: View {
    @EnvironmentObject var engine: SimulationEngine

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
                ExitedView()
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
                                    .foregroundColor(.green)
                                    .font(.caption)
                            } else if opponent.momentum < 0 {
                                Image(systemName: "arrow.down")
                                    .foregroundColor(.red)
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
                        .foregroundColor(.blue)
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
                        .foregroundColor(.red)
                    Text("Opponent EVs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("\(swingEVs) Tossup")
                        .font(.caption)
                        .foregroundColor(.orange)
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
                LegendItem(color: .blue, label: "Leaning You")
                LegendItem(color: .red, label: "Leaning Opponent")
                LegendItem(color: .yellow, label: "Tossup")
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
                .stroke(standing == .tossup ? Color.orange : Color.clear, lineWidth: 2)
        )
    }

    var standingColor: Color {
        switch standing {
        case .player: return .blue
        case .opponent: return .red
        case .tossup: return .yellow
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
                    .foregroundColor(.orange)
                    .padding()
                    .background(Color.orange.opacity(0.1))
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
        case .player: return .blue
        case .opponent: return .red
        case .tossup: return .orange
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
                // Would trigger new game
            }
            .buttonStyle(.borderedProminent)
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

            HStack(spacing: 4) {
                Text(String(format: format, value))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isGood ? .primary : .red)

                if trend != 0 {
                    let goodTrend: Bool = isPositiveGood ? trend > 0 : trend < 0
                    Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                        .foregroundColor(goodTrend ? .green : .red)
                }
            }
        }
        .frame(minWidth: 80)
    }
}

// MARK: - News Ticker

struct NewsTickerView: View {
    let text: String
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
                    .background(Color.red)
                    .cornerRadius(2)

                Text(text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text("  •  " + text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .offset(x: offset)
            .onAppear {
                let textWidth = text.count * 7
                withAnimation(.linear(duration: Double(textWidth) / 30).repeatForever(autoreverses: false)) {
                    offset = -CGFloat(textWidth + 100)
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
                                .background(Color.purple)
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
                        .foregroundColor(.green)

                    Text(event.resolution ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }

            if !event.consequences.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Consequences")
                        .font(.headline)

                    ForEach(event.consequences, id: \.affectedArea) { consequence in
                        HStack {
                            Image(systemName: consequence.delta >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .foregroundColor(consequence.delta >= 0 ? .green : .red)

                            Text(consequence.affectedArea)
                                .font(.subheadline)

                            Spacer()

                            Text(consequence.delta >= 0 ? "+\(String(format: "%.1f", consequence.delta))" : "\(String(format: "%.1f", consequence.delta))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(consequence.delta >= 0 ? .green : .red)
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

                Picker("Party", selection: $selectedParty) {
                    ForEach(PoliticalParty.allCases, id: \.self) { party in
                        Text(party.rawValue).tag(party)
                    }
                }

                Picker("Home State", selection: $homeState) {
                    ForEach(states, id: \.self) { state in
                        Text(state).tag(state)
                    }
                }

                Picker("Prior Experience", selection: $occupation) {
                    ForEach(occupations, id: \.self) { occ in
                        Text(occ).tag(occ)
                    }
                }

                Toggle("Use AI for consequence calculation", isOn: $useAI)
                    .disabled(engine.aiBrain == nil)
            }
            .frame(width: 300)

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Button("Start Game") {
                    startGame()
                }
                .buttonStyle(.borderedProminent)
                .disabled(candidateName.isEmpty)
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
                ResourcePill(icon: "banknote", label: "Political Capital", value: "\(Int(engine.gameState.resources.politicalCapital))", color: .blue)
                ResourcePill(icon: "dollarsign.circle", label: "Campaign Funds", value: "$\(formatMoney(Double(engine.gameState.resources.campaignFunds)))", color: .green)
                ResourcePill(icon: "tv", label: "Media Cycles", value: "\(engine.gameState.resources.mediaCycles)", color: .purple)

                Spacer()

                // Momentum
                HStack(spacing: 4) {
                    Image(systemName: engine.gameState.campaignMomentum >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        .foregroundColor(engine.gameState.campaignMomentum >= 0 ? .green : .red)
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
                        ActionCard(action: action) {
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
                    engine.gameState.world.currentNarrative = "You delivered a \(selectedSpeechType.replacingOccurrences(of: "_", with: " ")) speech."
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
        // Validate resource costs first
        for cost in action.costs {
            switch cost.type {
            case .politicalCapital:
                if engine.gameState.resources.politicalCapital < cost.amount {
                    engine.gameState.world.currentNarrative = "Not enough Political Capital for: \(action.name)"
                    return
                }
            case .money:
                if engine.gameState.resources.campaignFunds < cost.amount {
                    engine.gameState.world.currentNarrative = "Not enough Campaign Funds for: \(action.name)"
                    return
                }
            case .mediaCycle:
                if engine.gameState.resources.mediaCycles < Int(cost.amount) {
                    engine.gameState.world.currentNarrative = "Not enough Media Cycles for: \(action.name)"
                    return
                }
            case .time:
                break // Time is just turns, always available
            }
        }

        // Deduct costs
        for cost in action.costs {
            switch cost.type {
            case .politicalCapital:
                engine.gameState.resources.politicalCapital -= cost.amount
            case .money:
                engine.gameState.resources.campaignFunds -= cost.amount
            case .mediaCycle:
                engine.gameState.resources.mediaCycles -= Int(cost.amount)
            case .time:
                break
            }
        }

        // Apply action effects (clamped to valid ranges)
        for (key, value) in action.effects {
            switch key {
            case "mediaFavorability":
                engine.gameState.world.mediaFavorability = max(0, min(100, engine.gameState.world.mediaFavorability + value))
            case "approvalRating":
                engine.gameState.world.approvalRating = max(0, min(100, engine.gameState.world.approvalRating + value))
            case "momentum":
                engine.gameState.campaignMomentum = max(-10, min(10, engine.gameState.campaignMomentum + value))
            case "congressionalSupport":
                engine.gameState.world.congressionalSupport = max(0, min(100, engine.gameState.world.congressionalSupport + value))
            case "partyUnityScore":
                engine.gameState.world.partyUnityScore = max(0, min(100, engine.gameState.world.partyUnityScore + value))
            case "campaignFunds":
                engine.gameState.resources.campaignFunds = max(0, engine.gameState.resources.campaignFunds + value)
            case "globalInfluence":
                engine.gameState.world.globalInfluence = max(0, min(100, engine.gameState.world.globalInfluence + value))
            case "statePolling":
                engine.gameState.popularVoteMargin = max(-20, min(20, engine.gameState.popularVoteMargin + value))
            case "opponentPolling":
                engine.gameState.opponentPolling = max(0, min(100, engine.gameState.opponentPolling + value))
            case "cabinetSatisfaction":
                engine.gameState.cabinetSatisfaction = max(0, min(100, engine.gameState.cabinetSatisfaction + value))
            case "relationshipTarget":
                // relationshipTarget is handled per-country in diplomatic actions; generic fallback here
                break
            default:
                break
            }
        }

        // Show brief feedback
        engine.gameState.world.currentNarrative = "You used: \(action.name)"

        // For "Make Speech", open the speech editor sheet instead of immediate delivery
        if action.name == "Make Speech" {
            // Costs already deducted above; just set up the editor
            speechText = "My fellow Americans, we stand at a pivotal moment in our nation's history. Together, we will build a stronger economy, unite our people, and secure a brighter future for generations to come."
            isEditingSpeech = true
            return
        }

        // Sheet stays open — user can perform multiple actions or click "Done"
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
    let onPerform: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(action.category.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Perform") {
                    onPerform()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
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
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
                }

                Spacer()

                if action.cooldown > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(action.cooldown) turn cooldown")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func costIcon(_ type: ActionCostType) -> String {
        switch type {
        case .politicalCapital: return "banknote"
        case .time: return "clock"
        case .money: return "dollarsign.circle"
        case .mediaCycle: return "tv"
        }
    }
}

// MARK: - Briefings View

struct BriefingsView: View {
    @Binding var briefings: [Briefing]
    @EnvironmentObject var engine: SimulationEngine
    @Environment(\.dismiss) var dismiss
    @State private var selectedBriefing: Briefing?

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
                // Generate some sample briefings
                Color.clear
                    .onAppear {
                        generateSampleBriefings()
                    }

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
                                if let index = briefings.firstIndex(where: { $0.id == briefing.id }) {
                                    briefings[index].isRead = true
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 500, height: 450)
        .sheet(item: $selectedBriefing) { briefing in
            BriefingDetailView(briefing: briefing) {
                // Resolve briefing
                if let index = briefings.firstIndex(where: { $0.id == briefing.id }) {
                    briefings[index].isResolved = true
                }
                selectedBriefing = nil
            }
        }
    }

    private func generateSampleBriefings() {
        let sampleBriefings = [
            Briefing(
                type: .intelligence,
                title: "Foreign Leader Interest",
                summary: "Intelligence reports that a foreign leader has expressed interest in direct talks with you.",
                urgency: 2,
                turnReceived: engine.gameState.world.currentTurn,
                responseOptions: ["Schedule call", "Send emissary", "Delay response"]
            ),
            Briefing(
                type: .campaign,
                title: "Fundraising Opportunity",
                summary: "A major donor is hosting a fundraiser next week. Your team needs direction.",
                urgency: 3,
                turnReceived: engine.gameState.world.currentTurn,
                deadline: engine.gameState.world.currentTurn + 2,
                responseOptions: ["Attend personally", "Send surrogate", "Skip event"]
            ),
            Briefing(
                type: .legislative,
                title: "Congressional Push",
                summary: "Your allies in Congress want to know if you'll campaign for them this cycle.",
                urgency: 2,
                turnReceived: engine.gameState.world.currentTurn,
                responseOptions: ["Campaign actively", "Limited engagement", "Focus on own race"]
            )
        ]
        briefings = sampleBriefings
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
                                .foregroundColor(.orange)
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
                                .foregroundColor(.orange)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(12)
            .background(briefing.isResolved ? Color.green.opacity(0.1) : Color(NSColor.controlBackgroundColor))
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
    let onRespond: () -> Void
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
                        .foregroundColor(.green)
                    Text("Resolved")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else if !briefing.responseOptions.isEmpty {
                Divider()

                Text("Response Options")
                    .font(.headline)

                ForEach(briefing.responseOptions, id: \.self) { option in
                    Button(action: {
                        onRespond()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.circle")
                            Text(option)
                            Spacer()
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
