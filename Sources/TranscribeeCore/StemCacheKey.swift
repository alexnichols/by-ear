import Foundation

public struct StemCacheKey: Equatable, Sendable {
    public let sourcePath: String
    public let directoryName: String

    public init(sourceURL: URL) {
        sourcePath = sourceURL.standardizedFileURL.path
        let readableBase = Self.sanitize(sourceURL.deletingPathExtension().lastPathComponent)
        let hash = Self.fnv1a64(sourcePath)
        directoryName = "\(readableBase)-\(String(format: "%016llx", hash))"
    }

    private static func sanitize(_ value: String) -> String {
        var result = ""
        var previousWasSeparator = false
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))

        for scalar in value.unicodeScalars {
            if allowed.contains(scalar) {
                result.append(String(scalar))
                previousWasSeparator = scalar == " " || scalar == "-" || scalar == "_"
            } else if !previousWasSeparator {
                result.append("-")
                previousWasSeparator = true
            }
        }

        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: " -_"))
        return trimmed.isEmpty ? "audio" : trimmed
    }

    private static func fnv1a64(_ value: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
