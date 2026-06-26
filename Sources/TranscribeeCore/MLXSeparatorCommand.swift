import Foundation

public struct MLXSeparatorCommand: Equatable, Sendable {
    public static let modelFilename = "BS-Roformer-SW.ckpt"
    public static let targetStem = "Piano"
    public static let outputFormat = "WAV"
    public static let speedMode = "latency_safe_v3"

    public let executableURL: URL
    public let arguments: [String]
    public let expectedStem: URL

    public static func executable(
        _ executable: URL,
        input: URL,
        outputRoot: URL,
        modelRoot: URL
    ) -> MLXSeparatorCommand {
        MLXSeparatorCommand(
            executableURL: executable,
            arguments: separationArguments(input: input, outputRoot: outputRoot, modelRoot: modelRoot),
            expectedStem: expectedStemPath(input: input, outputRoot: outputRoot)
        )
    }

    public static func pythonModule(
        _ python: URL,
        input: URL,
        outputRoot: URL,
        modelRoot: URL
    ) -> MLXSeparatorCommand {
        MLXSeparatorCommand(
            executableURL: python,
            arguments: ["-m", "mlx_audio_separator"] + separationArguments(input: input, outputRoot: outputRoot, modelRoot: modelRoot),
            expectedStem: expectedStemPath(input: input, outputRoot: outputRoot)
        )
    }

    private static func separationArguments(input: URL, outputRoot: URL, modelRoot: URL) -> [String] {
        [
            input.path,
            "-m", modelFilename,
            "--single_stem", targetStem,
            "--output_format", outputFormat,
            "--output_dir", outputRoot.path,
            "--model_file_dir", modelRoot.path,
            "--speed_mode", speedMode,
            "--cache_clear_policy", "deferred",
            "--write_workers", "2"
        ]
    }

    private static func expectedStemPath(input: URL, outputRoot: URL) -> URL {
        outputRoot.appendingPathComponent(expectedStemFileName(input: input), isDirectory: false)
    }

    private static func expectedStemFileName(input: URL) -> String {
        let baseName = sanitize(input.deletingPathExtension().lastPathComponent)
        let stem = sanitize(targetStem.lowercased())
        let model = sanitize(String(modelFilename.split(separator: ".").first ?? Substring(modelFilename)))
        return "\(baseName)_(\(stem))_\(model).\(outputFormat.lowercased())"
    }

    private static func sanitize(_ value: String) -> String {
        var result = ""
        var previousWasUnderscore = false
        let disallowed = CharacterSet(charactersIn: #"<>:"/\|?*"#)

        for scalar in value.unicodeScalars {
            if disallowed.contains(scalar) {
                if !previousWasUnderscore {
                    result.append("_")
                    previousWasUnderscore = true
                }
            } else {
                result.append(String(scalar))
                previousWasUnderscore = scalar == "_"
            }
        }

        return result.trimmingCharacters(in: CharacterSet(charactersIn: "_. "))
    }
}
