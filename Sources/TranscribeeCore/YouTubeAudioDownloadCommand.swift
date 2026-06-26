import Foundation

public struct YouTubeAudioDownloadCommand: Equatable, Sendable {
    public static let outputTemplate = "%(title).200B [%(id)s].%(ext)s"

    public let executableURL: URL
    public let arguments: [String]

    public static func ytDLP(
        _ executable: URL,
        pageURL: URL,
        outputDirectory: URL
    ) -> YouTubeAudioDownloadCommand {
        YouTubeAudioDownloadCommand(
            executableURL: executable,
            arguments: [
                "--no-playlist",
                "--no-progress",
                "--no-simulate",
                "--extract-audio",
                "--audio-format", "mp3",
                "--audio-quality", "0",
                "--paths", outputDirectory.path,
                "--output", outputTemplate,
                "--print", "after_move:filepath",
                pageURL.absoluteString
            ]
        )
    }

    public static func downloadedAudioURL(fromOutput output: String) -> URL? {
        output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .last { line in
                let lowercased = line.lowercased()
                return lowercased.hasSuffix(".mp3")
                    || lowercased.hasSuffix(".m4a")
                    || lowercased.hasSuffix(".wav")
                    || lowercased.hasSuffix(".flac")
            }
            .map { URL(fileURLWithPath: $0) }
    }
}
