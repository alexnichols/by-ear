import Foundation

public struct DemucsCommand: Equatable, Sendable {
    public static let modelName = "htdemucs_6s"
    public static let targetStem = "piano"

    public let executableURL: URL
    public let arguments: [String]
    public let expectedPianoStem: URL

    public static func pythonModule(
        _ python: URL,
        input: URL,
        outputRoot: URL
    ) -> DemucsCommand {
        DemucsCommand(
            executableURL: python,
            arguments: moduleArguments(input: input, outputRoot: outputRoot),
            expectedPianoStem: expectedStemPath(input: input, outputRoot: outputRoot)
        )
    }

    public static func executable(
        _ demucs: URL,
        input: URL,
        outputRoot: URL
    ) -> DemucsCommand {
        DemucsCommand(
            executableURL: demucs,
            arguments: separationArguments(input: input, outputRoot: outputRoot),
            expectedPianoStem: expectedStemPath(input: input, outputRoot: outputRoot)
        )
    }

    private static func moduleArguments(input: URL, outputRoot: URL) -> [String] {
        ["-m", "demucs"] + separationArguments(input: input, outputRoot: outputRoot)
    }

    private static func separationArguments(input: URL, outputRoot: URL) -> [String] {
        [
            "-n", modelName,
            "--two-stems", targetStem,
            "--float32",
            "--segment", "7",
            "-o", outputRoot.path,
            input.path
        ]
    }

    private static func expectedStemPath(input: URL, outputRoot: URL) -> URL {
        outputRoot
            .appendingPathComponent(modelName, isDirectory: true)
            .appendingPathComponent(input.deletingPathExtension().lastPathComponent, isDirectory: true)
            .appendingPathComponent("\(targetStem).wav", isDirectory: false)
    }
}
