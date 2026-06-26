import Foundation

public enum KeyDetector {
    private static let majorProfile = [
        6.35, 2.23, 3.48, 2.33, 4.38, 4.09,
        2.52, 5.19, 2.39, 3.66, 2.29, 2.88
    ]

    private static let minorProfile = [
        6.33, 2.68, 3.52, 5.38, 2.60, 3.53,
        2.54, 4.75, 3.98, 2.69, 3.34, 3.17
    ]

    public static func rotatedMajorProfile(root: PitchClass) -> [Double] {
        rotated(majorProfile, root: root)
    }

    public static func rotatedMinorProfile(root: PitchClass) -> [Double] {
        rotated(minorProfile, root: root)
    }

    public static func detectKey(fromChroma chroma: [Double]) -> MusicalKey? {
        guard chroma.count == 12, chroma.contains(where: { abs($0) > 0.000001 }) else {
            return nil
        }

        var scored: [(key: MusicalKey, score: Double)] = []
        for root in PitchClass.allCases {
            let majorScore = correlation(chroma, rotatedMajorProfile(root: root))
            scored.append((MusicalKey(root: root, mode: .major, confidence: 0), majorScore))

            let minorScore = correlation(chroma, rotatedMinorProfile(root: root))
            scored.append((MusicalKey(root: root, mode: .minor, confidence: 0), minorScore))
        }

        let sorted = scored.sorted { $0.score > $1.score }
        guard let best = sorted.first else {
            return nil
        }

        let second = sorted.dropFirst().first?.score ?? best.score
        let confidence = max(0, min(1, (best.score - second) / max(abs(best.score), 0.000001)))
        return MusicalKey(root: best.key.root, mode: best.key.mode, confidence: confidence)
    }

    public static func detectKey(
        fromMonoSamples samples: [Float],
        sampleRate: Double,
        maxAnalysisSeconds: Double = 90
    ) -> MusicalKey? {
        guard sampleRate > 0, !samples.isEmpty else {
            return nil
        }

        let targetRate = 11_025.0
        let stride = max(1, Int(sampleRate / targetRate))
        let effectiveRate = sampleRate / Double(stride)
        let maxSamples = Int(maxAnalysisSeconds * effectiveRate)
        var downsampled: [Double] = []
        downsampled.reserveCapacity(min(samples.count / stride, maxSamples))

        var index = 0
        while index < samples.count, downsampled.count < maxSamples {
            downsampled.append(Double(samples[index]))
            index += stride
        }

        guard downsampled.count >= 1_024 else {
            return nil
        }

        let chroma = chromaVector(from: downsampled, sampleRate: effectiveRate)
        return detectKey(fromChroma: chroma)
    }

    private static func chromaVector(from samples: [Double], sampleRate: Double) -> [Double] {
        let frameSize = min(4_096, samples.count)
        let hop = max(512, frameSize / 2)
        let maxFrames = 120
        let window = hannWindow(count: frameSize)
        var chroma = Array(repeating: 0.0, count: 12)
        var frameStart = 0
        var frameCount = 0

        while frameStart + frameSize <= samples.count, frameCount < maxFrames {
            let frame = samples[frameStart..<(frameStart + frameSize)]
            let rms = sqrt(frame.reduce(0.0) { $0 + $1 * $1 } / Double(frameSize))
            if rms > 0.0005 {
                for midi in 36...84 {
                    let frequency = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
                    let power = goertzelPower(frame: frame, window: window, frequency: frequency, sampleRate: sampleRate)
                    chroma[midi % 12] += log1p(power)
                }
            }

            frameStart += hop
            frameCount += 1
        }

        return chroma
    }

    private static func rotated(_ profile: [Double], root: PitchClass) -> [Double] {
        var result = Array(repeating: 0.0, count: 12)
        for index in 0..<12 {
            result[(index + root.rawValue) % 12] = profile[index]
        }
        return result
    }

    private static func correlation(_ left: [Double], _ right: [Double]) -> Double {
        let leftMean = left.reduce(0, +) / Double(left.count)
        let rightMean = right.reduce(0, +) / Double(right.count)
        var numerator = 0.0
        var leftDenominator = 0.0
        var rightDenominator = 0.0

        for index in 0..<left.count {
            let l = left[index] - leftMean
            let r = right[index] - rightMean
            numerator += l * r
            leftDenominator += l * l
            rightDenominator += r * r
        }

        let denominator = sqrt(leftDenominator * rightDenominator)
        guard denominator > 0 else {
            return 0
        }
        return numerator / denominator
    }

    private static func hannWindow(count: Int) -> [Double] {
        guard count > 1 else {
            return [1]
        }
        return (0..<count).map { index in
            0.5 - 0.5 * cos((2.0 * Double.pi * Double(index)) / Double(count - 1))
        }
    }

    private static func goertzelPower(
        frame: ArraySlice<Double>,
        window: [Double],
        frequency: Double,
        sampleRate: Double
    ) -> Double {
        let omega = 2.0 * Double.pi * frequency / sampleRate
        let coefficient = 2.0 * cos(omega)
        var q1 = 0.0
        var q2 = 0.0
        var windowIndex = 0

        for sample in frame {
            let q0 = coefficient * q1 - q2 + sample * window[windowIndex]
            q2 = q1
            q1 = q0
            windowIndex += 1
        }

        return q1 * q1 + q2 * q2 - coefficient * q1 * q2
    }
}

