import Foundation
import SwiftData

protocol HomeSnapshotStoring: AnyObject {
    func latestSnapshot() async throws -> HomeSnapshot?
    func save(_ snapshot: HomeSnapshot) async throws
    func clear() async throws
}

@Model
final class CachedHomeSnapshot {
    @Attribute(.unique) var id: UUID
    var storedAt: Date
    @Attribute(.externalStorage) var payload: Data

    init(id: UUID = UUID(), storedAt: Date = .now, payload: Data) {
        self.id = id
        self.storedAt = storedAt
        self.payload = payload
    }
}

final class SwiftDataHomeSnapshotStore: HomeSnapshotStoring {
    private let container: ModelContainer
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(container: ModelContainer) {
        self.container = container

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    @MainActor
    static func makeDefault(for environment: AppEnvironment) -> SwiftDataHomeSnapshotStore {
        do {
            let container = try ModelContainer(for: CachedHomeSnapshot.self)
            return SwiftDataHomeSnapshotStore(container: container)
        } catch {
            assertionFailure("Failed to set up SwiftData container: \(error)")
            let fallback = try? ModelContainer(
                for: CachedHomeSnapshot.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )

            guard let fallback else {
                fatalError("Unable to create SwiftData container, even in-memory.")
            }

            return SwiftDataHomeSnapshotStore(container: fallback)
        }
    }

    func latestSnapshot() async throws -> HomeSnapshot? {
        try await MainActor.run {
            let context = makeContext()
            var descriptor = FetchDescriptor<CachedHomeSnapshot>(
                sortBy: [SortDescriptor(\.storedAt, order: .reverse)]
            )
            descriptor.fetchLimit = 1

            guard let stored = try context.fetch(descriptor).first else {
                return nil
            }

            return try decoder.decode(HomeSnapshot.self, from: stored.payload)
        }
    }

    func save(_ snapshot: HomeSnapshot) async throws {
        try await MainActor.run {
            let context = makeContext()
            try clear(in: context)
            let payload = try encoder.encode(snapshot)
            context.insert(CachedHomeSnapshot(storedAt: .now, payload: payload))
            try context.save()
        }
    }

    func clear() async throws {
        try await MainActor.run {
            let context = makeContext()
            try clear(in: context)
        }
    }

    @MainActor
    private func makeContext() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    @MainActor
    private func clear(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<CachedHomeSnapshot>()
        let records = try context.fetch(descriptor)
        guard !records.isEmpty else { return }

        records.forEach(context.delete)
        try context.save()
    }
}

