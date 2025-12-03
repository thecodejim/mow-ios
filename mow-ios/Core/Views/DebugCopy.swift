import SwiftUI
import Foundation

enum DebugInfoCopy {
    private enum Key {
        static let title = "debugInfo.title"
        static let doneButton = "debugInfo.done"
        static let environmentSection = "debugInfo.section.environment"
        static let endpointsSection = "debugInfo.section.endpoints"
        static let featureFlagsSection = "debugInfo.section.featureFlags"
        static let deviceSection = "debugInfo.section.device"
        static let appSection = "debugInfo.section.app"
        static let diagnosticsSection = "debugInfo.section.diagnostics"
        static let environmentLabel = "debugInfo.label.environment"
        static let logLevelLabel = "debugInfo.label.logLevel"
        static let apiBaseLabel = "debugInfo.label.apiBase"
        static let docsLabel = "debugInfo.label.docs"
        static let portalLabel = "debugInfo.label.portal"
        static let telemetryLabel = "debugInfo.label.telemetry"
        static let healthTokenLabel = "debugInfo.label.healthToken"
        static let featureFlagLabel = "debugInfo.label.useMockData"
        static let enabledValue = "debugInfo.value.enabled"
        static let disabledValue = "debugInfo.value.disabled"
        static let deviceArchitectureLabel = "debugInfo.label.deviceArchitecture"
        static let iosVersionLabel = "debugInfo.label.iosVersion"
        static let modelNameLabel = "debugInfo.label.modelName"
        static let identifierLabel = "debugInfo.label.identifier"
        static let appVersionLabel = "debugInfo.label.version"
        static let buildLabel = "debugInfo.label.build"
        static let bundleLabel = "debugInfo.label.bundleId"
        static let viewLogs = "debugInfo.action.viewLogs"
        static let versionBadge = "debugInfo.button.versionBadge"
    }

    static var title: LocalizedStringKey { .init(Key.title) }
    static var doneButtonTitle: LocalizedStringKey { .init(Key.doneButton) }
    static var environmentSectionTitle: LocalizedStringKey { .init(Key.environmentSection) }
    static var endpointsSectionTitle: LocalizedStringKey { .init(Key.endpointsSection) }
    static var featureFlagsSectionTitle: LocalizedStringKey { .init(Key.featureFlagsSection) }
    static var deviceSectionTitle: LocalizedStringKey { .init(Key.deviceSection) }
    static var appSectionTitle: LocalizedStringKey { .init(Key.appSection) }
    static var diagnosticsSectionTitle: LocalizedStringKey { .init(Key.diagnosticsSection) }

    static var environmentLabel: LocalizedStringKey { .init(Key.environmentLabel) }
    static var logLevelLabel: LocalizedStringKey { .init(Key.logLevelLabel) }
    static var apiBaseLabel: LocalizedStringKey { .init(Key.apiBaseLabel) }
    static var docsLabel: LocalizedStringKey { .init(Key.docsLabel) }
    static var portalLabel: LocalizedStringKey { .init(Key.portalLabel) }
    static var telemetryLabel: LocalizedStringKey { .init(Key.telemetryLabel) }
    static var healthTokenLabel: LocalizedStringKey { .init(Key.healthTokenLabel) }
    static var featureFlagLabel: LocalizedStringKey { .init(Key.featureFlagLabel) }
    static var deviceArchitectureLabel: LocalizedStringKey { .init(Key.deviceArchitectureLabel) }
    static var iosVersionLabel: LocalizedStringKey { .init(Key.iosVersionLabel) }
    static var modelNameLabel: LocalizedStringKey { .init(Key.modelNameLabel) }
    static var identifierLabel: LocalizedStringKey { .init(Key.identifierLabel) }
    static var appVersionLabel: LocalizedStringKey { .init(Key.appVersionLabel) }
    static var buildLabel: LocalizedStringKey { .init(Key.buildLabel) }
    static var bundleLabel: LocalizedStringKey { .init(Key.bundleLabel) }

    static var viewLogsActionTitle: LocalizedStringKey { .init(Key.viewLogs) }

    static func versionBadge(appVersion: String, environmentName: String) -> LocalizedStringKey {
        LocalizedStringKey("\(Key.versionBadge) \(appVersion) \(environmentName)")
    }

    static var featureFlagEnabledValue: String { localized(Key.enabledValue) }
    static var featureFlagDisabledValue: String { localized(Key.disabledValue) }

    private static func localized(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "")
    }
}

enum LogViewerCopy {
    private enum Key {
        static let title = "logViewer.title"
        static let searchPrompt = "logViewer.search.prompt"
        static let emptyTitle = "logViewer.empty.title"
        static let emptySubtitle = "logViewer.empty.subtitle"
        static let exportAccessibility = "logViewer.export.accessibilityLabel"
        static let exportFailedTitle = "logViewer.export.failedTitle"
        static let piiLabel = "logViewer.metadata.pii"
        static let piiEntry = "logViewer.metadata.piiEntry"
    }

    static var title: LocalizedStringKey { .init(Key.title) }
    static var searchPrompt: LocalizedStringKey { .init(Key.searchPrompt) }
    static var emptyTitle: LocalizedStringKey { .init(Key.emptyTitle) }
    static var emptySubtitle: LocalizedStringKey { .init(Key.emptySubtitle) }
    static var exportAccessibilityLabel: LocalizedStringKey { .init(Key.exportAccessibility) }
    static var exportFailedTitle: LocalizedStringKey { .init(Key.exportFailedTitle) }
    static var piiLabel: LocalizedStringKey { .init(Key.piiLabel) }

    static func piiEntry(key: String, value: String) -> LocalizedStringKey {
        LocalizedStringKey("\(Key.piiEntry) \(key) \(value)")
    }
}

