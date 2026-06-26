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

func testBuildsMLXCommandForLocalKeysStem() {
    let input = URL(fileURLWithPath: "/Users/test/Music/song with spaces.mp3")
    let outputRoot = URL(fileURLWithPath: "/tmp/transcribee-mlx")
    let modelRoot = URL(fileURLWithPath: "/tmp/transcribee-models")
    let executable = URL(fileURLWithPath: "/opt/homebrew/bin/mlx-audio-separator")

    let command = MLXSeparatorCommand.executable(
        executable,
        input: input,
        outputRoot: outputRoot,
        modelRoot: modelRoot,
        spec: .piano
    )

    expect(command.executableURL.path == "/opt/homebrew/bin/mlx-audio-separator", "mlx executable")
    expect(command.arguments.contains("BS-Roformer-SW.ckpt"), "mlx uses BS-Roformer-SW")
    expect(command.arguments.contains("--single_stem"), "mlx outputs a single stem")
    expect(command.arguments.contains("Piano"), "mlx targets piano stem")
    expect(command.arguments.contains("--custom_output_names"), "mlx uses predictable output names")
    expect(command.arguments.contains("{\"Piano\":\"piano\"}"), "mlx maps piano to stable output")
    expect(command.arguments.contains("latency_safe_v3"), "mlx uses stable fast path")
    expect(command.expectedStem.path == "/tmp/transcribee-mlx/piano.wav", "expected mlx output")
}

func testPracticeStemSpecsUseMLXModels() {
    let specs = MLXStemSpec.practiceSpecs

    expect(specs.map(\.stem) == [.piano, .vocals, .bass, .drums], "practice specs expose core stems")
    expect(specs.allSatisfy { !$0.modelFilename.localizedCaseInsensitiveContains("demucs") }, "practice specs avoid demucs")
    expect(MLXStemSpec.vocals.modelFilename == "vocals_mel_band_roformer.ckpt", "vocals use top local MLX roformer")
    expect(MLXStemSpec.bass.modelFilename == "kuielab_a_bass.onnx", "bass uses MLX MDX bass model")
    expect(MLXStemSpec.drums.modelFilename == "kuielab_b_drums.onnx", "drums use MLX MDX drums model")
}

func testBuildsFFmpegStemMixCommand() {
    let ffmpeg = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
    let inputs = [
        URL(fileURLWithPath: "/tmp/stems/piano.wav"),
        URL(fileURLWithPath: "/tmp/stems/bass.wav")
    ]
    let output = URL(fileURLWithPath: "/tmp/stems/selected-stems.wav")

    let command = FFmpegStemMixCommand.amix(ffmpeg, inputs: inputs, output: output)

    expect(command.executableURL == ffmpeg, "ffmpeg executable")
    expect(command.arguments.filter { $0 == "-i" }.count == 2, "ffmpeg receives each selected stem")
    expect(command.arguments.contains("amix=inputs=2:duration=longest:dropout_transition=0:normalize=0,alimiter=limit=0.95"), "ffmpeg mixes selected stems")
    expect(command.arguments.suffix(2) == ["-y", "/tmp/stems/selected-stems.wav"], "ffmpeg overwrites selected mix")
}

func testMVSepDigitalPianoRequestUsesDigitalPianoAlgorithm() {
    let request = MVSepSeparationRequest.digitalPiano(apiToken: "token-123")

    expect(request.endpoint.absoluteString == "https://mvsep.com/api/separation/create", "mvsep create endpoint")
    expect(request.formFields["api_token"] == "token-123", "mvsep api token")
    expect(request.formFields["sep_type"] == "79", "mvsep digital piano sep type")
    expect(request.formFields["add_opt2"] == "0", "mvsep extracts directly from mix")
    expect(request.formFields["output_format"] == "1", "mvsep wav output")
    expect(request.formFields["is_demo"] == "0", "mvsep private job")
}

func testSlowPlaybackUsesHigherTimePitchOverlap() {
    expect(PlaybackQualitySettings.timePitchOverlap(forSpeed: 1.0, pitchCents: 0) == 8, "normal speed overlap")
    expect(PlaybackQualitySettings.timePitchOverlap(forSpeed: 0.5, pitchCents: 0) >= 24, "slow speed increases overlap")
    expect(PlaybackQualitySettings.timePitchOverlap(forSpeed: 0.1, pitchCents: 0) == 32, "extreme slow speed maxes overlap")
    expect(PlaybackQualitySettings.timePitchOverlap(forSpeed: 1.0, pitchCents: 900) == 32, "large transpose maxes overlap")
}

func testRecentFilesDeduplicateNewestFirstAndCap() {
    var recents = RecentFilesList()

    for index in 0..<12 {
        recents.noteOpened(URL(fileURLWithPath: "/Users/test/song-\(index).wav"), maxCount: 10)
    }
    recents.noteOpened(URL(fileURLWithPath: "/Users/test/song-3.wav"), maxCount: 10)

    expect(recents.entries.count == 10, "recent files capped")
    expect(recents.entries.first?.url.path == "/Users/test/song-3.wav", "duplicate moves to front")
    expect(recents.entries.filter { $0.url.path == "/Users/test/song-3.wav" }.count == 1, "duplicate removed")
    expect(!recents.entries.contains { $0.url.path == "/Users/test/song-0.wav" }, "oldest item dropped")
}

