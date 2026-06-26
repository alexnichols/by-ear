import Foundation

public struct GeneratedAudioRetention: Equatable, Sendable {
    public private(set) var unsavedURL: URL?

    public var canSave: Bool {
        unsavedURL != nil
    }

    public init(unsavedURL: URL? = nil) {
        self.unsavedURL = unsavedURL
    }

    @discardableResult
    public mutating func trackUnsaved(_ url: URL) -> URL? {
        let previousURL = unsavedURL
        unsavedURL = url
        return previousURL == url ? nil : previousURL
    }

    @discardableResult
    public mutating func takeDiscardableURL() -> URL? {
        defer {
            unsavedURL = nil
        }
        return unsavedURL
    }

    @discardableResult
    public mutating func markSaved() -> URL? {
        defer {
            unsavedURL = nil
        }
        return unsavedURL
    }
}
