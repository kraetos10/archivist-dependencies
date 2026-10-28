#if !os(watchOS)
import CoreMedia
import VideoToolbox

/// Whether this device has an AV1 hardware decoder (A17 Pro, M3 and later).
///
/// Where it does, 4K AV1 plays through VideoToolbox. Where it doesn't, the
/// only decoder left is software dav1d, which crashes on that video.
public enum AV1HardwareDecoding {
    public static var isSupported: Bool {
        VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)
    }
}
#endif
