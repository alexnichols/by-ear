@preconcurrency import AVFoundation
import SwiftUI
import TranscribeeCore
import UniformTypeIdentifiers

private let supportedAudioTypes: [UTType] = [
    .audio,
    .mp3,
    .wav,
    .aiff,
    .mpeg4Audio,
    UTType(filenameExtension: "flac") ?? .audio
]

@main
struct TranscribeeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 860, minHeight: 560)
        }
    }
}

private struct ContentView: View {
    @StateObject private var model = PracticePlayerModel()
    @State private var isImporterPresented = false
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            VStack(spacing: 18) {
                WaveformView(
                    peaks: model.waveformPeaks,
                    duration: model.duration,
                    currentTime: model.currentTime,
                    loopRegion: model.loopRegion,
                    isDropTargeted: isDropTargeted,
                    onSeek: model.seek(to:),
                    onSelectLoop: model.setLoopSelection(start:end:)
                )
                .frame(minHeight: 210)
                .padding(.top, 8)

                transport
                loopControls
                analysisControls
                demucsControls

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: supportedAudioTypes,
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                model.load(url)
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            openDroppedFile(from: providers)
        }
        .onReceive(Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()) { _ in
            model.tickPlayback()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                isImporterPresented = true
            } label: {
                Label("Open Audio", systemImage: "folder")
            }
            .keyboardShortcut("o", modifiers: [.command])

            VStack(alignment: .leading, spacing: 2) {
                Text(model.loadedFileName)
                    .font(.headline)
                    .lineLimit(1)

                Text(model.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(timeRangeText)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var transport: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    model.seekRelative(-5)
                } label: {
                    Label("Back 5s", systemImage: "gobackward.5")
                }
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button {
                    model.seekRelative(-1)
                } label: {
                    Label("Back 1s", systemImage: "backward.end.alt")
                }
                .keyboardShortcut(.leftArrow, modifiers: [.shift])

                Button {
                    model.togglePlayback()
                } label: {
                    Label(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill")
                        .frame(minWidth: 92)
                }
                .keyboardShortcut(.space, modifiers: [])

                Button {
                    model.seekRelative(1)
                } label: {
                    Label("Forward 1s", systemImage: "forward.end.alt")
                }
                .keyboardShortcut(.rightArrow, modifiers: [.shift])

                Button {
                    model.seekRelative(5)
                } label: {
                    Label("Forward 5s", systemImage: "goforward.5")
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
            }

            HStack(spacing: 12) {
                Button {
                    model.stepSpeed(-0.01)
                } label: {
                    Label("Slower", systemImage: "minus")
                }
                .keyboardShortcut("-", modifiers: [])

                Slider(
                    value: Binding(
                        get: { model.speed },
                        set: { model.setSpeed($0) }
                    ),
                    in: PracticeSpeed.minimum...PracticeSpeed.maximum
                )
                .frame(maxWidth: 360)

                Button {
                    model.stepSpeed(0.01)
                } label: {
                    Label("Faster", systemImage: "plus")
                }
                .keyboardShortcut("+", modifiers: [])

                Text("\(model.speed, specifier: "%.2f")x")
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 56, alignment: .trailing)
            }
        }
    }

    private var loopControls: some View {
        HStack(spacing: 10) {
            Button {
                model.setLoopStartAtCurrentTime()
            } label: {
                Label("Set A", systemImage: "a.circle")
            }
            .keyboardShortcut("[", modifiers: [])

            Button {
                model.setLoopEndAtCurrentTime()
            } label: {
                Label("Set B", systemImage: "b.circle")
            }
            .keyboardShortcut("]", modifiers: [])

            Button {
                model.toggleLoop()
            } label: {
                Label(model.loopRegion?.isEnabled == true ? "Disable Loop" : "Enable Loop", systemImage: "repeat")
            }
            .keyboardShortcut("l", modifiers: [])

            Button(role: .destructive) {
                model.clearLoop()
            } label: {
                Label("Clear", systemImage: "xmark.circle")
            }

            Spacer()

            Text(model.loopDescription)
                .foregroundStyle(.secondary)
        }
    }

    private var analysisControls: some View {
        HStack(spacing: 12) {
            Label(model.detectedKeyText, systemImage: "music.quarternote.3")

            Picker("Target", selection: Binding(get: { model.targetRoot }, set: { model.setTargetRoot($0) })) {
                Text("No transpose").tag(PitchClass?.none)
                ForEach(PitchClass.allCases) { pitchClass in
                    Text(pitchClass.displayName).tag(PitchClass?.some(pitchClass))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)

            Text("Pitch \(model.pitchCents) cents")
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var demucsControls: some View {
        HStack(spacing: 10) {
            Button {
                model.isolatePiano()
            } label: {
                Label(model.isIsolating ? "Isolating..." : "Isolate Piano", systemImage: "pianokeys")
            }
            .disabled(model.isIsolating || model.currentSourceURL == nil)

            Button {
                model.installDemucs()
            } label: {
                Label(model.isInstallingDemucs ? "Installing..." : "Install Demucs", systemImage: "arrow.down.circle")
            }
            .disabled(model.isInstallingDemucs)

            Spacer()
        }
    }

    private var timeRangeText: String {
        "\(PracticePlayerModel.formatTime(model.currentTime)) / \(PracticePlayerModel.formatTime(model.duration))"
    }

    private func openDroppedFile(from providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let itemURL = item as? URL {
                url = itemURL
            } else if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = nil
            }

            if let url {
                Task { @MainActor in
                    model.load(url)
                }
            }
        }
        return true
    }
}

