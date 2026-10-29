#if !os(watchOS)
import CoreMedia
import Dependencies
import VideoToolbox

/// Whether this device has an AV1 hardware decoder (A17 Pro, M3 and later).
///
/// Where it does, 4K AV1 plays through VideoToolbox. Where it doesn't, the
/// only decoder left is software dav1d, which can crash on that video.
public enum AV1HardwareDecoding {
    public static var isSupported: Bool {
        VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)
    }
}

/// `AV1HardwareDecoding` as a dependency, so a reducer can warn before a
/// video that this device can't safely decode.
public struct AV1HardwareDecodingClient: Sendable {
    public var isSupported: @Sendable () -> Bool

    public init(isSupported: @escaping @Sendable () -> Bool) {
        self.isSupported = isSupported
    }
}

extension AV1HardwareDecodingClient: DependencyKey {
    public static let liveValue = AV1HardwareDecodingClient { AV1HardwareDecoding.isSupported }
    /// Tests that care say which; the rest never meet an AV1 video.
    public static let testValue = AV1HardwareDecodingClient { true }
}

extension DependencyValues {
    public var av1HardwareDecoding: AV1HardwareDecodingClient {
        get { self[AV1HardwareDecodingClient.self] }
        set { self[AV1HardwareDecodingClient.self] = newValue }
    }
}
#endif
