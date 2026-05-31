import SwiftUI

struct RouteDecisionView: View {
    let decision: RouteDecision

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
            row("Route", decision.route.rawValue)
            row("Domain", decision.domain.rawValue)
            row("Complexity", decision.complexity.rawValue)
            row("Risk", decision.risk.rawValue)
            row("Readiness", decision.readiness.rawValue)
            row("Confidence", decision.confidence.formatted(.number.precision(.fractionLength(2))))
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .fontWeight(.medium)
            Text(value)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("routeDecision.\(label)")
        }
    }
}