private struct WaveformView: View {
    let peaks: [Float]
    let duration: Double
    let currentTime: Double
    let loopRegion: LoopRegion?
    let isDropTargeted: Bool
    let onSeek: (Double) -> Void
    let onSelectLoop: (Double, Double) -> Void

    @State private var dragStartX: CGFloat?
    @State private var dragCurrentX: CGFloat?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDropTargeted ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))

                Canvas { context, size in
                    drawWaveform(in: &context, size: size)
                    drawLoop(in: &context, size: size)
                    drawSelection(in: &context, size: size)
                    drawPlayhead(in: &context, size: size)
                }
                .padding(1)

                if peaks.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "waveform")
                            .font(.system(size: 42))
                            .foregroundStyle(.secondary)
                        Text("No audio")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStartX == nil {
                            dragStartX = clampedX(value.startLocation.x, width: proxy.size.width)
                        }
                        dragCurrentX = clampedX(value.location.x, width: proxy.size.width)
                    }
                    .onEnded { value in
                        let start = seconds(for: dragStartX ?? value.startLocation.x, width: proxy.size.width)
                        let end = seconds(for: value.location.x, width: proxy.size.width)

                        if abs((dragStartX ?? value.startLocation.x) - value.location.x) < 3 {
                            onSeek(end)
                        } else {
                            onSelectLoop(start, end)
                        }

                        dragStartX = nil
                        dragCurrentX = nil
                    }
            )
        }
    }

    private func drawWaveform(in context: inout GraphicsContext, size: CGSize) {
        guard !peaks.isEmpty else {
            return
        }

        let centerY = size.height / 2
        let widthPerPeak = max(1, size.width / CGFloat(peaks.count))
        var path = Path()

        for index in peaks.indices {
            let peak = CGFloat(min(1, max(0, peaks[index])))
            let height = max(1, peak * size.height * 0.88)
            let x = CGFloat(index) * widthPerPeak
            path.move(to: CGPoint(x: x, y: centerY - height / 2))
            path.addLine(to: CGPoint(x: x, y: centerY + height / 2))
        }

        context.stroke(path, with: .color(.primary.opacity(0.78)), lineWidth: max(1, min(2, widthPerPeak)))
    }

    private func drawLoop(in context: inout GraphicsContext, size: CGSize) {
        guard let loopRegion, duration > 0 else {
            return
        }

        let startX = CGFloat(loopRegion.start / duration) * size.width
        let endX = CGFloat(loopRegion.end / duration) * size.width
        let rect = CGRect(x: min(startX, endX), y: 0, width: abs(endX - startX), height: size.height)
        context.fill(Path(rect), with: .color(.accentColor.opacity(loopRegion.isEnabled ? 0.18 : 0.08)))
        context.stroke(Path(rect), with: .color(.accentColor.opacity(loopRegion.isEnabled ? 0.72 : 0.35)), lineWidth: 1)
    }

    private func drawSelection(in context: inout GraphicsContext, size: CGSize) {
        guard let dragStartX, let dragCurrentX, abs(dragStartX - dragCurrentX) >= 3 else {
            return
        }

        let rect = CGRect(
            x: min(dragStartX, dragCurrentX),
            y: 0,
            width: abs(dragStartX - dragCurrentX),
            height: size.height
        )
        context.fill(Path(rect), with: .color(.yellow.opacity(0.24)))
    }

    private func drawPlayhead(in context: inout GraphicsContext, size: CGSize) {
        guard duration > 0 else {
            return
        }

        let x = CGFloat(currentTime / duration) * size.width
        var path = Path()
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: size.height))
        context.stroke(path, with: .color(.red), lineWidth: 2)
    }

    private func clampedX(_ x: CGFloat, width: CGFloat) -> CGFloat {
        min(max(0, x), max(0, width))
    }

    private func seconds(for x: CGFloat, width: CGFloat) -> Double {
        guard duration > 0, width > 0 else {
            return 0
        }
        return Double(clampedX(x, width: width) / width) * duration
    }
}

