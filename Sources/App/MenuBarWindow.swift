import SwiftUI

struct MenuBarWindow: View {
    var pendingCommands: PendingCommandStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Sirious", systemImage: "waveform")
                .font(.headline)

            if let canceled = pendingCommands.canceledCommands.last {
                Text("Canceled \(description(for: canceled)).")
                    .foregroundStyle(.red)
            } else if pendingCommands.completedCommands.isEmpty == false {
                Text("No commands are pending.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Ready for local voice routing.")
                    .foregroundStyle(.secondary)
            }

            if pendingCommands.queuedCommandCount > 0 {
                Text("\(pendingCommands.queuedCommandCount) risky command(s) queued.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(width: 280, alignment: .leading)
        .onAppear {
            pendingCommands.cancelActive()
        }
    }

    private func description(for command: PendingCommand) -> String {
        if let patternCommand = command.match.command {
            return patternCommand.rawValue
        }

        return command.match.decision.route.rawValue
    }
}
