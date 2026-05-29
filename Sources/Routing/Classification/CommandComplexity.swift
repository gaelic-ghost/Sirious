enum CommandComplexity: String, Equatable {
    case atomic
    case parameterized
    case multiStep = "multi_step"
    case openEnded = "open_ended"
}