@MainActor
private final class PracticePlayerModel: ObservableObject {
    @Published var loadedFileName = "No audio loaded"
    @Published var statusText = "Ready"
    @Published var waveformPeaks: [Float] = []
    @Published var duration = 0.0
    @Published var currentTime = 0.0
    @Published var isPlaying = false
    @Published var speed = 1.0
    @Published var detectedKey: MusicalKey?
    @Published var targetRoot: PitchClass?
    @Published var loopRegion: LoopRegion?
    @Published var isInstallingDemucs = false
    @Published var isIsolating = false

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private var playbackFile: AVAudioFile?
    private var playbackSampleRate = 44_100.0
    private var playbackAnchorTime = 0.0
    private var playbackAnchorDate: Date?
    private var originalAudioURL: URL?
    private var displayedAudioURL: URL?
    private var pendingLoopStart: Double?

    var currentSourceURL: URL? {
        originalAudioURL
    }

    var detectedKeyText: String {
        guard let detectedKey else {
            return "Detected key: Unknown"
        }
        return "Detected key: \(detectedKey.displayName)"
    }

    var pitchCents: Int {
        TransposePlan(detectedKey: detectedKey, targetRoot: targetRoot).pitchCents
    }

    var loopDescription: String {
        guard let loopRegion else {
            return "Loop: none"
        }

        let enabled = loopRegion.isEnabled ? "on" : "off"
        return "Loop \(enabled): \(Self.formatTime(loopRegion.start)) - \(Self.formatTime(loopRegion.end))"
    }

    init() {
        engine.attach(player)
        engine.attach(timePitch)
        timePitch.rate = Float(speed)
        timePitch.pitch = 0
    }

    func load(_ url: URL) {
        loadAudio(url, preserveOriginalSource: false)
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard let playbackFile else {
            statusText = "Open an audio file first."
            return
        }

        if currentTime >= duration {
            currentTime = loopRegion?.isEnabled == true ? loopRegion?.start ?? 0 : 0
        }

        if let loopRegion, loopRegion.isEnabled, !loopRegion.contains(currentTime) {
            currentTime = loopRegion.start
        }

        do {
            try ensureEngineStarted(for: playbackFile)
            schedulePlayback(from: currentTime)
            player.play()
            playbackAnchorTime = currentTime
            playbackAnchorDate = Date()
            isPlaying = true
            statusText = "Playing \(loadedFileName)"
        } catch {
            isPlaying = false
            statusText = "Playback failed: \(error.localizedDescription)"
        }
    }

    func pause() {
        guard isPlaying else {
            return
        }
        currentTime = effectivePlaybackTime()
        player.stop()
        playbackAnchorDate = nil
        isPlaying = false
        statusText = "Paused"
    }

    func seek(to time: Double) {
        currentTime = clampedTime(time)
        if isPlaying {
            player.stop()
            play()
        }
    }

    func seekRelative(_ delta: Double) {
        seek(to: currentTime + delta)
    }

    func setSpeed(_ value: Double) {
        let clamped = PracticeSpeed.clamp(value)
        if isPlaying {
            currentTime = effectivePlaybackTime()
            playbackAnchorTime = currentTime
            playbackAnchorDate = Date()
        }
        speed = clamped
        timePitch.rate = Float(clamped)
    }

