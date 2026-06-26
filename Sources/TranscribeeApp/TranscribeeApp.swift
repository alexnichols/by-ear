@preconcurrency import AVFoundation
import AppKit
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

private let titlebarControlPadding: CGFloat = 76

@main
struct TranscribeeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(
            width: PracticeWindowLayout.metrics(hasAudio: false).width,
            height: PracticeWindowLayout.metrics(hasAudio: false).height
        )
    }
}

private struct ContentView: View {
    @StateObject private var model = PracticePlayerModel()
    @State private var isImporterPresented = false
    @State private var isDropTargeted = false
    @State private var isYouTubeSheetPresented = false
    @State private var isAdvancedSheetPresented = false
    @State private var youtubeURLString = ""
    @AppStorage("mvsepApiToken") private var mvsepApiToken = ""

    var body: some View {
        let metrics = PracticeWindowLayout.metrics(hasAudio: model.hasAudio)

        Group {
            if model.hasAudio {
                practiceSurface
            } else {
                emptySurface
            }
        }
        .frame(minWidth: metrics.width, minHeight: metrics.height)
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            model.discardUnsavedGeneratedStem()
        }
        .onDisappear {
            model.discardUnsavedGeneratedStem()
        }
        .onChange(of: model.hasAudio) { _, hasAudio in
            resizeWindow(hasAudio: hasAudio)
        }
        .sheet(isPresented: $isYouTubeSheetPresented) {
            youtubeSheet
        }
        .sheet(isPresented: $isAdvancedSheetPresented) {
            advancedSheet
        }
    }

    private var practiceSurface: some View {
        VStack(spacing: 0) {
            header

            Divider()

            VStack(spacing: 24) {
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

                if model.currentSourceURL != nil || model.canSaveGeneratedStem {
                    contextualActions
                }

                transport
                keyControls

                Spacer(minLength: 0)
            }
            .padding(24)
        }
    }

    private var emptySurface: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                openMenu
                    .controlSize(.large)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ready to practice")
                        .font(.headline)
                    Text(model.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                advancedButton
            }
            .padding(.top, 18)
            .padding(.horizontal, 20)
            .padding(.leading, titlebarControlPadding)

            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    Image(systemName: "waveform")
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(.secondary.opacity(0.75))
                }
                .frame(height: 72)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            openMenu

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

            advancedButton
        }
        .padding(.trailing, 20)
        .padding(.leading, titlebarControlPadding + 20)
        .padding(.vertical, 14)
    }

    private var openMenu: some View {
        Menu {
            Button {
                isImporterPresented = true
            } label: {
                Label("Audio File", systemImage: "folder")
            }
            .keyboardShortcut("o", modifiers: [.command])

            Button {
                isYouTubeSheetPresented = true
            } label: {
                Label("YouTube Link", systemImage: "link")
            }

            Divider()

            if model.recentAudioItems.isEmpty {
                Text("No Recents")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.recentAudioItems) { item in
                    Button {
                        model.openRecent(item)
                    } label: {
                        Label(item.displayName, systemImage: "music.note")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    model.clearRecents()
                } label: {
                    Label("Clear Recents", systemImage: "trash")
                }
            }
        } label: {
            Label("Open", systemImage: "folder")
        }
        .menuStyle(.button)
    }

    private var advancedButton: some View {
        Button {
            isAdvancedSheetPresented = true
        } label: {
            Label("Advanced", systemImage: "slider.horizontal.3")
                .labelStyle(.iconOnly)
        }
        .help("Advanced")
    }

    private var contextualActions: some View {
        HStack(spacing: 10) {
            if !model.generatedStemOptions.isEmpty {
                Label("Stems", systemImage: "slider.horizontal.3")
                    .foregroundStyle(.secondary)

                ForEach($model.generatedStemOptions) { $option in
                    Toggle(option.stem.displayName, isOn: $option.isIncluded)
                        .toggleStyle(.checkbox)
                }

                Button {
                    model.applySelectedStemMix()
                } label: {
                    Label(model.isMixingStems ? "Mixing..." : "Use", systemImage: "checkmark")
                }
                .disabled(model.isStemWorkRunning || !model.hasSelectedGeneratedStems)

                stemSaveButtons
            } else if model.canSaveGeneratedStem {
                Label("Stem mix ready", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)

                stemSaveButtons
            } else if model.currentSourceURL != nil {
                Button {
                    model.separatePracticeStems()
                } label: {
                    Label(model.isIsolating ? "Separating..." : "Separate Stems", systemImage: "waveform.badge.magnifyingglass")
                }
                .disabled(model.isStemWorkRunning)
            }

            Spacer()
        }
        .frame(minHeight: 32)
    }

    private var stemSaveButtons: some View {
        Group {
            if model.canSaveGeneratedStem {
                Button {
                    model.saveGeneratedStem()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: [.command])

                Button(role: .destructive) {
                    model.discardGeneratedStemAndRestoreSource()
                } label: {
                    Label("Discard", systemImage: "trash")
                }
            }
        }
    }

    private var transport: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Button {
                    model.seekRelative(-5)
                } label: {
                    Label("5s", systemImage: "gobackward.5")
                }
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button {
                    model.togglePlayback()
                } label: {
                    Label(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill")
                        .frame(minWidth: 108)
                }
                .controlSize(.large)
                .keyboardShortcut(.space, modifiers: [])

                Button {
                    model.seekRelative(5)
                } label: {
                    Label("5s", systemImage: "goforward.5")
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
            }
            .disabled(model.currentSourceURL == nil)

            HStack(spacing: 18) {
                Button {
                    model.stepSpeed(-0.05)
                } label: {
                    Label("Slower", systemImage: "minus")
                }
                .keyboardShortcut("-", modifiers: [])

                Text(model.speedText)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(width: 96)

                Button {
                    model.stepSpeed(0.05)
                } label: {
                    Label("Faster", systemImage: "plus")
                }
                .keyboardShortcut("+", modifiers: [])

                Divider()
                    .frame(height: 24)

                Button {
                    model.toggleLoop()
                } label: {
                    Label(model.loopButtonText, systemImage: "repeat")
                }
                .disabled(model.currentSourceURL == nil)
                .keyboardShortcut("l", modifiers: [])

                if model.loopRegion != nil {
                    Button(role: .destructive) {
                        model.clearLoop()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                            .labelStyle(.iconOnly)
                    }
                    .help("Clear loop")
                }
            }
            .disabled(model.currentSourceURL == nil)
        }
    }

    private var keyControls: some View {
        HStack(spacing: 12) {
            Label(model.keySummaryText, systemImage: "music.quarternote.3")

            Picker("Change to", selection: Binding(get: { model.targetRoot }, set: { model.setTargetRoot($0) })) {
                Text("Original").tag(PitchClass?.none)
                ForEach(PitchClass.allCases) { pitchClass in
                    Text(pitchClass.displayName).tag(PitchClass?.some(pitchClass))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)

            Spacer()
        }
        .foregroundStyle(.secondary)
    }

    private var youtubeSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Open YouTube")
                .font(.title2.weight(.semibold))

            TextField("YouTube URL", text: $youtubeURLString)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    startYouTubeDownload()
                }

            HStack {
                Spacer()

                Button("Cancel") {
                    isYouTubeSheetPresented = false
                }

                Button {
                    startYouTubeDownload()
                } label: {
                    Label(model.isDownloadingYouTube ? "Opening..." : "Open", systemImage: "arrow.down.to.line")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.isDownloadingYouTube || youtubeURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private var advancedSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Advanced")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button {
                    isAdvancedSheetPresented = false
                } label: {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
                .help("Close")
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Label("Speed", systemImage: "speedometer")

                HStack(spacing: 12) {
                    Slider(
                        value: Binding(
                            get: { model.speed },
                            set: { model.setSpeed($0) }
                        ),
                        in: PracticeSpeed.minimum...PracticeSpeed.maximum
                    )

                    Text(model.speedText)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 56, alignment: .trailing)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Label("Separation", systemImage: "pianokeys")

                HStack(spacing: 10) {
                    Button {
                        model.extractDigitalPianoWithMVSep(token: mvsepApiToken)
                    } label: {
                        Label(model.isRunningMVSep ? "Running..." : "MVSep Digital Piano", systemImage: "cloud")
                    }
                    .disabled(model.isStemWorkRunning || model.currentSourceURL == nil || mvsepApiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    SecureField("MVSep API token", text: $mvsepApiToken)
                        .textFieldStyle(.roundedBorder)
                }

                Button {
                    model.installLocalSeparators()
                } label: {
                    Label(model.isInstallingSeparators ? "Installing..." : "Install Local AI", systemImage: "arrow.down.circle")
                }
                .disabled(model.isInstallingSeparators)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func startYouTubeDownload() {
        model.downloadYouTubeAudio(youtubeURLString)
        isYouTubeSheetPresented = false
    }

    private func resizeWindow(hasAudio: Bool) {
        let metrics = PracticeWindowLayout.metrics(hasAudio: hasAudio)
        let size = NSSize(width: metrics.width, height: metrics.height)

        DispatchQueue.main.async {
            guard let window = NSApplication.shared.keyWindow
                ?? NSApplication.shared.windows.first(where: { $0.isVisible }) else {
                return
            }

            window.minSize = size
            window.setContentSize(size)
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

private struct GeneratedStemOption: Identifiable, Equatable {
    let stem: PracticeStem
    let url: URL
    var isIncluded: Bool

    var id: PracticeStem {
        stem
    }
}

private struct ExtractedPracticeStem: Equatable {
    let stem: PracticeStem
    let url: URL
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
    @Published var isInstallingSeparators = false
    @Published var isIsolating = false
    @Published var isMixingStems = false
    @Published var isRunningMVSep = false
    @Published var isDownloadingYouTube = false
    @Published var recentAudioItems: [RecentFileEntry] = []
    @Published var canSaveGeneratedStem = false
    @Published var hasAudio = false
    @Published var generatedStemOptions: [GeneratedStemOption] = []

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private let recentFilesDefaultsKey = "recentAudioFiles.v1"
    private var playbackFile: AVAudioFile?
    private var playbackSampleRate = 44_100.0
    private var playbackAnchorTime = 0.0
    private var playbackAnchorDate: Date?
    private var originalAudioURL: URL?
    private var displayedAudioURL: URL?
    private var pendingLoopStart: Double?
    private var recentFiles = RecentFilesList()
    private var generatedRetention = GeneratedAudioRetention()

    var currentSourceURL: URL? {
        originalAudioURL
    }

    var isStemWorkRunning: Bool {
        isIsolating || isMixingStems || isRunningMVSep
    }

    var hasSelectedGeneratedStems: Bool {
        generatedStemOptions.contains { $0.isIncluded }
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

    var speedText: String {
        PracticeSurfaceCopy.speedText(speed)
    }

    var keySummaryText: String {
        PracticeSurfaceCopy.keyText(detectedKey: detectedKey, targetRoot: targetRoot)
    }

    var loopButtonText: String {
        PracticeSurfaceCopy.loopText(loopRegion)
    }

    init() {
        engine.attach(player)
        engine.attach(timePitch)
        loadRecents()
        applyTimePitchSettings()
    }

    @discardableResult
    func load(_ url: URL) -> Bool {
        let previousGeneratedURL = generatedRetention.takeDiscardableURL()
        updateGeneratedSaveState()

        if loadAudio(url, preserveOriginalSource: false, addToRecents: true) {
            generatedStemOptions = []
            removeGeneratedFile(previousGeneratedURL)
            return true
        } else if let previousGeneratedURL {
            _ = generatedRetention.trackUnsaved(previousGeneratedURL)
            updateGeneratedSaveState()
        }

        return false
    }

    func openRecent(_ item: RecentFileEntry) {
        guard FileManager.default.fileExists(atPath: item.path) else {
            removeRecent(item.url)
            statusText = "Recent file missing: \(item.displayName)"
            return
        }

        load(item.url)
    }

    func clearRecents() {
        recentFiles = RecentFilesList()
        recentAudioItems = []
        UserDefaults.standard.removeObject(forKey: recentFilesDefaultsKey)
    }

    func downloadYouTubeAudio(_ rawURLString: String) {
        guard !isDownloadingYouTube else {
            return
        }

        let trimmed = rawURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pageURL = URL(string: trimmed),
              let scheme = pageURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            statusText = "Enter a valid YouTube URL."
            return
        }

        guard let ytDLP = ProcessRunner.findExecutable("yt-dlp") else {
            statusText = "Install yt-dlp first, or put yt-dlp on PATH."
            return
        }

        isDownloadingYouTube = true
        statusText = "Downloading YouTube audio..."

        Task {
            do {
                try FileManager.default.createDirectory(at: youtubeDownloadRootURL, withIntermediateDirectories: true)
                let command = YouTubeAudioDownloadCommand.ytDLP(
                    ytDLP,
                    pageURL: pageURL,
                    outputDirectory: youtubeDownloadRootURL
                )
                let output = try await ProcessRunner.run(command.executableURL, arguments: command.arguments)
                let downloadedURL = try findDownloadedYouTubeAudio(from: output)

                isDownloadingYouTube = false
                if load(downloadedURL) {
                    statusText = "Downloaded \(downloadedURL.lastPathComponent)"
                }
            } catch {
                isDownloadingYouTube = false
                statusText = "YouTube download failed: \(error.localizedDescription)"
            }
        }
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
        applyTimePitchSettings()
    }

    func stepSpeed(_ delta: Double) {
        setSpeed(speed + delta)
    }

    func setTargetRoot(_ root: PitchClass?) {
        targetRoot = root
        applyTimePitchSettings()
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

    func installLocalSeparators() {
        guard !isInstallingSeparators else {
            return
        }

        isInstallingSeparators = true
        statusText = "Installing local AI into \(localSeparatorVenvURL.path)"

        Task {
            do {
                try FileManager.default.createDirectory(
                    at: localSeparatorVenvURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try await LocalSeparatorInstaller.install(into: localSeparatorVenvURL)
                isInstallingSeparators = false
                statusText = "Local AI installed."
            } catch {
                isInstallingSeparators = false
                statusText = "Local AI install failed: \(error.localizedDescription)"
            }
        }
    }

    func separatePracticeStems() {
        guard !isIsolating else {
            return
        }
        guard let input = originalAudioURL else {
            statusText = "Open an audio file before separating stems."
            return
        }
        isIsolating = true
        generatedStemOptions = []
        statusText = "Separating stems with MLX..."

        Task {
            do {
                let stems = try await extractLocalPracticeStems(from: input) { [weak self] message in
                    Task { @MainActor in
                        self?.statusText = message
                    }
                }
                isIsolating = false

                generatedStemOptions = stems.map { stem in
                    GeneratedStemOption(stem: stem.stem, url: stem.url, isIncluded: stem.stem == .piano)
                }
                if !generatedStemOptions.contains(where: { $0.isIncluded }),
                   !generatedStemOptions.isEmpty {
                    generatedStemOptions[0].isIncluded = true
                }

                applySelectedStemMix()
            } catch {
                isIsolating = false
                statusText = "Stem separation failed: \(error.localizedDescription)"
            }
        }
    }

    func applySelectedStemMix() {
        guard !isMixingStems else {
            return
        }

        let selectedOptions = generatedStemOptions.filter { $0.isIncluded }
        guard !selectedOptions.isEmpty else {
            statusText = "Choose at least one stem."
            return
        }

        let outputDirectory = generatedJobDirectory(containing: selectedOptions[0].url)
            ?? selectedOptions[0].url.deletingLastPathComponent()
        let outputURL = outputDirectory.appendingPathComponent("selected-stems.wav", isDirectory: false)
        let selectedURLs = selectedOptions.map(\.url)
        let selectedLabel = selectedOptions.map { $0.stem.displayName }.joined(separator: " + ")

        isMixingStems = true
        statusText = selectedOptions.count == 1 ? "Loading \(selectedLabel)..." : "Mixing \(selectedLabel)..."
        pause()
        engine.stop()
        engine.reset()
        playbackFile = nil

        Task {
            do {
                try await createSelectedStemMix(from: selectedURLs, output: outputURL)
                isMixingStems = false

                if loadAudio(outputURL, preserveOriginalSource: true, addToRecents: false) {
                    trackUnsavedGenerated(outputURL)
                    statusText = "Loaded \(selectedLabel). Save it to keep the WAV."
                } else {
                    removeGeneratedFile(outputURL)
                }
            } catch {
                isMixingStems = false
                statusText = "Could not mix stems: \(error.localizedDescription)"
            }
        }
    }

    func extractDigitalPianoWithMVSep(token: String) {
        guard !isStemWorkRunning else {
            return
        }
        guard let input = originalAudioURL else {
            statusText = "Open an audio file before running MVSep."
            return
        }

        let apiToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiToken.isEmpty else {
            statusText = "Enter an MVSep API token first."
            return
        }

        isRunningMVSep = true
        statusText = "Uploading to MVSep Digital Piano..."

        Task {
            do {
                let outputDirectory = generatedJobRootURL(under: mvsepOutputRootURL)
                try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
                let stemURL = try await MVSepClient.extractDigitalPiano(
                    input: input,
                    apiToken: apiToken,
                    outputDirectory: outputDirectory
                ) { [weak self] message in
                    Task { @MainActor in
                        self?.statusText = message
                    }
                }
                isRunningMVSep = false
                generatedStemOptions = []
                if loadAudio(stemURL, preserveOriginalSource: true, addToRecents: false) {
                    trackUnsavedGenerated(stemURL)
                    statusText = "Loaded MVSep digital piano stem. Save it to keep the WAV."
                } else {
                    removeGeneratedFile(stemURL)
                }
            } catch {
                isRunningMVSep = false
                statusText = "MVSep failed: \(error.localizedDescription)"
            }
        }
    }

    func saveGeneratedStem() {
        guard let sourceURL = generatedRetention.unsavedURL else {
            statusText = "No generated stem to save."
            return
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Save Generated Stem"
        savePanel.nameFieldStringValue = sourceURL.lastPathComponent
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.allowedContentTypes = [UTType(filenameExtension: "wav") ?? .wav]

        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else {
            return
        }

        do {
            try copyGeneratedStem(from: sourceURL, to: destinationURL)
            let temporaryURL = generatedRetention.markSaved()
            updateGeneratedSaveState()
            generatedStemOptions = []
            removeGeneratedFile(temporaryURL, preserving: destinationURL)

            if loadAudio(destinationURL, preserveOriginalSource: true, addToRecents: true) {
                statusText = "Saved \(destinationURL.lastPathComponent)"
            }
        } catch {
            statusText = "Could not save stem: \(error.localizedDescription)"
        }
    }

    func discardUnsavedGeneratedStem() {
        let discardableURL = generatedRetention.takeDiscardableURL()
        updateGeneratedSaveState()
        generatedStemOptions = []
        removeGeneratedFile(discardableURL)
    }

    func discardGeneratedStemAndRestoreSource() {
        let sourceURL = originalAudioURL
        discardUnsavedGeneratedStem()

        guard let sourceURL else {
            return
        }

        if displayedAudioURL?.standardizedFileURL.path != sourceURL.standardizedFileURL.path,
           loadAudio(sourceURL, preserveOriginalSource: false, addToRecents: false) {
            statusText = "Discarded stem mix."
        }
    }

    @discardableResult
    private func loadAudio(_ url: URL, preserveOriginalSource: Bool, addToRecents: Bool) -> Bool {
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
            hasAudio = true
            loopRegion = nil
            pendingLoopStart = nil
            detectedKey = KeyDetector.detectKey(fromMonoSamples: analysis.monoSamples, sampleRate: analysis.sampleRate)
            applyTimePitchSettings()
            if addToRecents {
                noteRecent(url)
            }
            statusText = "Loaded \(url.lastPathComponent)"
            return true
        } catch {
            statusText = "Could not open \(url.lastPathComponent): \(error.localizedDescription)"
            return false
        }
    }

    private func applyTimePitchSettings() {
        timePitch.rate = Float(speed)
        timePitch.pitch = Float(pitchCents)
        timePitch.overlap = PlaybackQualitySettings.timePitchOverlap(forSpeed: speed, pitchCents: pitchCents)
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

    private var localSeparatorVenvURL: URL {
        appSupportURL
            .appendingPathComponent("local-separators-venv", isDirectory: true)
    }

    private var mlxOutputRootURL: URL {
        appSupportURL.appendingPathComponent("MLXStems", isDirectory: true)
    }

    private var mlxModelRootURL: URL {
        appSupportURL.appendingPathComponent("Models", isDirectory: true)
    }

    private var mvsepOutputRootURL: URL {
        appSupportURL.appendingPathComponent("MVSepStems", isDirectory: true)
    }

    private var youtubeDownloadRootURL: URL {
        appSupportURL.appendingPathComponent("YouTube", isDirectory: true)
    }

    private var appSupportURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Transcribee", isDirectory: true)
    }

    private func extractLocalPracticeStems(
        from input: URL,
        progress: @escaping @Sendable (String) -> Void
    ) async throws -> [ExtractedPracticeStem] {
        let mlxJobRootURL = generatedJobRootURL(under: mlxOutputRootURL)
        guard mlxCommand(input: input, outputRoot: mlxJobRootURL, spec: .piano) != nil else {
            throw AppProcessError.failed("Install Local AI first, or put mlx-audio-separator on PATH.")
        }

        try FileManager.default.createDirectory(at: mlxJobRootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mlxModelRootURL, withIntermediateDirectories: true)

        var extractedStems: [ExtractedPracticeStem] = []
        var failures: [String] = []

        for spec in MLXStemSpec.practiceSpecs {
            guard let command = mlxCommand(input: input, outputRoot: mlxJobRootURL, spec: spec) else {
                throw AppProcessError.failed("Install Local AI first, or put mlx-audio-separator on PATH.")
            }

            progress("MLX: \(spec.stem.displayName)...")

            do {
                _ = try await ProcessRunner.run(command.executableURL, arguments: command.arguments)

                if FileManager.default.fileExists(atPath: command.expectedStem.path) {
                    extractedStems.append(ExtractedPracticeStem(stem: spec.stem, url: command.expectedStem))
                    continue
                }

                if let discovered = findStem(in: mlxJobRootURL, matching: [spec.expectedFileName, "(\(spec.targetStem))", spec.targetStem]) {
                    extractedStems.append(ExtractedPracticeStem(stem: spec.stem, url: discovered))
                    continue
                }

                failures.append("\(spec.stem.displayName): no output")
            } catch {
                failures.append("\(spec.stem.displayName): \(error.localizedDescription)")
            }
        }

        guard !extractedStems.isEmpty else {
            let detail = failures.isEmpty ? "No stems were created." : failures.joined(separator: "; ")
            throw AppProcessError.failed(detail)
        }

        return extractedStems
    }

    private func mlxCommand(input: URL, outputRoot: URL, spec: MLXStemSpec) -> MLXSeparatorCommand? {
        let venvExecutable = localSeparatorVenvURL.appendingPathComponent("bin/mlx-audio-separator")
        if FileManager.default.isExecutableFile(atPath: venvExecutable.path) {
            return .executable(venvExecutable, input: input, outputRoot: outputRoot, modelRoot: mlxModelRootURL, spec: spec)
        }

        let venvPython = localSeparatorVenvURL.appendingPathComponent("bin/python")
        if FileManager.default.isExecutableFile(atPath: venvPython.path) {
            return .pythonModule(venvPython, input: input, outputRoot: outputRoot, modelRoot: mlxModelRootURL, spec: spec)
        }

        if let mlx = ProcessRunner.findExecutable("mlx-audio-separator") {
            return .executable(mlx, input: input, outputRoot: outputRoot, modelRoot: mlxModelRootURL, spec: spec)
        }

        return nil
    }

    private func findStem(in directory: URL, matching tokens: [String]) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            guard tokens.contains(where: { fileURL.lastPathComponent.localizedCaseInsensitiveContains($0) }) else {
                continue
            }
            if (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                return fileURL
            }
        }

        return nil
    }

    private func findDownloadedYouTubeAudio(from output: String) throws -> URL {
        if let printedURL = YouTubeAudioDownloadCommand.downloadedAudioURL(fromOutput: output),
           FileManager.default.fileExists(atPath: printedURL.path) {
            return printedURL
        }

        guard let enumerator = FileManager.default.enumerator(
            at: youtubeDownloadRootURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw AppProcessError.failed("yt-dlp finished but no downloaded audio folder was readable.")
        }

        let audioExtensions = Set(["mp3", "m4a", "wav", "flac"])
        var newestURL: URL?
        var newestDate = Date.distantPast

        for case let fileURL as URL in enumerator {
            guard audioExtensions.contains(fileURL.pathExtension.lowercased()) else {
                continue
            }

            let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true else {
                continue
            }

            let modified = values?.contentModificationDate ?? Date.distantPast
            if modified > newestDate {
                newestDate = modified
                newestURL = fileURL
            }
        }

        guard let newestURL else {
            throw AppProcessError.failed("yt-dlp finished but did not create an MP3.")
        }

        return newestURL
    }

    private func trackUnsavedGenerated(_ url: URL) {
        let previousURL = generatedRetention.trackUnsaved(url)
        updateGeneratedSaveState()
        removeGeneratedFile(previousURL, preserving: url)
    }

    private func createSelectedStemMix(from inputs: [URL], output: URL) async throws {
        guard !inputs.isEmpty else {
            throw AppProcessError.failed("Choose at least one stem.")
        }

        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }

        if inputs.count == 1 {
            try FileManager.default.copyItem(at: inputs[0], to: output)
            return
        }

        guard let ffmpeg = ProcessRunner.findExecutable("ffmpeg") else {
            throw AppProcessError.failed("Install ffmpeg first, or put ffmpeg on PATH.")
        }

        let command = FFmpegStemMixCommand.amix(ffmpeg, inputs: inputs, output: output)
        _ = try await ProcessRunner.run(command.executableURL, arguments: command.arguments)

        guard FileManager.default.fileExists(atPath: output.path) else {
            throw AppProcessError.failed("ffmpeg finished but did not create \(output.path)")
        }
    }

    private func updateGeneratedSaveState() {
        canSaveGeneratedStem = generatedRetention.canSave
    }

    private func copyGeneratedStem(from sourceURL: URL, to destinationURL: URL) throws {
        let sourcePath = sourceURL.standardizedFileURL.path
        let destinationPath = destinationURL.standardizedFileURL.path

        guard sourcePath != destinationPath else {
            return
        }

        if FileManager.default.fileExists(atPath: destinationPath) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    private func removeGeneratedFile(_ url: URL?, preserving preservedURL: URL? = nil) {
        guard let url else {
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        if let preservedURL,
           preservedURL.standardizedFileURL.path == url.standardizedFileURL.path {
            return
        }

        if let jobDirectory = generatedJobDirectory(containing: url) {
            if let preservedURL, generatedJobDirectory(containing: preservedURL) == jobDirectory {
                try? FileManager.default.removeItem(at: url)
            } else {
                try? FileManager.default.removeItem(at: jobDirectory)
            }
            return
        }

        try? FileManager.default.removeItem(at: url)
    }

    private func generatedJobRootURL(under root: URL) -> URL {
        root.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func generatedJobDirectory(containing url: URL) -> URL? {
        let standardizedURL = url.standardizedFileURL
        let generatedRoots = [
            mlxOutputRootURL.standardizedFileURL,
            mvsepOutputRootURL.standardizedFileURL
        ]

        for root in generatedRoots {
            let rootPath = root.path
            let urlPath = standardizedURL.path
            guard urlPath.hasPrefix(rootPath + "/") else {
                continue
            }

            let relativePath = String(urlPath.dropFirst(rootPath.count + 1))
            guard let jobName = relativePath.split(separator: "/").first else {
                continue
            }

            return root.appendingPathComponent(String(jobName), isDirectory: true)
        }

        return nil
    }

    private func loadRecents() {
        guard let data = UserDefaults.standard.data(forKey: recentFilesDefaultsKey),
              let stored = try? JSONDecoder().decode(RecentFilesList.self, from: data) else {
            return
        }

        recentFiles = stored
        recentAudioItems = stored.entries
    }

    private func noteRecent(_ url: URL) {
        recentFiles.noteOpened(url)
        recentAudioItems = recentFiles.entries
        persistRecents()
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    private func removeRecent(_ url: URL) {
        recentFiles.remove(url)
        recentAudioItems = recentFiles.entries
        persistRecents()
    }

    private func persistRecents() {
        guard let data = try? JSONEncoder().encode(recentFiles) else {
            return
        }

        UserDefaults.standard.set(data, forKey: recentFilesDefaultsKey)
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

private enum LocalSeparatorInstaller {
    static func install(into venvURL: URL) async throws {
        if let uv = ProcessRunner.findExecutable("uv") {
            try await installWithUV(uv, venvURL: venvURL)
            return
        }

        guard let python = ProcessRunner.findExecutable("python3.12")
            ?? ProcessRunner.findExecutable("python3.11")
            ?? ProcessRunner.findExecutable("python3.10")
            ?? ProcessRunner.findExecutable("python3") else {
            throw AppProcessError.failed("Could not find uv or Python 3.10+ on PATH.")
        }

        try await ProcessRunner.run(python, arguments: ["-m", "venv", venvURL.path])
        let venvPython = venvURL.appendingPathComponent("bin/python")
        try await ProcessRunner.run(venvPython, arguments: ["-m", "pip", "install", "--upgrade", "pip"])
        try await ProcessRunner.run(venvPython, arguments: ["-m", "pip", "install", "--upgrade", "mlx-audio-separator", "torch"])
        try await ProcessRunner.run(venvPython, arguments: ["-m", "mlx_audio_separator", "--help"])
    }

    private static func installWithUV(_ uv: URL, venvURL: URL) async throws {
        let pythonVersions = ["3.12", "3.11", "3.10", "3.14"]
        var lastError: Error?

        for pythonVersion in pythonVersions {
            do {
                try await ProcessRunner.run(uv, arguments: ["venv", "--allow-existing", "--python", pythonVersion, venvURL.path])
                lastError = nil
                break
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }

        let venvPython = venvURL.appendingPathComponent("bin/python")
        try await ProcessRunner.run(uv, arguments: ["pip", "install", "--python", venvPython.path, "--upgrade", "mlx-audio-separator", "torch"])
        try await ProcessRunner.run(venvPython, arguments: ["-m", "mlx_audio_separator", "--help"])
    }
}

private enum MVSepClient {
    static func extractDigitalPiano(
        input: URL,
        apiToken: String,
        outputDirectory: URL,
        progress: @escaping @Sendable (String) -> Void
    ) async throws -> URL {
        let hash = try await createDigitalPianoJob(input: input, apiToken: apiToken)
        progress("MVSep queued: \(hash)")
        return try await waitForResult(hash: hash, outputDirectory: outputDirectory, progress: progress)
    }

    private static func createDigitalPianoJob(input: URL, apiToken: String) async throws -> String {
        let spec = MVSepSeparationRequest.digitalPiano(apiToken: apiToken)
        let boundary = "Transcribee-\(UUID().uuidString)"
        var request = URLRequest(url: spec.endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = try multipartBody(
            fields: spec.formFields,
            fileField: "audiofile",
            fileURL: input,
            boundary: boundary
        )

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        try validate(response: response, data: data)

        let createResponse = try JSONDecoder().decode(CreateResponse.self, from: data)
        guard createResponse.success, let hash = createResponse.data?.hash, !hash.isEmpty else {
            throw AppProcessError.failed(createResponse.message ?? createResponse.data?.message ?? "MVSep did not return a job hash.")
        }

        return hash
    }

    private static func waitForResult(
        hash: String,
        outputDirectory: URL,
        progress: @escaping @Sendable (String) -> Void
    ) async throws -> URL {
        for _ in 0..<90 {
            let result = try await getResult(hash: hash)
            let status = result.status ?? "unknown"

            if status == "done", let files = result.data?.files, !files.isEmpty {
                return try await downloadBestStem(from: files, outputDirectory: outputDirectory)
            }

            if status == "failed" || status == "error" {
                throw AppProcessError.failed(result.data?.message ?? "MVSep job failed.")
            }

            if let queueCount = result.data?.queueCount, let currentOrder = result.data?.currentOrder {
                progress("MVSep \(status): \(currentOrder)/\(queueCount)")
            } else {
                progress("MVSep \(status)...")
            }

            try await Task.sleep(nanoseconds: 10_000_000_000)
        }

        throw AppProcessError.failed("MVSep timed out before returning a digital piano stem.")
    }

    private static func getResult(hash: String) async throws -> ResultResponse {
        var components = URLComponents(string: "https://mvsep.com/api/separation/get")!
        components.queryItems = [URLQueryItem(name: "hash", value: hash)]

        guard let url = components.url else {
            throw AppProcessError.failed("Could not build MVSep result URL.")
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ResultResponse.self, from: data)
    }

    private static func downloadBestStem(from files: [ResultFile], outputDirectory: URL) async throws -> URL {
        let preferred = files.first { file in
            let name = file.download.lowercased()
            return name.contains("digital") || name.contains("piano") || name.contains("keys")
        } ?? files[0]

        guard let sourceURL = URL(string: preferred.url.replacingOccurrences(of: "\\/", with: "/")) else {
            throw AppProcessError.failed("MVSep returned an invalid download URL.")
        }

        let (temporaryURL, response) = try await URLSession.shared.download(from: sourceURL)
        try validate(response: response, data: Data())

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let destination = outputDirectory.appendingPathComponent(preferred.download, isDirectory: false)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    private static func multipartBody(fields: [String: String], fileField: String, fileURL: URL, boundary: String) throws -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        for key in fields.keys.sorted() {
            body.append("--\(boundary)\(lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak + lineBreak)")
            body.append("\(fields[key] ?? "")\(lineBreak)")
        }

        let filename = fileURL.lastPathComponent
        body.append("--\(boundary)\(lineBreak)")
        body.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(filename)\"\(lineBreak)")
        body.append("Content-Type: \(mimeType(for: fileURL))\(lineBreak + lineBreak)")
        body.append(try Data(contentsOf: fileURL))
        body.append(lineBreak)
        body.append("--\(boundary)--\(lineBreak)")

        return body
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "mp3":
            return "audio/mpeg"
        case "flac":
            return "audio/flac"
        case "m4a":
            return "audio/mp4"
        case "aif", "aiff":
            return "audio/aiff"
        default:
            return "audio/wav"
        }
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            return
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw AppProcessError.failed(detail)
        }
    }

    private struct CreateResponse: Decodable {
        let success: Bool
        let data: CreateData?
        let message: String?
    }

    private struct CreateData: Decodable {
        let hash: String?
        let message: String?
    }

    private struct ResultResponse: Decodable {
        let success: Bool
        let status: String?
        let data: ResultData?
    }

    private struct ResultData: Decodable {
        let files: [ResultFile]?
        let message: String?
        let queueCount: Int?
        let currentOrder: Int?

        enum CodingKeys: String, CodingKey {
            case files
            case message
            case queueCount = "queue_count"
            case currentOrder = "current_order"
        }
    }

    private struct ResultFile: Decodable {
        let url: String
        let download: String
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
            process.environment = environmentWithToolFallbacks()
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

    private static func environmentWithToolFallbacks() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let fallbackPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        var paths = (environment["PATH"] ?? "").split(separator: ":").map(String.init)

        for fallbackPath in fallbackPaths where !paths.contains(fallbackPath) {
            paths.append(fallbackPath)
        }

        environment["PATH"] = paths.joined(separator: ":")
        return environment
    }
}

private extension LoopRegion {
    func contains(_ time: Double) -> Bool {
        time >= start && time <= end
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
