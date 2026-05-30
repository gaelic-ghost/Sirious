protocol AccessibilityPermissionProviding: Sendable {
    @MainActor
    func status() -> AccessibilityPermissionStatus
}
