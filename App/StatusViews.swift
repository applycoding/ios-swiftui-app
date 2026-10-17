import SwiftUI
import FleetLogCore

struct StatusBadge: View {
    let status: TripStatus

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(FleetTheme.color(for: status))
            .background(FleetTheme.color(for: status).opacity(0.14), in: Capsule())
            .accessibilityLabel("Status: \(status.title)")
    }
}

struct LoadingStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text(title)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(FleetTheme.ink)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(FleetTheme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FleetTheme.paper)
    }
}

struct ErrorStateView: View {
    let title: String
    let message: String
    var retryTitle: String? = "Try again"
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(FleetTheme.amber)
            Text(title)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(FleetTheme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(FleetTheme.inkSoft)
                .multilineTextAlignment(.center)
            if let retryTitle, let retry {
                Button(retryTitle, action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FleetTheme.paper)
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(FleetTheme.inkSoft)
    }
}

struct FactBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: title)
            Text(value)
                .font(.body)
                .foregroundStyle(FleetTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
