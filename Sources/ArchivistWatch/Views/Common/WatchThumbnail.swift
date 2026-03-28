#if os(watchOS)
import ArchivistNetworking
import SwiftUI

@MainActor @Observable
final class ThumbnailLoader {
    var image: Image?

    func load(
        path: String,
        config: ServerConfig
    ) async {
        guard let url = config.fullURL(for: path) else { return }
        await load(url: url, config: config)
    }

    func load(
        url: URL,
        config: ServerConfig
    ) async {
        var request = URLRequest(url: url)
        if url.host == config.baseURL || url.host?.contains(config.baseURL) == true {
            for (key, value) in config.authHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let uiImage = UIImage(data: data) {
                image = Image(uiImage: uiImage)
            }
        } catch {}
    }
}

public struct WatchThumbnail: View {
    let path: String?
    let resolvedURL: URL?
    let config: ServerConfig
    let width: CGFloat
    let aspectRatio: CGFloat

    @State private var loader = ThumbnailLoader()

    public init(
        path: String?,
        config: ServerConfig,
        width: CGFloat = 60,
        aspectRatio: CGFloat = 16 / 9
    ) {
        self.path = path
        self.resolvedURL = nil
        self.config = config
        self.width = width
        self.aspectRatio = aspectRatio
    }

    public init(
        url: URL?,
        config: ServerConfig,
        width: CGFloat = 60,
        aspectRatio: CGFloat = 16 / 9
    ) {
        self.path = nil
        self.resolvedURL = url
        self.config = config
        self.width = width
        self.aspectRatio = aspectRatio
    }

    private var taskID: String? {
        path ?? resolvedURL?.absoluteString
    }

    public var body: some View {
        Group {
            if let image = loader.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.secondary.opacity(0.3))
            }
        }
        .frame(width: width, height: width / aspectRatio)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task(id: taskID) {
            if let path {
                await loader.load(path: path, config: config)
            } else if let resolvedURL {
                await loader.load(url: resolvedURL, config: config)
            }
        }
    }
}

public struct WatchChannelThumb: View {
    let path: String?
    let config: ServerConfig
    let size: CGFloat

    @State private var loader = ThumbnailLoader()

    public init(
        path: String?,
        config: ServerConfig,
        size: CGFloat = 32
    ) {
        self.path = path
        self.config = config
        self.size = size
    }

    public var body: some View {
        Group {
            if let image = loader.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Circle()
                    .fill(.secondary.opacity(0.3))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: path) {
            guard let path else { return }
            await loader.load(path: path, config: config)
        }
    }
}
#endif
