import ArchivistNetworking
import Testing

@testable import ArchivistFeatures

/// Covers `VideoResponse.requiresSoftwareDecodingAtHighResolution`, which
/// gates the one-time "may not play smoothly" warning.
///
/// The rule has to be narrow in both directions: warning about content that
/// plays fine trains people to dismiss it, and staying quiet on 4K VP9 is
/// the case that actually stutters on an Apple TV.
struct SoftwareDecodeDetectionTests {
    private func video(
        codec: String?,
        width: Int?,
        height: Int?,
        type: String? = "video"
    ) -> VideoResponse {
        TestFixtures.videoWithStream(
            VideoStream(type: type, index: 0, codec: codec, width: width, height: height, bitrate: nil)
        )
    }

    // MARK: - Warns

    @Test(arguments: ["vp9", "VP9", "vp09.00.50.08", "av1", "av01.0.12M.08"])
    func warnsFor4KCodecsWithNoHardwareDecoder(codec: String) {
        #expect(video(codec: codec, width: 3840, height: 2160).requiresSoftwareDecodingAtHighResolution)
    }

    @Test func warnsAbove4K() {
        #expect(video(codec: "vp9", width: 7680, height: 4320).requiresSoftwareDecodingAtHighResolution)
    }

    /// Anamorphic and vertical sources can clear one axis but not the other.
    @Test func warnsWhenOnlyOneDimensionIs4K() {
        #expect(video(codec: "vp9", width: 3840, height: 1608).requiresSoftwareDecodingAtHighResolution)
        #expect(video(codec: "vp9", width: 2160, height: 3840).requiresSoftwareDecodingAtHighResolution)
    }

    // MARK: - Stays quiet

    @Test(arguments: ["h264", "avc1.640028", "hevc", "hvc1"])
    func staysQuietForHardwareDecodedCodecs(codec: String) {
        #expect(!video(codec: codec, width: 3840, height: 2160).requiresSoftwareDecodingAtHighResolution)
    }

    /// 1440p VP9 software-decodes acceptably, so warning would be noise.
    @Test func staysQuietBelow4K() {
        #expect(!video(codec: "vp9", width: 2560, height: 1440).requiresSoftwareDecodingAtHighResolution)
    }

    @Test func staysQuietWhenTheServerReportsNoStreams() {
        #expect(!TestFixtures.video1.requiresSoftwareDecodingAtHighResolution)
    }

    @Test func staysQuietWhenCodecOrSizeIsMissing() {
        #expect(!video(codec: nil, width: 3840, height: 2160).requiresSoftwareDecodingAtHighResolution)
        #expect(!video(codec: "vp9", width: nil, height: nil).requiresSoftwareDecodingAtHighResolution)
    }

    /// The audio stream must never be what the check reads.
    @Test func ignoresNonVideoStreams() {
        #expect(!video(codec: "vp9", width: 3840, height: 2160, type: "audio")
            .requiresSoftwareDecodingAtHighResolution)
    }
}
