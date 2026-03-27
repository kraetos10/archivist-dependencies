import Lottie
import SwiftUI

public enum LottieAnimationFile: String {
    case server = "server_animation"
    case credentials = "credentials_animation"
    case channel = "channel_animation"
    case playlist = "playlist_animation"
    case video = "video_animation"

    public var animation: LottieAnimation? {
        guard let path = Bundle.module.path(forResource: rawValue, ofType: "json") else { return nil }
        return LottieAnimation.filepath(path)
    }
}
