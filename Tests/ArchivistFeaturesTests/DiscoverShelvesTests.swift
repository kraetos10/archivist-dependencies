#if !os(tvOS)
import ArchivistNetworking
import Foundation
import Testing

@testable import ArchivistFeatures

struct DiscoverShelvesTests {
    private func watched(
        _ id: String,
        title: String = "A video",
        channel: String
    ) -> VideoResponse {
        VideoResponse(
            videoId: id,
            title: title,
            description: nil,
            category: nil,
            channel: VideoChannel(
                channelId: channel,
                channelName: "Name of \(channel)",
                channelActive: nil,
                channelBannerUrl: nil,
                channelThumbUrl: nil,
                channelTvartUrl: nil,
                channelDescription: nil,
                channelLastRefresh: nil,
                channelSubs: nil,
                channelSubscribed: nil,
                channelTags: nil,
                channelTabs: nil
            ),
            published: nil,
            dateDownloaded: nil,
            vidLastRefresh: nil,
            vidThumbUrl: nil,
            vidType: nil,
            active: nil,
            mediaUrl: nil,
            mediaSize: nil,
            player: nil,
            stats: nil,
            subtitles: nil,
            streams: nil,
            tags: nil,
            commentCount: nil
        )
    }

    private func upload(
        _ id: String,
        daysAgo: Int
    ) -> YouTubeVideo {
        YouTubeVideo(
            videoId: id,
            title: id,
            channelId: "UC",
            channelTitle: "C",
            published: Date(timeIntervalSince1970: 2_000_000_000 - Double(daysAgo) * 86_400)
        )
    }

    // MARK: - Taste

    @Test func mostWatchedChannelsComeFirstAndTiesGoToTheMoreRecent() {
        let taste = DiscoverTaste(
            watched: [
                watched("1", channel: "B"),
                watched("2", channel: "A"),
                watched("3", channel: "A"),
                watched("4", channel: "C")
            ]
        )

        #expect(taste.channels.map(\.id) == ["A", "B", "C"])
        #expect(taste.channels.first?.watchedCount == 2)
    }

    @Test func tasteKeepsFiveChannelsAndOneSeedPerChannel() {
        let videos = (1...8).map { watched("v\($0)", channel: "C\($0)") }
            + [watched("again", channel: "C1")]

        let taste = DiscoverTaste(watched: videos)

        #expect(taste.channels.count == DiscoverTaste.channelLimit)
        #expect(taste.seeds.map(\.videoId) == ["v1", "v2"])
        #expect(taste.watchedIds.count == 9)
    }

    @Test func noWatchedVideosIsAnEmptyTaste() {
        #expect(DiscoverTaste(watched: []).isEmpty)
    }

    // MARK: - Search text

    @Test(arguments: [
        ("WWDC 2024 — June 10 | Apple", "WWDC 2024"),
        ("Apple Event - October 30, 2023", "Apple Event"),
        ("doesn’t matter how many screenshots you take #shorts", "doesn’t matter how many screenshots you take"),
        ("Crimson Desert PC Performance Review (4K) [DF]", "Crimson Desert PC Performance Review"),
        ("  Plain title  ", "Plain title")
    ])
    func searchTextDropsCreditsTagsAndNotes(
        title: String,
        expected: String
    ) {
        #expect(DiscoverShelves.searchQuery(fromTitle: title) == expected)
    }

    @Test func searchTextIsCapped() {
        let long = String(repeating: "word ", count: 40)
        #expect(DiscoverShelves.searchQuery(fromTitle: long).count <= 60)
    }

    // MARK: - Shelves

    @Test func channelShelfIsNewestFirstWithoutWatchedOrRepeats() {
        let shelf = DiscoverShelves.channelShelf(
            uploads: [
                [upload("a1", daysAgo: 5), upload("seen", daysAgo: 1)],
                [upload("b1", daysAgo: 2), upload("a1", daysAgo: 5)]
            ],
            excluding: ["seen"]
        )

        #expect(shelf?.videos.map(\.videoId) == ["b1", "a1"])
        #expect(shelf?.id == "channels")
    }

    @Test func noChannelCrowdsTheShelf() {
        let crowded = (1...10).map { upload("c\($0)", daysAgo: $0) }

        let shelf = DiscoverShelves.channelShelf(uploads: [crowded], excluding: [])

        #expect(shelf?.videos.count == DiscoverShelves.perChannelLimit)
    }

    @Test func nothingNewMeansNoShelf() {
        #expect(DiscoverShelves.channelShelf(uploads: [[upload("seen", daysAgo: 1)]], excluding: ["seen"]) == nil)
        #expect(DiscoverShelves.channelShelf(uploads: [], excluding: []) == nil)
    }

    @Test func becauseShelfLeavesOutTheSeedAndWatchedVideos() {
        let seed = DiscoverTaste.Seed(videoId: "seed", title: "The seed")

        let shelf = DiscoverShelves.becauseShelf(
            seed: seed,
            results: [upload("seed", daysAgo: 1), upload("seen", daysAgo: 2), upload("new", daysAgo: 3)],
            excluding: ["seen"]
        )

        #expect(shelf?.videos.map(\.videoId) == ["new"])
        #expect(shelf?.id == "because-seed")
        #expect(shelf?.title.contains("The seed") == true)
    }

    @Test func shelvesSurviveTheCacheRoundTrip() throws {
        let shelf = DiscoverShelf(id: "x", title: "T", videos: [upload("a", daysAgo: 1)])

        let decoded = try JSONDecoder().decode(
            [DiscoverShelf].self,
            from: JSONEncoder().encode([shelf])
        )

        #expect(decoded == [shelf])
    }
}
#endif
