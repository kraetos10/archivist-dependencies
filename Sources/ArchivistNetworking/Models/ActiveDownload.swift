import Foundation

public nonisolated struct ActiveDownload: Equatable, Sendable {
    public let title: String
    public let messages: [String]
    public let progress: Double?

    public init(
        title: String,
        messages: [String],
        progress: Double?
    ) {
        self.title = title
        self.messages = messages
        self.progress = progress
    }

    public var videoTitle: String? {
        for message in messages {
            if let range = message.range(of: "Processing Video: ") {
                return String(message[range.upperBound...])
            }
        }
        if let range = title.range(of: "Downloading: ") {
            return String(title[range.upperBound...])
        }
        return nil
    }

    public var currentStep: String {
        messages.last ?? ""
    }
}
