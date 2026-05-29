enum StreamingReadiness: String, Equatable, Sendable {
    case notEnough = "not_enough"
    case likelyRoute = "likely_route"
    case actionable
    case waitForEndpoint = "wait_for_endpoint"
}
