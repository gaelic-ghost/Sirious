import Foundation

enum AutomationHelperXPC {
    static let machServiceName = "com.galewilliams.Sirious.AutomationHelper"
    static let terminationStatusKey = "terminationStatus"
    static let standardOutputKey = "standardOutput"
    static let standardErrorKey = "standardError"
}

@objc
protocol AutomationHelperXPCProtocol {
    func runCommand(_ arguments: [String], withReply reply: @escaping (NSDictionary) -> Void)
}
