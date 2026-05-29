import SwiftUI

struct CommandCenterView: View {
    private let previewRoute = RouteDecision(
        route: .localFunction,
        domain: .appControl,
        complexity: .atomic,
        risk: .safe,
        readiness: .actionable,
        confidence: 0.96
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sirious")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Local voice command routing lab")
                .foregroundStyle(.secondary)

            RouteDecisionView(decision: previewRoute)
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 360, alignment: .topLeading)
    }
}
