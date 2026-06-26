import Foundation
import TranscribeeCore

@discardableResult
func expect(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if condition() {
        return true
    }

    FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
    failures += 1
    return false
}

nonisolated(unsafe) var failures = 0

func testPitchClassDisplayNamesIncludeFlatKeys() {
    expect(PitchClass.bFlat.displayName == "Bb", "Bb display name")
    expect(PitchClass.dFlat.displayName == "Db", "Db display name")
}

func testTransposeDeltaUsesNearestDirection() {
    expect(PitchClass.c.semitones(to: .bFlat) == -2, "C to Bb is down 2")
    expect(PitchClass.e.semitones(to: .bFlat) == 6, "E to Bb is tritone")
    expect(PitchClass.bFlat.semitones(to: .c) == 2, "Bb to C is up 2")
}

func testTargetKeyTransposeCents() {
    let detected = MusicalKey(root: .c, mode: .major, confidence: 0.92)
    expect(TransposePlan(detectedKey: detected, targetRoot: .bFlat).pitchCents == -200, "C to Bb is -200 cents")
}

func testLoopRegionNormalizesDragDirectionAndMinimumLength() {
    let region = LoopRegion.fromSelection(8.0, 3.0, duration: 10.0)
    expect(abs(region.start - 3.0) < 0.0001, "loop start normalized")
    expect(abs(region.end - 8.0) < 0.0001, "loop end normalized")
    expect(region.isEnabled, "loop enabled by selection")
}

func testLoopRegionClampsTinySelections() {
    let region = LoopRegion.fromSelection(4.0, 4.02, duration: 5.0)
    expect(abs(region.start - 4.0) < 0.0001, "tiny loop start kept")
    expect(abs(region.end - 4.1) < 0.0001, "tiny loop end expanded")
}

func testPracticeSpeedClamp() {
    expect(PracticeSpeed.clamp(0.02) == 0.1, "speed lower bound")
    expect(PracticeSpeed.clamp(1.8) == 1.5, "speed upper bound")
    expect(PracticeSpeed.clamp(0.75) == 0.75, "speed passthrough")
}

func testDetectsMajorKeyFromChromaProfile() {
    let estimate = KeyDetector.detectKey(fromChroma: [
        6.35, 2.23, 3.48, 2.33, 4.38, 4.09,
        2.52, 5.19, 2.39, 3.66, 2.29, 2.88
    ])

    expect(estimate?.root == .c, "C major root")
    expect(estimate?.mode == .major, "C major mode")
}

func testDetectsMinorKeyFromRotatedChromaProfile() {
    let aMinorProfile = KeyDetector.rotatedMinorProfile(root: .a)
    let estimate = KeyDetector.detectKey(fromChroma: aMinorProfile)

    expect(estimate?.root == .a, "A minor root")
    expect(estimate?.mode == .minor, "A minor mode")
}

func testBuildsPythonModuleCommandForPianoStem() {
    let input = URL(fileURLWithPath: "/Users/test/Music/song with spaces.mp3")
    let outputRoot = URL(fileURLWithPath: "/tmp/transcribee-stems")
    let python = URL(fileURLWithPath: "/usr/bin/python3")

    let command = DemucsCommand.pythonModule(
        python,
        input: input,
        outputRoot: outputRoot
    )

    expect(command.executableURL.path == "/usr/bin/python3", "python executable")
    expect(Array(command.arguments.prefix(6)) == ["-m", "demucs", "-n", "htdemucs_6s", "--two-stems", "piano"], "piano command prefix")
    expect(!command.arguments.contains("--other-method"), "compatible PyPI demucs command")
    expect(command.expectedPianoStem.path == "/tmp/transcribee-stems/htdemucs_6s/song with spaces/piano.wav", "expected piano output")
}

testPitchClassDisplayNamesIncludeFlatKeys()
testTransposeDeltaUsesNearestDirection()
testTargetKeyTransposeCents()
testLoopRegionNormalizesDragDirectionAndMinimumLength()
testLoopRegionClampsTinySelections()
testPracticeSpeedClamp()
testDetectsMajorKeyFromChromaProfile()
testDetectsMinorKeyFromRotatedChromaProfile()
testBuildsPythonModuleCommandForPianoStem()

if failures > 0 {
    FileHandle.standardError.write(Data("\(failures) test failure(s)\n".utf8))
    exit(1)
}

print("TranscribeeCoreTests passed")
