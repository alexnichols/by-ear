import Foundation

public enum PlaybackQualitySettings {
    public static func timePitchOverlap(forSpeed speed: Double, pitchCents: Int) -> Float {
        let clampedSpeed = PracticeSpeed.clamp(speed)
        let absolutePitchCents = abs(pitchCents)

        if clampedSpeed <= 0.35 || absolutePitchCents >= 700 {
            return 32
        }

        if clampedSpeed <= 0.5 || absolutePitchCents >= 400 {
            return 28
        }

        if clampedSpeed <= 0.75 || absolutePitchCents >= 200 {
            return 20
        }

        if clampedSpeed < 0.95 {
            return 12
        }

        return 8
    }
}
