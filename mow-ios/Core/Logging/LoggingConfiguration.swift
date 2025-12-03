import Foundation

struct LoggingConfiguration: Sendable {
    struct DestinationConfiguration: Sendable {
        struct Console: Sendable {
            let isEnabled: Bool
            let showIcon: Bool
        }

        struct File: Sendable {
            let isEnabled: Bool
            let maxFileBytes: Int
            let maxFiles: Int // max rotated archives - active file will be +1
            let directoryName: String
        }

        let console: Console
        let file: File
        let inMemoryEntryLimit: Int
    }

    struct PIIBehavior: Sendable {
        let captureHashes: Bool
    }

    let defaultLevel: LogLevel
    let categoryLevels: [LogCategory: LogLevel]
    let destinations: DestinationConfiguration
    let globalMetadata: LogMetadataFields
    let piiBehavior: PIIBehavior
    let serverTimeOffset: TimeInterval
}

extension AppEnvironment {
    var loggingConfiguration: LoggingConfiguration {
        LoggingConfiguration(
            defaultLevel: defaultLogLevel.asLogLevel,
            categoryLevels: categoryThresholds.mapValues { $0.asLogLevel },
            destinations: destinationsConfiguration,
            globalMetadata: [
                "appVersion": .public(appVersion),
                "buildNumber": .public(buildNumber),
                "bundleId": .public(bundleIdentifier),
                "environment": .public(name.rawValue),
                "deviceLocale": .public(Locale.current.identifier)
            ],
            piiBehavior: LoggingConfiguration.PIIBehavior(
                captureHashes: name != .localDev
            ),
            serverTimeOffset: 0 // reserved for future server-synchronized clocks
        )
    }

    private var defaultLogLevel: AppEnvironment.LogLevel {
        switch name {
        case .localDev:
            return .debug
        case .stage:
            return .info
        case .prod:
            return .error
        }
    }

    private var categoryThresholds: [LogCategory: AppEnvironment.LogLevel] {
        switch name {
        case .localDev:
            return [
                .network: .debug,
                .database: .debug,
                .ui: .debug,
                .auth: .info,
                .businessLogic: .info,
                .analytics: .info
            ]
        case .stage:
            return [
                .network: .debug,
                .database: .info,
                .auth: .info,
                .businessLogic: .info,
                .ui: .info
            ]
        case .prod:
            return [
                .network: .warn,
                .database: .warn,
                .auth: .info,
                .businessLogic: .info
            ]
        }
    }

    private var destinationsConfiguration: LoggingConfiguration.DestinationConfiguration {
        switch name {
        case .localDev:
            return .init(
                console: .init(isEnabled: true, showIcon: true),
                file: .init(
                    isEnabled: false,
                    maxFileBytes: 5 * 1_024 * 1_024,
                    maxFiles: 2,
                    directoryName: "Logs"
                ),
                inMemoryEntryLimit: 500
            )
        case .stage:
            return .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(
                    isEnabled: true,
                    maxFileBytes: 5 * 1_024 * 1_024,
                    maxFiles: 3,
                    directoryName: "StageLogs"
                ),
                inMemoryEntryLimit: 600
            )
        case .prod:
            return .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(
                    isEnabled: true,
                    maxFileBytes: 5 * 1_024 * 1_024,
                    maxFiles: 3,
                    directoryName: "ProdLogs"
                ),
                inMemoryEntryLimit: 600
            )
        }
    }
}

private extension AppEnvironment.LogLevel {
    var asLogLevel: LogLevel {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warn: return .warning
        case .error: return .error
        }
    }
}
