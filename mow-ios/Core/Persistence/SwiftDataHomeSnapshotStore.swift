import Foundation
import SwiftData

// MARK: - Async storage primitives

protocol AsyncDataStoring {
    func load(key: String) async throws -> Data?
    func save(_ data: Data, key: String) async throws
    func delete(key: String) async throws
}

@Model
final class CachedBlob {
    @Attribute(.unique) var key: String
    var storedAt: Date
    @Attribute(.externalStorage) var payload: Data

    init(key: String, storedAt: Date = .now, payload: Data) {
        self.key = key
        self.storedAt = storedAt
        self.payload = payload
    }
}

final class SwiftDataBlobStore: AsyncDataStoring {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func load(key: String) async throws -> Data? {
        try await MainActor.run {
            let context = makeContext()
            var descriptor = FetchDescriptor<CachedBlob>(
                predicate: #Predicate { $0.key == key },
                sortBy: [SortDescriptor(\.storedAt, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.payload
        }
    }

    func save(_ data: Data, key: String) async throws {
        try await MainActor.run {
            let context = makeContext()
            let descriptor = FetchDescriptor<CachedBlob>(
                predicate: #Predicate { $0.key == key }
            )
            let existing = try context.fetch(descriptor)
            existing.forEach(context.delete)
            context.insert(CachedBlob(key: key, storedAt: .now, payload: data))
            try context.save()
        }
    }

    func delete(key: String) async throws {
        try await MainActor.run {
            let context = makeContext()
            let descriptor = FetchDescriptor<CachedBlob>(
                predicate: #Predicate { $0.key == key }
            )
            let records = try context.fetch(descriptor)
            guard !records.isEmpty else { return }
            records.forEach(context.delete)
            try context.save()
        }
    }

    @MainActor
    private func makeContext() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }
}

// MARK: - Async Codable store

enum AsyncCodableStoreError: Error {
    case encodingFailed(Error)
    case decodingFailed(Error)
    case underlying(Error)
}

extension AsyncCodableStoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .encodingFailed(error):
            return "Failed to encode value: \(error.localizedDescription)"
        case let .decodingFailed(error):
            return "Failed to decode value: \(error.localizedDescription)"
        case let .underlying(error):
            return error.localizedDescription
        }
    }
}

final class AsyncCodableStore<Value: Codable> {
    private let dataStore: AsyncDataStoring
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        dataStore: AsyncDataStoring,
        key: String,
        configureEncoder: (JSONEncoder) -> Void = { _ in },
        configureDecoder: (JSONDecoder) -> Void = { _ in }
    ) {
        self.dataStore = dataStore
        self.key = key

        let encoder = JSONEncoder()
        configureEncoder(encoder)
        self.encoder = encoder

        let decoder = JSONDecoder()
        configureDecoder(decoder)
        self.decoder = decoder
    }

    func load() async throws -> Value? {
        do {
            guard let data = try await dataStore.load(key: key) else { return nil }
            return try decoder.decode(Value.self, from: data)
        } catch let error as AsyncCodableStoreError {
            throw error
        } catch let error as DecodingError {
            throw AsyncCodableStoreError.decodingFailed(error)
        } catch {
            throw AsyncCodableStoreError.underlying(error)
        }
    }

    func save(_ value: Value) async throws {
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw AsyncCodableStoreError.encodingFailed(error)
        }

        do {
            try await dataStore.save(data, key: key)
        } catch let error as AsyncCodableStoreError {
            throw error
        } catch {
            throw AsyncCodableStoreError.underlying(error)
        }
    }

    func clear() async throws {
        do {
            try await dataStore.delete(key: key)
        } catch let error as AsyncCodableStoreError {
            throw error
        } catch {
            throw AsyncCodableStoreError.underlying(error)
        }
    }
}

// MARK: - Domain store

protocol HomeSnapshotStoring: AnyObject, Sendable {
    func latestSnapshot() async throws -> HomeSnapshot?
    func save(_ snapshot: HomeSnapshot) async throws
    func clear() async throws
}

final class SwiftDataHomeSnapshotStore: HomeSnapshotStoring {
    private static let storageKey = "home.snapshot"

    private let store: AsyncCodableStore<HomeSnapshot>

    init(container: ModelContainer) {
        let blobStore = SwiftDataBlobStore(container: container)
        self.store = AsyncCodableStore(
            dataStore: blobStore,
            key: Self.storageKey,
            configureEncoder: { $0.dateEncodingStrategy = .iso8601 },
            configureDecoder: { $0.dateDecodingStrategy = .iso8601 }
        )
    }

    @MainActor
    static func makeDefault(for environment: AppEnvironment) -> SwiftDataHomeSnapshotStore {
        ensureApplicationSupportDirectoryExists()

        do {
            let container = try ModelContainer(for: CachedBlob.self)
            return SwiftDataHomeSnapshotStore(container: container)
        } catch {
            assertionFailure("Failed to set up SwiftData container: \(error)")
            let fallback = try? ModelContainer(
                for: CachedBlob.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )

            guard let fallback else {
                fatalError("Unable to create SwiftData container, even in-memory.")
            }

            return SwiftDataHomeSnapshotStore(container: fallback)
        }
    }

    func latestSnapshot() async throws -> HomeSnapshot? {
        try await store.load()
    }

    func save(_ snapshot: HomeSnapshot) async throws {
        try await store.save(snapshot)
    }

    func clear() async throws {
        try await store.clear()
    }
    
    private static func ensureApplicationSupportDirectoryExists() {
        let fm = FileManager.default
        guard let dirURL = fm.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first
        else { return }

        if !fm.fileExists(atPath: dirURL.path) {
            do {
                try fm.createDirectory(
                    at: dirURL,
                    withIntermediateDirectories: true
                )
            } catch {
                print("Failed to create Application Support directory: \(error)")
            }
        }
    }
}

// MARK: - Mock services

actor InMemoryHomeSnapshotStore: HomeSnapshotStoring {
    private var snapshot: HomeSnapshot?

    func latestSnapshot() async throws -> HomeSnapshot? {
        snapshot
    }

    func save(_ snapshot: HomeSnapshot) async throws {
        self.snapshot = snapshot
    }

    func clear() async throws {
        snapshot = nil
    }
}
