//
//  ContentView.swift
//  mow-ios
//
//  Created by James Smith on 11/22/25.
//

import SwiftUI

struct ContentView: View {
    private let environment = AppEnvironment.current

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                EnvironmentHeader(environment: environment)

                EnvironmentDetailList(environment: environment)

                Spacer()
            }
            .padding(24)
            .navigationTitle("Meals on Wheels")
        }
    }
}

private struct EnvironmentHeader: View {
    let environment: AppEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EnvironmentBadge(name: environment.name)
            Text("App foundations are in place.")
                .font(.title2.weight(.semibold))
            Text("You're connected to \(environment.name.displayName) with feature flags and endpoints loaded from xcconfig files.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EnvironmentDetailList: View {
    let environment: AppEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EnvironmentDetailRow(title: "API base URL", value: environment.apiBaseURL.absoluteString)
            EnvironmentDetailRow(title: "Docs URL", value: environment.docsURL.absoluteString)
            EnvironmentDetailRow(title: "Portal URL", value: environment.portalURL.absoluteString)
            EnvironmentDetailRow(title: "Telemetry endpoint", value: environment.telemetryURL.absoluteString)
            EnvironmentDetailRow(
                title: "Feature flags",
                value: environment.featureFlags.useMockData ? "Mock data ON" : "Mock data OFF"
            )
            EnvironmentDetailRow(title: "Log level", value: environment.logLevel.rawValue)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct EnvironmentDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospaced())
                .textSelection(.enabled)
        }
    }
}

private struct EnvironmentBadge: View {
    let name: AppEnvironment.Name

    private var tint: Color {
        switch name {
        case .localDev: .green
        case .stage: .orange
        case .prod: .blue
        }
    }

    var body: some View {
        Text(name.badgeText)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(tint)
            .background(tint.opacity(0.15), in: Capsule(style: .continuous))
    }
}

#Preview {
    ContentView()
}
