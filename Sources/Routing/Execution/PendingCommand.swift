import Foundation

struct PendingCommand: Equatable, Identifiable {
    var id: UUID
    var match: RouteMatch
    var enqueuedAt: Date

    init(
        id: UUID = UUID(),
        match: RouteMatch,
        enqueuedAt: Date = Date()
    ) {
        self.id = id
        self.match = match
        self.enqueuedAt = enqueuedAt
    }
}
