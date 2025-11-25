import SwiftUI

struct DebugInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let environment = AppEnvironment.current
    
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
            InfoRow(label: "Device", value: deviceModel)
            InfoRow(label: "iOS Version", value: UIDevice.current.systemVersion)
            InfoRow(label: "Device Name", value: UIDevice.current.name)
            InfoRow(label: "Identifier", value: identifierForVendor, monospaced: true)
        } header: {
            Label("Device", systemImage: "iphone")
        }
    }
    
    private var appSection: some View {
        Section {
            InfoRow(label: "Version", value: appVersion)
            InfoRow(label: "Build", value: buildNumber)
            InfoRow(label: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "Unknown", monospaced: true)
        } header: {
            Label("App", systemImage: "app.badge")
        }
    }
    
    // MARK: - Computed Properties
    
    private var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    private var identifierForVendor: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "Unavailable"
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    private func maskedToken(_ token: String) -> String {
        guard token.count > 8 else { return String(repeating: "•", count: token.count) }
        let prefix = token.prefix(4)
        let suffix = token.suffix(4)
        let masked = String(repeating: "•", count: min(token.count - 8, 12))
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
    @State private var isShowingDebugInfo = false
    
    var body: some View {
        Button {
            isShowingDebugInfo = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text("v\(appVersion) • \(AppEnvironment.current.name.badgeText)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $isShowingDebugInfo) {
            DebugInfoView()
        }
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
}

#Preview {
    DebugInfoView()
}

