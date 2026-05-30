import SwiftUI

extension RoutingMode {
    var menuBarSystemImage: String {
        switch self {
            case .command:
                "waveform"
            case .text:
                "textformat"
            case .secureText:
                "lock.fill"
            case .search:
                "hourglass"
            case .swift:
                "swift"
            case .chat:
                "bubble.left.and.bubble.right.fill"
            case .code:
                "chevron.left.forwardslash.chevron.right"
        }
    }

    var menuBarForegroundStyle: AnyShapeStyle {
        switch self {
            case .command:
                AnyShapeStyle(.primary)
            case .text:
                AnyShapeStyle(.blue)
            case .secureText:
                AnyShapeStyle(.yellow)
            case .search:
                AnyShapeStyle(.purple)
            case .swift:
                AnyShapeStyle(.orange)
            case .chat:
                AnyShapeStyle(.mint)
            case .code:
                AnyShapeStyle(.cyan)
        }
    }
}
