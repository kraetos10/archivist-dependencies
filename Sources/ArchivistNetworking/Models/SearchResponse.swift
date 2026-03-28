import Foundation

public nonisolated struct SearchResponseWrapper: Decodable, Sendable, Equatable {
    public let results: SearchResponse

    public init(results: SearchResponse) {
        self.results = results
    }
}

public nonisolated struct SearchResponse: Decodable, Sendable, Equatable {
    public let videoResults: [VideoResponse]?
    public let channelResults: [ChannelResponse]?
    public let playlistResults: [PlaylistResponse]?

    public init(
        videoResults: [VideoResponse]?,
        channelResults: [ChannelResponse]?,
        playlistResults: [PlaylistResponse]?
    ) {
        self.videoResults = videoResults
        self.channelResults = channelResults
        self.playlistResults = playlistResults
    }

    enum CodingKeys: String, CodingKey {
        case videoResults = "video_results"
        case channelResults = "channel_results"
        case playlistResults = "playlist_results"
    }
}
