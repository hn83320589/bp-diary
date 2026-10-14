import Foundation

enum Arm: String, Codable, CaseIterable, Identifiable, Sendable {
    case left
    case right

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left: "左手"
        case .right: "右手"
        }
    }
}
