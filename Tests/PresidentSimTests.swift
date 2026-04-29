import XCTest
@testable import PresidentSim

final class PresidentSimTests: XCTestCase {

    // MARK: - GameState

    func testGameStateCodableRoundTrip() throws {
        let state = GameState()
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(state.phase, decoded.phase)
        XCTAssertEqual(state.player.name, decoded.player.name)
        XCTAssertEqual(state.world.approvalRating, decoded.world.approvalRating)
    }

    func testWorldStateCodableRoundTrip() throws {
        let world = WorldState()
        let data = try JSONEncoder().encode(world)
        let decoded = try JSONDecoder().decode(WorldState.self, from: data)
        XCTAssertEqual(world.approvalRating, decoded.approvalRating)
        XCTAssertEqual(world.inflation, decoded.inflation)
        XCTAssertEqual(world.currentYear, decoded.currentYear)
    }

    // MARK: - Turn Description

    func testTurnDescription_StartOfYear() {
        var world = WorldState()
        world.currentTurn = 1
        world.currentYear = 2025
        XCTAssertEqual(world.turnDescription, "January, Week 1, 2025")
    }

    func testTurnDescription_December() {
        var world = WorldState()
        world.currentTurn = 48
        world.currentYear = 2025
        XCTAssertEqual(world.turnDescription, "December, Week 9, 2025")
    }

    func testTurnDescription_November() {
        var world = WorldState()
        world.currentTurn = 44
        world.currentYear = 2025
        XCTAssertEqual(world.turnDescription, "November, Week 5, 2025")
    }

    func testTurnDescription_YearBoundary() {
        var world = WorldState()
        world.currentTurn = 53
        world.currentYear = 2025
        XCTAssertEqual(world.turnDescription, "January, Week 1, 2026")
    }

    // MARK: - Player

    func testPlayerCodableRoundTrip() throws {
        let player = Player(name: "Test Candidate", party: .republican)
        let data = try JSONEncoder().encode(player)
        let decoded = try JSONDecoder().decode(Player.self, from: data)
        XCTAssertEqual(player.name, decoded.name)
        XCTAssertEqual(player.party, decoded.party)
    }

    // MARK: - Actions

    func testActionRegistry_ReturnsActions() {
        let actions = ActionRegistry.allActions
        XCTAssertFalse(actions.isEmpty)
    }

    func testMakeSpeechAction_Exists() {
        let speechAction = ActionRegistry.allActions.first { $0.name == "Make Speech" }
        XCTAssertNotNil(speechAction)
        XCTAssertEqual(speechAction?.category, .communication)
    }
}