    func stepSpeed(_ delta: Double) {
        setSpeed(speed + delta)
    }

    func setTargetRoot(_ root: PitchClass?) {
        targetRoot = root
        timePitch.pitch = Float(pitchCents)
    }

    func setLoopSelection(start: Double, end: Double) {
        guard duration > 0 else {
            return
        }
        loopRegion = LoopRegion.fromSelection(start, end, duration: duration)
        pendingLoopStart = nil
        if isPlaying, let loopRegion, !loopRegion.contains(currentTime) {
            seek(to: loopRegion.start)
        }
    }

    func setLoopStartAtCurrentTime() {
        pendingLoopStart = currentTime
        if let loopRegion {
            self.loopRegion = LoopRegion.fromSelection(currentTime, loopRegion.end, duration: duration)
        } else {
            statusText = "Loop start set at \(Self.formatTime(currentTime))"
        }
    }

    func setLoopEndAtCurrentTime() {
        let start = pendingLoopStart ?? loopRegion?.start ?? 0
        setLoopSelection(start: start, end: currentTime)
    }

    func toggleLoop() {
        guard var loopRegion else {
            setLoopSelection(start: currentTime, end: min(duration, currentTime + 8))
            return
        }
        loopRegion.isEnabled.toggle()
        self.loopRegion = loopRegion
    }

    func clearLoop() {
        loopRegion = nil
        pendingLoopStart = nil
    }

    func installDemucs() {
        guard !isInstallingDemucs else {
            return
        }

        isInstallingDemucs = true
        statusText = "Installing Demucs into \(demucsVenvURL.path)"

        Task {
            do {
                try FileManager.default.createDirectory(
                    at: demucsVenvURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try await DemucsInstaller.install(into: demucsVenvURL)
                isInstallingDemucs = false
                statusText = "Demucs installed locally."
            } catch {
                isInstallingDemucs = false
                statusText = "Demucs install failed: \(error.localizedDescription)"
            }
        }
    }

    func isolatePiano() {
        guard !isIsolating else {
            return
        }
        guard let input = originalAudioURL else {
            statusText = "Open an audio file before isolating piano."
            return
        }
        guard let command = demucsCommand(input: input) else {
            statusText = "Install Demucs first, or put demucs on PATH."
            return
        }

        isIsolating = true
        statusText = "Running local Demucs piano isolation..."

        Task {
            do {
                try FileManager.default.createDirectory(at: demucsOutputRootURL, withIntermediateDirectories: true)
                _ = try await ProcessRunner.run(command.executableURL, arguments: command.arguments)

                guard FileManager.default.fileExists(atPath: command.expectedPianoStem.path) else {
                    throw AppProcessError.failed("Demucs finished but did not create \(command.expectedPianoStem.path)")
                }

                isIsolating = false
                loadAudio(command.expectedPianoStem, preserveOriginalSource: true)
                statusText = "Loaded isolated piano stem."
            } catch {
                isIsolating = false
                statusText = "Piano isolation failed: \(error.localizedDescription)"
            }
        }
    }

    private func loadAudio(_ url: URL, preserveOriginalSource: Bool) {
        let didStartSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didStartSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            pause()
            engine.stop()
            engine.reset()
            let analysis = try AudioAnalysis.decode(url)
            playbackFile = try AVAudioFile(forReading: url)
            playbackSampleRate = analysis.sampleRate
            displayedAudioURL = url
            if !preserveOriginalSource {
                originalAudioURL = url
            }
            loadedFileName = url.lastPathComponent
            waveformPeaks = analysis.peaks
            duration = analysis.duration
            currentTime = 0
            loopRegion = nil
            pendingLoopStart = nil
            detectedKey = KeyDetector.detectKey(fromMonoSamples: analysis.monoSamples, sampleRate: analysis.sampleRate)
            timePitch.pitch = Float(pitchCents)
            statusText = "Loaded \(url.lastPathComponent)"
        } catch {
            statusText = "Could not open \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    private func ensureEngineStarted(for file: AVAudioFile) throws {
        if engine.isRunning {
            return
        }

        engine.disconnectNodeInput(timePitch)
        engine.disconnectNodeOutput(timePitch)
        engine.connect(player, to: timePitch, format: file.processingFormat)
        engine.connect(timePitch, to: engine.mainMixerNode, format: file.processingFormat)
        engine.prepare()
        try engine.start()
    }

    private func schedulePlayback(from time: Double) {
        guard let playbackFile else {
            return
        }

        let startFrame = AVAudioFramePosition(clampedTime(time) * playbackSampleRate)
        let frameCount = min(max(0, playbackFile.length - startFrame), AVAudioFramePosition(UInt32.max))
        player.scheduleSegment(playbackFile, startingFrame: startFrame, frameCount: AVAudioFrameCount(frameCount), at: nil)
    }

    func tickPlayback() {
        guard isPlaying else {
            return
        }

        let nextTime = effectivePlaybackTime()
        currentTime = clampedTime(nextTime)

        if let loopRegion, loopRegion.isEnabled, currentTime >= loopRegion.end {
            seek(to: loopRegion.start)
            return
        }

        if currentTime >= duration {
            player.stop()
            currentTime = duration
            playbackAnchorDate = nil
            isPlaying = false
            statusText = "Reached end."
        }
    }

    private func effectivePlaybackTime() -> Double {
        guard let playbackAnchorDate else {
            return currentTime
        }
        return playbackAnchorTime + Date().timeIntervalSince(playbackAnchorDate) * speed
    }

    private func clampedTime(_ time: Double) -> Double {
        min(max(0, time), max(0, duration))
    }

    private var demucsVenvURL: URL {
        appSupportURL
            .appendingPathComponent("demucs-venv", isDirectory: true)
    }

    private var demucsOutputRootURL: URL {
        appSupportURL.appendingPathComponent("Stems", isDirectory: true)
    }

    private var appSupportURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Transcribee", isDirectory: true)
    }

