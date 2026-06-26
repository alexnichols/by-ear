import Foundation

public enum PracticeStem: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case piano
    case vocals
    case bass
    case drums

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .piano:
            return "Piano"
        case .vocals:
            return "Voice"
        case .bass:
            return "Bass"
        case .drums:
            return "Drums"
        }
    }
}
