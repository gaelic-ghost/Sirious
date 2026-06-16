import Foundation

enum AutomationHelperXPC {
    static let signingTeamIdentifier = "BC73766F69"
    static let appBundleIdentifier = "com.galewilliams.Sirious"
    static let helperBundleIdentifier = "com.galewilliams.Sirious.AutomationHelper"
    static let launchAgentPlistName = "com.galewilliams.Sirious.AutomationHelper.plist"
    static let machServiceName = "com.galewilliams.Sirious.AutomationHelper"
    static let terminationStatusKey = "terminationStatus"
    static let standardOutputKey = "standardOutput"
    static let standardErrorKey = "standardError"
    static let appCodeSigningRequirement = codeSigningRequirement(bundleIdentifier: appBundleIdentifier)
    static let helperCodeSigningRequirement = codeSigningRequirement(bundleIdentifier: helperBundleIdentifier)

    static func connectionErrorMessage(
        for error: any Error,
        commandArguments: [String]
    ) -> String {
        let error = error as NSError
        let command = commandArguments.joined(separator: " ")

        if error.domain == NSCocoaErrorDomain,
           error.code == NSXPCConnectionCodeSigningRequirementFailure
        {
            return "Sirious rejected the automation helper XPC peer because its code signature did not satisfy the required signing identity. Required helper identifier: \(helperBundleIdentifier). Required team identifier: \(signingTeamIdentifier). macOS reported: \(error.localizedDescription). Command: \(command)."
        }

        return "Sirious could not connect to the automation helper XPC service named \(machServiceName). macOS reported: \(error.localizedDescription). Command: \(command)."
    }

    private static func codeSigningRequirement(bundleIdentifier: String) -> String {
        #"anchor apple generic and certificate leaf[subject.OU] = "\#(signingTeamIdentifier)" and identifier "\#(bundleIdentifier)""#
    }
}

@objc
protocol AutomationHelperXPCProtocol {
    func runCommand(_ arguments: [String], withReply reply: @escaping (NSDictionary) -> Void)
}
