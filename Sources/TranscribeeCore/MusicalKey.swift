import Foundation

public enum PitchClass: Int, CaseIterable, Identifiable, Sendable {
    case c = 0
    case dFlat = 1
    case d = 2
    case eFlat = 3
    case e = 4
    case f = 5
    case gFlat = 6
    case g = 7
    case aFlat = 8
    case a = 9
    case bFlat = 10
    case b = 11

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .c: "C"
        case .dFlat: "Db"
        case .d: "D"
        case .eFlat: "Eb"
        case .e: "E"
        case .f: "F"
        case .gFlat: "Gb"
        case .g: "G"
        case .aFlat: "Ab"
        case .a: "A"
        case .bFlat: "Bb"
        case .b: "B"
        }
    }

    public func semitones(to target: PitchClass) -> Int {
        let rawDelta = target.rawValue - rawValue
        if rawDelta > 6 {
            return rawDelta - 12
        }
        if rawDelta < -6 {
            return rawDelta + 12
        }
        return rawDelta
    }
}

public enum KeyMode: String, CaseIterable, Identifiable, Sendable {
    case major
    case minor

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .major: "major"
        case .minor: "minor"
        }
    }
}

public struct MusicalKey: Equatable, Sendable {
    public let root: PitchClass
    public let mode: KeyMode
    public let confidence: Double

    public init(root: PitchClass, mode: KeyMode, confidence: Double) {
        self.root = root
        self.mode = mode
        self.confidence = confidence
    }

    public var displayName: String {
        "\(root.displayName) \(mode.displayName)"
    }
}

public struct TransposePlan: Equatable, Sendable {
    public let detectedKey: MusicalKey?
    public let targetRoot: PitchClass?

    public init(detectedKey: MusicalKey?, targetRoot: PitchClass?) {
        self.detectedKey = detectedKey
        self.targetRoot = targetRoot
    }

    public var semitones: Int {
        guard let detectedKey, let targetRoot else {
            return 0
        }
        return detectedKey.root.semitones(to: targetRoot)
    }

    public var pitchCents: Int {
        semitones * 100
    }
}

