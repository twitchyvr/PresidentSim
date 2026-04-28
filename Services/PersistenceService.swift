import Foundation

// MARK: - Persistence Service
// Handles saving/loading game state

class PersistenceService {
    private let saveDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        saveDirectory = appSupport.appendingPathComponent("PresidentSim/Saves", isDirectory: true)

        try? FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true)
    }

    func save(_ gameState: GameState, filename: String? = nil) throws {
        let name = filename ?? "save_\(Date().timeIntervalSince1970).json"
        let url = saveDirectory.appendingPathComponent(name)

        let data = try encoder.encode(gameState)
        try data.write(to: url)
    }

    func load(filename: String) throws -> GameState {
        let url = saveDirectory.appendingPathComponent(filename)
        let data = try Data(contentsOf: url)
        return try decoder.decode(GameState.self, from: data)
    }

    func listSaves() -> [SaveMetadata] {
        let contents = (try? FileManager.default.contentsOfDirectory(at: saveDirectory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []

        return contents.compactMap { url -> SaveMetadata? in
            guard url.pathExtension == "json" else { return nil }

            let name = url.deletingPathExtension().lastPathComponent
            let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0

            return SaveMetadata(
                filename: url.lastPathComponent,
                displayName: name,
                modifiedDate: modDate ?? Date(),
                sizeBytes: size
            )
        }.sorted { $0.modifiedDate > $1.modifiedDate }
    }

    func delete(filename: String) throws {
        let url = saveDirectory.appendingPathComponent(filename)
        try FileManager.default.removeItem(at: url)
    }
}

struct SaveMetadata: Identifiable {
    var id: String { filename }
    let filename: String
    let displayName: String
    let modifiedDate: Date
    let sizeBytes: Int

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modifiedDate)
    }
}
