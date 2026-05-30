import Observation
import OSLog

@MainActor
protocol RuntimeIssueLogging {
    func log(_ issue: RuntimeIssue)
}

struct OSLogRuntimeIssueLogger: RuntimeIssueLogging {
    private let logger = Logger(subsystem: "com.galewilliams.Sirious", category: "RuntimeIssue")

    func log(_ issue: RuntimeIssue) {
        switch issue.severity {
            case .info:
                logger.info("\(issue.subsystem.rawValue, privacy: .public): \(issue.message, privacy: .public)")
            case .warning:
                logger.warning("\(issue.subsystem.rawValue, privacy: .public): \(issue.message, privacy: .public)")
            case .error:
                logger.error("\(issue.subsystem.rawValue, privacy: .public): \(issue.message, privacy: .public)")
            case .critical:
                logger.critical("\(issue.subsystem.rawValue, privacy: .public): \(issue.message, privacy: .public)")
        }
    }
}

@MainActor
@Observable
final class RuntimeIssueStore {
    private(set) var latestIssue: RuntimeIssue?
    private(set) var recentIssues: [RuntimeIssue] = []

    @ObservationIgnored
    private let maximumIssueCount: Int

    @ObservationIgnored
    private let logger: any RuntimeIssueLogging

    @ObservationIgnored
    private var continuations: [UUID: AsyncStream<RuntimeIssue>.Continuation] = [:]

    var issues: AsyncStream<RuntimeIssue> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.continuations[id] = nil
                }
            }
        }
    }

    init(
        maximumIssueCount: Int = 10,
        logger: any RuntimeIssueLogging = OSLogRuntimeIssueLogger()
    ) {
        self.maximumIssueCount = maximumIssueCount
        self.logger = logger
    }

    func record(_ issue: RuntimeIssue) {
        latestIssue = issue
        recentIssues.insert(issue, at: 0)
        if recentIssues.count > maximumIssueCount {
            recentIssues.removeLast(recentIssues.count - maximumIssueCount)
        }

        logger.log(issue)

        for continuation in continuations.values {
            continuation.yield(issue)
        }
    }

    func clear() {
        latestIssue = nil
        recentIssues.removeAll()
    }
}
