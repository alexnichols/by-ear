import Foundation

public struct MLXSeparatorCommand: Equatable, Sendable {
    public static let outputFormat = "WAV"
    public static let speedMode = "latency_safe_v3"

    public let executableURL: URL
    public let arguments: [String]
    public let expectedStem: URL

    public static func executable(
        _ executable: URL,
        input: URL,
        outputRoot: URL,
        modelRoot: URL,
        spec: MLXStemSpec = .piano
    ) -> MLXSeparatorCommand {
        MLXSeparatorCommand(
            executableURL: executable,
            arguments: separationArguments(input: input, outputRoot: outputRoot, modelRoot: modelRoot, spec: spec),
            expectedStem: expectedStemPath(outputRoot: outputRoot, spec: spec)
        )
    }

    public static func pythonModule(
        _ python: URL,
        input: URL,
        outputRoot: URL,
        modelRoot: URL,
        spec: MLXStemSpec = .piano
    ) -> MLXSeparatorCommand {
        MLXSeparatorCommand(
            executableURL: python,
            arguments: ["-m", "mlx_audio_separator"] + separationArguments(input: input, outputRoot: outputRoot, modelRoot: modelRoot, spec: spec),
            expectedStem: expectedStemPath(outputRoot: outputRoot, spec: spec)
        )
    }

    private static func separationArguments(input: URL, outputRoot: URL, modelRoot: URL, spec: MLXStemSpec) -> [String] {
        [
            input.path,
            "-m", spec.modelFilename,
            "--single_stem", spec.targetStem,
            "--output_format", outputFormat,
            "--custom_output_names", spec.customOutputNamesJSON,
            "--output_dir", outputRoot.path,
            "--model_file_dir", modelRoot.path,
            "--speed_mode", speedMode,
            "--cache_clear_policy", "deferred",
            "--write_workers", "2"
        ]
    }

    private static func expectedStemPath(outputRoot: URL, spec: MLXStemSpec) -> URL {
        outputRoot.appendingPathComponent(spec.expectedFileName, isDirectory: false)
    }
}
