#if os(watchOS)
import ArchivistNetworking
import SwiftUI
import UIKit

@MainActor
@Observable
final class ThumbnailLoader {
    private(set) var image: Image?

    /// Loads `url`, sending the API token only when the URL is on the
    /// configured server — an exact host match, so artwork from YouTube or a
    /// lookalike host never receives it.
    func load(
        url: URL,
        config: ServerConfig
    ) async {
        var request = URLRequest(url: url)
        if config.isServerURL(url) {
            for (key, value) in config.authHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let uiImage = UIImage(data: data) else { return }
        image = Image(uiImage: uiImage)
    }
}

public struct WatchThumbnail: View {
    let url: URL?
    let config: ServerConfig
    let width: Double
    let aspectRatio: Double

    @State private var loader = ThumbnailLoader()

    public init(
        url: URL?,
        config: ServerConfig,
        width: Double = 60,
        aspectRatio: Double = 16 / 9
    ) {
        self.url = url
        self.config = config
        self.width = width
        self.aspectRatio = aspectRatio
    }

    public var body: some View {
        Group {
            if let image = loader.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.quaternary)
            }
        }
        .frame(width: width, height: width / aspectRatio)
        .clipShape(.rect(cornerRadius: 6))
        .accessibilityHidden(true)
        .task(id: url) {
            guard let url else { return }
            await loader.load(url: url, config: config)
        }
    }
}

public struct WatchChannelThumb: View {
    let url: URL?
    let config: ServerConfig
    let size: Double

    @State private var loader = ThumbnailLoader()

    public init(
        url: URL?,
        config: ServerConfig,
        size: Double = 32
    ) {
        self.url = url
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
                    .fill(.quaternary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
        .task(id: url) {
            guard let url else { return }
            await loader.load(url: url, config: config)
        }
    }
}
#endif
