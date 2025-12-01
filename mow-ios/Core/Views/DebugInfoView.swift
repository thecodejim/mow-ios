import SwiftUI

struct DebugInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    let environment: AppEnvironment
    let deviceInfo: any DeviceInfoService
    
    var body: some View {
        NavigationStack {
            List {
                environmentSection
                endpointsSection
                featureFlagsSection
                deviceSection
                appSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Debug Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var environmentSection: some View {
        Section {
            InfoRow(label: "Environment", value: environment.name.displayName, style: .badge(environment.name.badgeColor))
            InfoRow(label: "Log Level", value: environment.logLevel.rawValue)
        } header: {
            Label("Environment", systemImage: "gearshape.2")
        }
    }
    
    private var endpointsSection: some View {
        Section {
            InfoRow(label: "API Base", value: environment.apiBaseURL.absoluteString, monospaced: true)
            InfoRow(label: "Docs", value: environment.docsURL.absoluteString, monospaced: true)
            InfoRow(label: "Portal", value: environment.portalURL.absoluteString, monospaced: true)
            InfoRow(label: "Telemetry", value: environment.telemetryURL.absoluteString, monospaced: true)
            InfoRow(label: "Health Token", value: maskedToken(environment.healthCheckToken), monospaced: true)
        } header: {
            Label("Endpoints", systemImage: "network")
        }
    }
    
    private var featureFlagsSection: some View {
        Section {
            InfoRow(label: "Use Mock Data", value: environment.featureFlags.useMockData ? "Enabled" : "Disabled", style: environment.featureFlags.useMockData ? .enabled : .disabled)
        } header: {
            Label("Feature Flags", systemImage: "flag")
        }
    }
    
    private var deviceSection: some View {
        Section {
            InfoRow(label: "Device", value: deviceInfo.model)
            InfoRow(label: "iOS Version", value: deviceInfo.systemVersion)
            InfoRow(label: "Device Name", value: deviceInfo.name)
            InfoRow(label: "Identifier", value: deviceInfo.identifierForVendor, monospaced: true)
        } header: {
            Label("Device", systemImage: "iphone")
        }
    }
    
    private var appSection: some View {
        Section {
            InfoRow(label: "Version", value: environment.appVersion)
            InfoRow(label: "Build", value: environment.buildNumber)
            InfoRow(label: "Bundle ID", value: environment.bundleIdentifier, monospaced: true)
        } header: {
            Label("App", systemImage: "app.badge")
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
    
    let label: String
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
            Text(value)
                .font(monospaced ? .footnote.monospaced() : .body)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        case .badge(let color):
            Text(value)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color.opacity(0.15), in: Capsule())
                .foregroundStyle(color)
        case .enabled:
            Label(value, systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.green)
        case .disabled:
            Label(value, systemImage: "xmark.circle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
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
    let deviceInfo: any DeviceInfoService
    
    init(isPresented: Binding<Bool>, environment: AppEnvironment, deviceInfo: any DeviceInfoService) {
        self._isPresented = isPresented
        self.environment = environment
        self.deviceInfo = deviceInfo
    }
    
    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text("v\(environment.appVersion) • \(environment.name.badgeText)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $isPresented) {
            DebugInfoView(environment: environment, deviceInfo: deviceInfo)
        }
    }
}

#Preview {
    DebugInfoView(environment: .preview, deviceInfo: MockDeviceInfoService())
}