    private func demucsCommand(input: URL) -> DemucsCommand? {
        let venvDemucs = demucsVenvURL.appendingPathComponent("bin/demucs")
        if FileManager.default.isExecutableFile(atPath: venvDemucs.path) {
            return .executable(venvDemucs, input: input, outputRoot: demucsOutputRootURL)
        }

        let venvPython = demucsVenvURL.appendingPathComponent("bin/python")
        if FileManager.default.isExecutableFile(atPath: venvPython.path) {
            return .pythonModule(venvPython, input: input, outputRoot: demucsOutputRootURL)
        }

        if let demucs = ProcessRunner.findExecutable("demucs") {
            return .executable(demucs, input: input, outputRoot: demucsOutputRootURL)
        }

        return nil
    }

    static func formatTime(_ value: Double) -> String {
        guard value.isFinite else {
            return "0:00"
        }

        let seconds = max(0, Int(value.rounded()))
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

private struct AudioAnalysis {
    let peaks: [Float]
    let monoSamples: [Float]
    let sampleRate: Double
    let duration: Double

    static func decode(_ url: URL) throws -> AudioAnalysis {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let channelCount = Int(format.channelCount)
        let totalFrames = max(0, file.length)
        let duration = sampleRate > 0 ? Double(totalFrames) / sampleRate : 0
        let peakCount = max(256, min(4_000, Int(max(1, duration) * 80)))
        var peaks = Array(repeating: Float(0), count: peakCount)
        let maxKeySamples = Int(sampleRate * 90)
        var monoSamples: [Float] = []
        monoSamples.reserveCapacity(min(Int(min(totalFrames, AVAudioFramePosition(maxKeySamples))), maxKeySamples))

        let chunkCapacity: AVAudioFrameCount = 8_192
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkCapacity) else {
            throw AppProcessError.failed("Could not allocate decode buffer.")
        }

        var absoluteFrame: AVAudioFramePosition = 0
        while absoluteFrame < totalFrames {
            let framesToRead = min(chunkCapacity, AVAudioFrameCount(totalFrames - absoluteFrame))
            try file.read(into: buffer, frameCount: framesToRead)
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else {
                break
            }
            guard let channelData = buffer.floatChannelData else {
                throw AppProcessError.failed("Decoded audio is not float PCM.")
            }

            for frameIndex in 0..<frameLength {
                var sample = Float(0)
                for channelIndex in 0..<channelCount {
                    sample += channelData[channelIndex][frameIndex]
                }
                sample /= Float(max(1, channelCount))

                if monoSamples.count < maxKeySamples {
                    monoSamples.append(sample)
                }

                let peakIndex = peakCount > 0 && totalFrames > 0
                    ? min(peakCount - 1, Int((absoluteFrame + AVAudioFramePosition(frameIndex)) * AVAudioFramePosition(peakCount) / totalFrames))
                    : 0
                peaks[peakIndex] = max(peaks[peakIndex], abs(sample))
            }

            absoluteFrame += AVAudioFramePosition(frameLength)
        }

        let maximumPeak = peaks.max() ?? 0
        if maximumPeak > 0 {
            peaks = peaks.map { min(1, $0 / maximumPeak) }
        }

        return AudioAnalysis(peaks: peaks, monoSamples: monoSamples, sampleRate: sampleRate, duration: duration)
    }
}

private enum DemucsInstaller {
    static func install(into venvURL: URL) async throws {
        if let uv = ProcessRunner.findExecutable("uv") {
            try await installWithUV(uv, venvURL: venvURL)
            return
        }

        guard let python = ProcessRunner.findExecutable("python3.11") ?? ProcessRunner.findExecutable("python3.12") else {
            throw AppProcessError.failed("Could not find uv, python3.11, or python3.12 on PATH.")
        }

        try await ProcessRunner.run(python, arguments: ["-m", "venv", venvURL.path])
        let venvPython = venvURL.appendingPathComponent("bin/python")
        try await ProcessRunner.run(venvPython, arguments: ["-m", "pip", "install", "--upgrade", "pip"])
        try await ProcessRunner.run(venvPython, arguments: ["-m", "pip", "install", "demucs", "torchcodec"])
    }

