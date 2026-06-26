import Foundation

public struct RecentFileEntry: Codable, Equatable, Identifiable, Sendable {
    public let path: String
    public let displayName: String

    public var id: String {
        path
    }

    public var url: URL {
        URL(fileURLWithPath: path)
    }

    public init(url: URL) {
        self.path = url.standardizedFileURL.path
        self.displayName = url.lastPathComponent
    }
}

public struct RecentFilesList: Codable, Equatable, Sendable {
    public private(set) var entries: [RecentFileEntry]

    public init(entries: [RecentFileEntry] = []) {
        self.entries = entries
    }

    public mutating func noteOpened(_ url: URL, maxCount: Int = 10) {
        let entry = RecentFileEntry(url: url)
        entries.removeAll { $0.path == entry.path }
        entries.insert(entry, at: 0)

        if entries.count > maxCount {
            entries = Array(entries.prefix(maxCount))
        }
    }

    public mutating func remove(_ url: URL) {
        let path = url.standardizedFileURL.path
        entries.removeAll { $0.path == path }
    }
}
