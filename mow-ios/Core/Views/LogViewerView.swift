import SwiftUI
import Combine
import UIKit

@MainActor
final class LogViewerViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedLevels: Set<LogLevel> = []
    @Published var selectedCategories: Set<LogCategory> = []
    @Published private(set) var entries: [LogEntry] = []

    private let logHistory: LogHistoryProviding
    private var streamTask: Task<Void, Never>?

    init(logHistory: LogHistoryProviding) {
        self.logHistory = logHistory
        observe()
    }

    deinit {
        streamTask?.cancel()
    }

    var filteredEntries: [LogEntry] {
        entries.filter { entry in
            levelFilterAllows(entry) &&
            categoryFilterAllows(entry) &&
            searchMatches(entry)
        }
    }

    func toggle(level: LogLevel) {
        if selectedLevels.contains(level) {
            selectedLevels.remove(level)
        } else {
            selectedLevels.insert(level)
        }
    }

    func toggle(category: LogCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    func export() async throws -> URL {
        try await logHistory.exportArchive()
    }

    private func observe() {
        streamTask = Task {
            let stream = await logHistory.stream()
            for await snapshot in stream {
                await MainActor.run {
                    self.entries = snapshot.sorted(by: { $0.sequence < $1.sequence })
                }
            }
        }
    }

    private func levelFilterAllows(_ entry: LogEntry) -> Bool {
        selectedLevels.isEmpty || selectedLevels.contains(entry.level)
    }

    private func categoryFilterAllows(_ entry: LogEntry) -> Bool {
        selectedCategories.isEmpty || selectedCategories.contains(entry.category)
    }

    private func searchMatches(_ entry: LogEntry) -> Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let query = trimmed.lowercased()
        if entry.message.lowercased().contains(query) {
            return true
        }
        if entry.metadata.contains(where: { key, value in
            key.lowercased().contains(query) || value.readableDescription.lowercased().contains(query)
        }) {
            return true
        }
        return false
    }
}

struct LogViewerView: View {
    @StateObject private var viewModel: LogViewerViewModel
    @State private var sharePayload: SharePayload?
    @State private var exportError: String?
    @State private var isExporting = false

    init(logHistory: LogHistoryProviding) {
        _viewModel = StateObject(wrappedValue: LogViewerViewModel(logHistory: logHistory))
    }

    var body: some View {
        List {
            if viewModel.filteredEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(LogViewerCopy.emptyTitle)
                        .font(.headline)
                    Text(LogViewerCopy.emptySubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.filteredEntries) { entry in
                    LogEntryRow(entry: entry)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }
            }
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .top, spacing: 0) {
            FiltersView(
                selectedLevels: $viewModel.selectedLevels,
                selectedCategories: $viewModel.selectedCategories
            )
            .background(.bar)
            .padding(.bottom, 4)
        }
        .searchable(text: $viewModel.searchText, prompt: LogViewerCopy.searchPrompt)
        .navigationTitle(LogViewerCopy.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await exportLogs() }
                } label: {
                    if isExporting {
                        ProgressView()
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(isExporting)
                .accessibilityLabel(Text(LogViewerCopy.exportAccessibilityLabel))
            }
        }
        .alert(LogViewerCopy.exportFailedTitle, isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        ), actions: {},
        message: { Text(exportError ?? "") })
        .sheet(item: $sharePayload) { payload in
            ShareSheet(activityItems: [payload.url])
        }
    }

    private func exportLogs() async {
        isExporting = true
        do {
            let url = try await viewModel.export()
            await MainActor.run {
                sharePayload = SharePayload(url: url)
                isExporting = false
            }
        } catch {
            await MainActor.run {
                exportError = error.localizedDescription
                isExporting = false
            }
        }
    }
}

private struct FiltersView: View {
    @Binding var selectedLevels: Set<LogLevel>
    @Binding var selectedCategories: Set<LogCategory>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LogLevel.allCases, id: \.rawValue) { level in
                    FilterChip(
                        title: level.label,
                        isSelected: selectedLevels.contains(level),
                        color: level.tintColor
                    ) {
                        if selectedLevels.contains(level) {
                            selectedLevels.remove(level)
                        } else {
                            selectedLevels.insert(level)
                        }
                    }
                }

                Divider().frame(height: 18)

                ForEach(LogCategory.defaults, id: \.rawValue) { category in
                    FilterChip(
                        title: category.rawValue,
                        isSelected: selectedCategories.contains(category),
                        color: .secondary
                    ) {
                        if selectedCategories.contains(category) {
                            selectedCategories.remove(category)
                        } else {
                            selectedCategories.insert(category)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.15) : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(isSelected ? color : .secondary)
        }
        .buttonStyle(.plain)
    }
}

private struct LogEntryRow: View {
    let entry: LogEntry
    private let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.level.label)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(entry.level.tintColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(entry.level.tintColor)
                Spacer()
                Text(timestampFormatter.string(from: entry.timestamp))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(entry.message)
                .font(.body.weight(.medium))

            if !entry.metadata.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack {
                            Text(key)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(value.readableDescription)
                                .font(.caption.monospaced())
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }

            if !entry.pii.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LogViewerCopy.piiLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(entry.pii.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        Text(LogViewerCopy.piiEntry(key: key, value: value.redacted))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text(verbatim: "\(entry.category.rawValue) • \(entry.source.function) • \(entry.source.file):\(entry.source.line)")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SharePayload: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension LogLevel {
    var tintColor: Color {
        switch self {
        case .trace: return .gray
        case .debug: return .blue
        case .info: return .teal
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
}

#Preview("en") {
    NavigationStack {
        LogViewerView(logHistory: MockLogHistoryProvider())
    }
}

#Preview("es") {
    NavigationStack {
        LogViewerView(logHistory: MockLogHistoryProvider())
            .environment(\.locale, .init(identifier: "es"))
    }
}