    private static func installWithUV(_ uv: URL, venvURL: URL) async throws {
        do {
            try await ProcessRunner.run(uv, arguments: ["venv", "--allow-existing", "--python", "3.11", venvURL.path])
        } catch {
            try await ProcessRunner.run(uv, arguments: ["venv", "--allow-existing", "--python", "3.12", venvURL.path])
        }

        let venvPython = venvURL.appendingPathComponent("bin/python")
        try await ProcessRunner.run(uv, arguments: ["pip", "install", "--python", venvPython.path, "demucs", "torchcodec"])
    }
}

private enum AppProcessError: LocalizedError, Sendable {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message):
            message
        }
    }
}

private enum ProcessRunner {
    static func findExecutable(_ name: String) -> URL? {
        let environment = ProcessInfo.processInfo.environment
        let configuredPaths = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        let fallbackPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        var paths: [String] = []

        for path in configuredPaths + fallbackPaths where !paths.contains(path) {
            paths.append(path)
        }

        for path in paths {
            let candidate = URL(fileURLWithPath: path).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }

    @discardableResult
    static func run(_ executable: URL, arguments: [String]) async throws -> String {
        try await Task.detached(priority: .utility) {
            let captureDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("Transcribee-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: captureDirectory, withIntermediateDirectories: true)
            defer {
                try? FileManager.default.removeItem(at: captureDirectory)
            }

            let outputURL = captureDirectory.appendingPathComponent("stdout.txt")
            let errorURL = captureDirectory.appendingPathComponent("stderr.txt")
            FileManager.default.createFile(atPath: outputURL.path, contents: nil)
            FileManager.default.createFile(atPath: errorURL.path, contents: nil)

            let outputHandle = try FileHandle(forWritingTo: outputURL)
            let errorHandle = try FileHandle(forWritingTo: errorURL)
            defer {
                try? outputHandle.close()
                try? errorHandle.close()
            }

            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = outputHandle
            process.standardError = errorHandle

            try process.run()
            process.waitUntilExit()

            let outputData = try Data(contentsOf: outputURL)
            let errorData = try Data(contentsOf: errorURL)
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""

            guard process.terminationStatus == 0 else {
                let detail = [output, error]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                throw AppProcessError.failed(detail.isEmpty ? "Process exited \(process.terminationStatus)." : detail)
            }

            return output
        }.value
    }
}

private extension LoopRegion {
    func contains(_ time: Double) -> Bool {
        time >= start && time <= end
    }
}
