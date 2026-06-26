import Foundation

public enum PracticeSurfaceCopy {
    public static func speedText(_ speed: Double) -> String {
        String(format: "%.2fx", PracticeSpeed.clamp(speed))
    }

    public static func keyText(detectedKey: MusicalKey?, targetRoot: PitchClass?) -> String {
        guard let detectedKey else {
            return "Key: Unknown"
        }

        guard let targetRoot else {
            return "Key: \(detectedKey.displayName)"
        }

        return "Key: \(detectedKey.displayName) -> \(targetKeyText(root: targetRoot, detectedKey: detectedKey))"
    }

    public static func targetKeyText(root: PitchClass, detectedKey: MusicalKey?) -> String {
        guard let mode = detectedKey?.mode else {
            return root.displayName
        }

        return "\(root.displayName) \(mode.displayName)"
    }

    public static func loopText(_ loopRegion: LoopRegion?) -> String {
        guard let loopRegion, loopRegion.isEnabled else {
            return "Loop"
        }

        return "Loop \(formatTime(loopRegion.start))-\(formatTime(loopRegion.end))"
    }

    private static func formatTime(_ value: Double) -> String {
        guard value.isFinite else {
            return "0:00"
        }

        let seconds = max(0, Int(value.rounded()))
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}
