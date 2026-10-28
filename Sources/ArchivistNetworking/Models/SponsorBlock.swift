import Foundation

/// The SponsorBlock data TubeArchivist keeps for a video.
///
/// Decoding is deliberately forgiving: a segment the server describes in a
/// shape we don't know is dropped, never allowed to fail the video's page.
public nonisolated struct SponsorBlock: Decodable, Sendable, Equatable {
    public let isEnabled: Bool
    public let segments: [SponsorBlockSegment]

    public init(
        isEnabled: Bool,
        segments: [SponsorBlockSegment]
    ) {
        self.isEnabled = isEnabled
        self.segments = segments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isEnabled)) ?? false
        let lossy = (try? container.decodeIfPresent([LossySegment].self, forKey: .segments)) ?? []
        segments = lossy.compactMap(\.segment)
    }

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case segments
    }

    private struct LossySegment: Decodable {
        let segment: SponsorBlockSegment?

        init(from decoder: Decoder) throws {
            segment = try? SponsorBlockSegment(from: decoder)
        }
    }
}

public nonisolated struct SponsorBlockSegment: Decodable, Sendable, Equatable {
    public let uuid: String
    /// SponsorBlock's category: `sponsor`, `intro`, `outro`, `selfpromo`…
    public let category: String
    /// `skip` for a segment to jump over; others (`mute`, `poi`, `chapter`)
    /// aren't skips.
    public let actionType: String
    public let start: Double
    public let end: Double

    public init(
        uuid: String,
        category: String,
        actionType: String,
        start: Double,
        end: Double
    ) {
        self.uuid = uuid
        self.category = category
        self.actionType = actionType
        self.start = start
        self.end = end
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(String.self, forKey: .uuid)
        category = try container.decode(String.self, forKey: .category)
        actionType = try container.decode(String.self, forKey: .actionType)
        let bounds = try container.decode([Double].self, forKey: .segment)
        guard bounds.count == 2 else {
            throw DecodingError.dataCorruptedError(
                forKey: .segment,
                in: container,
                debugDescription: "A segment is a [start, end] pair"
            )
        }
        start = bounds[0]
        end = bounds[1]
    }

    /// Worth jumping over: a `skip` action covering some time.
    public var isSkippable: Bool {
        actionType == "skip" && start >= 0 && end > start
    }

    enum CodingKeys: String, CodingKey {
        case uuid = "UUID"
        case category
        case actionType
        case segment
    }
}

extension VideoResponse {
    /// The time ranges playback should jump over, earliest first. Empty
    /// unless the server has SponsorBlock switched on for this video.
    public var sponsorSkipRanges: [Range<Double>] {
        guard let sponsorblock, sponsorblock.isEnabled else { return [] }
        return sponsorblock.segments
            .filter(\.isSkippable)
            .map { $0.start..<$0.end }
            .sorted { $0.lowerBound < $1.lowerBound }
    }
}
