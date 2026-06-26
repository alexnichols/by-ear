import Foundation

public struct PracticeWindowMetrics: Equatable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public enum PracticeWindowLayout {
    public static func metrics(hasAudio: Bool) -> PracticeWindowMetrics {
        hasAudio
            ? PracticeWindowMetrics(width: 860, height: 560)
            : PracticeWindowMetrics(width: 520, height: 190)
    }
}
