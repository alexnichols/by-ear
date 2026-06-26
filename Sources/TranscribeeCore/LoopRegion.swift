import Foundation

public enum PracticeSpeed {
    public static let minimum = 0.1
    public static let maximum = 1.5

    public static func clamp(_ value: Double) -> Double {
        min(maximum, max(minimum, value))
    }
}

public struct LoopRegion: Equatable, Sendable {
    public static let minimumLength = 0.1

    public var start: Double
    public var end: Double
    public var isEnabled: Bool

    public init(start: Double, end: Double, isEnabled: Bool = true) {
        self.start = start
        self.end = end
        self.isEnabled = isEnabled
    }

    public var duration: Double {
        max(0, end - start)
    }

    public static func fromSelection(_ first: Double, _ second: Double, duration: Double) -> LoopRegion {
        let fileDuration = max(0, duration)
        var start = max(0, min(fileDuration, min(first, second)))
        var end = max(0, min(fileDuration, max(first, second)))

        if end - start < minimumLength {
            end = min(fileDuration, start + minimumLength)
            if end - start < minimumLength {
                start = max(0, end - minimumLength)
            }
        }

        return LoopRegion(start: start, end: end, isEnabled: true)
    }

    public func clamped(to duration: Double) -> LoopRegion {
        LoopRegion.fromSelection(start, end, duration: duration)
    }
}

