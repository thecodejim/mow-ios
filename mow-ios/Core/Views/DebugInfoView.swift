import SwiftUI

struct DebugInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    let environment: AppEnvironment
    let deviceInfo: DeviceInfoService
    let logHistory: LogHistoryProviding
    
    var body: some View {
        NavigationStack {
            List {
                environmentSection
                endpointsSection
                featureFlagsSection
                deviceSection
                appSection
                diagnosticsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(DebugInfoCopy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(DebugInfoCopy.doneButtonTitle) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var environmentSection: some View {
        Section {
            InfoRow(label: DebugInfoCopy.environmentLabel, value: environment.name.displayName, style: .badge(environment.name.badgeColor))
            InfoRow(label: DebugInfoCopy.logLevelLabel, value: environment.logLevel.rawValue)
        } header: {
            Label(DebugInfoCopy.environmentSectionTitle, systemImage: "gearshape.2")
        }
    }
    
    private var endpointsSection: some View {
        Section {
            InfoRow(label: DebugInfoCopy.apiBaseLabel, value: environment.apiBaseURL.absoluteString, monospaced: true)
            InfoRow(label: DebugInfoCopy.docsLabel, value: environment.docsURL.absoluteString, monospaced: true)
            InfoRow(label: DebugInfoCopy.portalLabel, value: environment.portalURL.absoluteString, monospaced: true)
            InfoRow(label: DebugInfoCopy.telemetryLabel, value: environment.telemetryURL.absoluteString, monospaced: true)
            InfoRow(label: DebugInfoCopy.healthTokenLabel, value: maskedToken(environment.healthCheckToken), monospaced: true)
        } header: {
            Label(DebugInfoCopy.endpointsSectionTitle, systemImage: "network")
        }
    }
    
    private var featureFlagsSection: some View {
        Section {
            InfoRow(
                label: DebugInfoCopy.featureFlagLabel,
                value: environment.featureFlags.useMockData ? DebugInfoCopy.featureFlagEnabledValue : DebugInfoCopy.featureFlagDisabledValue,
                style: environment.featureFlags.useMockData ? .enabled : .disabled
            )
        } header: {
            Label(DebugInfoCopy.featureFlagsSectionTitle, systemImage: "flag")
        }
    }
    
    private var deviceSection: some View {
        Section {
            InfoRow(label: DebugInfoCopy.deviceArchitectureLabel, value: deviceInfo.deviceArchitecture)
            InfoRow(label: DebugInfoCopy.iosVersionLabel, value: deviceInfo.systemVersion)
            InfoRow(label: DebugInfoCopy.modelNameLabel, value: deviceInfo.modelName)
            #if DEBUG
            InfoRow(label: DebugInfoCopy.identifierLabel, value: deviceInfo.identifierForVendor, monospaced: true)
            #endif

        } header: {
            Label(DebugInfoCopy.deviceSectionTitle, systemImage: "iphone")
        }
    }
    
    private var appSection: some View {
        Section {
            InfoRow(label: DebugInfoCopy.appVersionLabel, value: environment.appVersion)
            InfoRow(label: DebugInfoCopy.buildLabel, value: environment.buildNumber)
            InfoRow(label: DebugInfoCopy.bundleLabel, value: environment.bundleIdentifier, monospaced: true)
        } header: {
            Label(DebugInfoCopy.appSectionTitle, systemImage: "app.badge")
        }
    }
    private var diagnosticsSection: some View {
        Section {
            NavigationLink {
                LogViewerView(logHistory: logHistory)
            } label: {
                Text(DebugInfoCopy.viewLogsActionTitle)
            }
        } header: {
            Label(DebugInfoCopy.diagnosticsSectionTitle, systemImage: "terminal")
        }
    }

    // MARK: - Helpers
    
    private func maskedToken(_ token: String) -> String {
        guard token.count > 8 else { return String(repeating: "•", count: token.count) }
        let prefix = token.prefix(4)
        let suffix = token.suffix(4)
        let masked = String(repeating: "•", count: token.count - 8)
        return "\(prefix)\(masked)\(suffix)"
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    enum Style {
        case plain
        case badge(Color)
        case enabled
        case disabled
    }
    
    let label: LocalizedStringKey
    let value: String
    var monospaced: Bool = false
    var style: Style = .plain
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            valueView
        }
    }
    
    @ViewBuilder
    private var valueView: some View {
        switch style {
        case .plain:
            Text(verbatim: value)
                .font(monospaced ? .footnote.monospaced() : .body)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        case .badge(let color):
            Text(verbatim: value)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color.opacity(0.15), in: Capsule())
                .foregroundStyle(color)
        case .enabled:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(verbatim: value)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.green)
            }
        case .disabled:
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                Text(verbatim: value)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Environment Badge Color

private extension AppEnvironment.Name {
    var badgeColor: Color {
        switch self {
        case .localDev: .orange
        case .stage: .purple
        case .prod: .green
        }
    }
}

// MARK: - Debug Info Button

struct DebugInfoButton: View {
    @Binding private var isPresented: Bool
    let environment: AppEnvironment
    let deviceInfo: DeviceInfoService
    let logHistory: LogHistoryProviding
    
    init(isPresented: Binding<Bool>, environment: AppEnvironment, deviceInfo: DeviceInfoService, logHistory: LogHistoryProviding) {
        self._isPresented = isPresented
        self.environment = environment
        self.deviceInfo = deviceInfo
        self.logHistory = logHistory
    }
    
    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text(DebugInfoCopy.versionBadge(appVersion: environment.appVersion, environmentName: environment.name.badgeText))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $isPresented) {
            DebugInfoView(environment: environment, deviceInfo: deviceInfo, logHistory: logHistory)
        }
    }
}

#Preview("en") {
    DebugInfoView(environment: .preview, deviceInfo: MockDeviceInfoService(), logHistory: MockLogHistoryProvider())
}

#Preview("es") {
    DebugInfoView(environment: .preview, deviceInfo: MockDeviceInfoService(), logHistory: MockLogHistoryProvider())
        .environment(\.locale, .init(identifier: "es"))
}