func testStemCacheKeyIsStableForSourcePath() {
    let first = StemCacheKey(sourceURL: URL(fileURLWithPath: "/Users/test/Music/Rose Lesson.wav"))
    let same = StemCacheKey(sourceURL: URL(fileURLWithPath: "/Users/test/Music/Rose Lesson.wav"))
    let different = StemCacheKey(sourceURL: URL(fileURLWithPath: "/Users/test/Music/Other Lesson.wav"))

    expect(first.directoryName == same.directoryName, "same source path reuses stem cache")
    expect(first.directoryName != different.directoryName, "different source path gets different stem cache")
    expect(first.directoryName.hasPrefix("Rose Lesson-"), "cache name keeps readable song base")
    expect(!first.directoryName.contains("/"), "cache name is path safe")
}

func testBuildsYTDLPCommandForYouTubeMP3Download() {
    let executable = URL(fileURLWithPath: "/opt/homebrew/bin/yt-dlp")
    let pageURL = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!
    let outputDirectory = URL(fileURLWithPath: "/Users/test/Library/Application Support/Transcribee/YouTube")

    let command = YouTubeAudioDownloadCommand.ytDLP(
        executable,
        pageURL: pageURL,
        outputDirectory: outputDirectory
    )

    expect(command.executableURL.path == "/opt/homebrew/bin/yt-dlp", "yt-dlp executable")
    expect(command.arguments.contains("--no-playlist"), "yt-dlp avoids playlist downloads")
    expect(command.arguments.contains("--extract-audio"), "yt-dlp extracts audio")
    expect(command.arguments.contains("--audio-format"), "yt-dlp sets audio format")
    expect(command.arguments.contains("mp3"), "yt-dlp downloads mp3")
    expect(command.arguments.contains("--print"), "yt-dlp prints final filepath")
    expect(command.arguments.contains("after_move:filepath"), "yt-dlp prints after conversion")
    expect(command.arguments.contains("/Users/test/Library/Application Support/Transcribee/YouTube"), "yt-dlp writes to app support")
    expect(command.arguments.last == pageURL.absoluteString, "yt-dlp url is final argument")

    let printedOutput = """
    [ExtractAudio] Destination: ignored
    /Users/test/Library/Application Support/Transcribee/YouTube/Rose Piano [abc123].mp3
    """
    expect(
        YouTubeAudioDownloadCommand.downloadedAudioURL(fromOutput: printedOutput)?.path == "/Users/test/Library/Application Support/Transcribee/YouTube/Rose Piano [abc123].mp3",
        "yt-dlp parser finds final mp3"
    )
}

func testPracticeSurfaceCopyUsesPlainMusicianLanguage() {
    let detected = MusicalKey(root: .c, mode: .major, confidence: 0.9)
    let minor = MusicalKey(root: .a, mode: .minor, confidence: 0.9)

    expect(PracticeSurfaceCopy.speedText(0.753) == "0.75x", "speed text rounds plainly")
    expect(PracticeSurfaceCopy.keyText(detectedKey: nil, targetRoot: nil) == "Key: Unknown", "unknown key text")
    expect(PracticeSurfaceCopy.keyText(detectedKey: detected, targetRoot: nil) == "Key: C major", "detected key text")
    expect(PracticeSurfaceCopy.keyText(detectedKey: detected, targetRoot: .bFlat) == "Key: C major -> Bb major", "target major key text")
    expect(PracticeSurfaceCopy.keyText(detectedKey: minor, targetRoot: .bFlat) == "Key: A minor -> Bb minor", "target minor key text")
    expect(PracticeSurfaceCopy.targetKeyText(root: .bFlat, detectedKey: nil) == "Bb", "unknown mode target label")
    expect(PracticeSurfaceCopy.targetKeyText(root: .bFlat, detectedKey: minor) == "Bb minor", "minor mode target label")
    expect(PracticeSurfaceCopy.loopText(nil) == "Loop", "disabled loop text is minimal")
    expect(PracticeSurfaceCopy.loopText(LoopRegion(start: 12, end: 36, isEnabled: true)) == "Loop 0:12-0:36", "enabled loop text is short")
}

func testPracticeWindowLayoutStartsCompactAndExpandsForAudio() {
    let empty = PracticeWindowLayout.metrics(hasAudio: false)
    let loaded = PracticeWindowLayout.metrics(hasAudio: true)

    expect(empty.width == 520, "empty window width is compact")
    expect(empty.height == 190, "empty window height is compact")
    expect(loaded.width == 860, "loaded window width is full practice surface")
    expect(loaded.height == 560, "loaded window height is full practice surface")
}

testPitchClassDisplayNamesIncludeFlatKeys()
testTransposeDeltaUsesNearestDirection()
testTargetKeyTransposeCents()
testLoopRegionNormalizesDragDirectionAndMinimumLength()
testLoopRegionClampsTinySelections()
testPracticeSpeedClamp()
testDetectsMajorKeyFromChromaProfile()
testDetectsMinorKeyFromRotatedChromaProfile()
testBuildsMLXCommandForLocalKeysStem()
testPracticeStemSpecsUseMLXModels()
testBuildsFFmpegStemMixCommand()
testMVSepDigitalPianoRequestUsesDigitalPianoAlgorithm()
testSlowPlaybackUsesHigherTimePitchOverlap()
testRecentFilesDeduplicateNewestFirstAndCap()
testStemCacheKeyIsStableForSourcePath()
testBuildsYTDLPCommandForYouTubeMP3Download()
testPracticeSurfaceCopyUsesPlainMusicianLanguage()
testPracticeWindowLayoutStartsCompactAndExpandsForAudio()

if failures > 0 {
    FileHandle.standardError.write(Data("\(failures) test failure(s)\n".utf8))
    exit(1)
}

print("TranscribeeCoreTests passed")
