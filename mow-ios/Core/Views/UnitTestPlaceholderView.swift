import SwiftUI

struct UnitTestPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(verbatim: "Unit Test Mode")
                .font(.title2.weight(.semibold))

            Text(verbatim: "UI rendering is disabled while tests run.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    UnitTestPlaceholderView()
}
