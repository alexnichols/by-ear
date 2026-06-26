import Foundation

public struct FFmpegStemMixCommand: Equatable, Sendable {
    public let executableURL: URL
    public let arguments: [String]
    public let outputURL: URL

    public static func amix(_ ffmpeg: URL, inputs: [URL], output: URL) -> FFmpegStemMixCommand {
        var arguments: [String] = ["-hide_banner", "-loglevel", "error"]

        for input in inputs {
            arguments.append(contentsOf: ["-i", input.path])
        }

        arguments.append(contentsOf: [
            "-filter_complex",
            "amix=inputs=\(inputs.count):duration=longest:dropout_transition=0:normalize=0,alimiter=limit=0.95",
            "-ar", "44100",
            "-ac", "2",
            "-c:a", "pcm_s16le",
            "-y",
            output.path
        ])

        return FFmpegStemMixCommand(executableURL: ffmpeg, arguments: arguments, outputURL: output)
    }
}
