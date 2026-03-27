import ArchivistNetworking
import SwiftUI

public struct TVPlaylistCardView: View {
    public let playlist: PlaylistResponse
    public let serverConfig: ServerConfig
    public var action: () -> Void = {}

    @FocusState private var isFocused: Bool

    public init(playlist: PlaylistResponse, serverConfig: ServerConfig, action: @escaping () -> Void = {}) {
        self.playlist = playlist
        self.serverConfig = serverConfig
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                thumbnailView
                infoView
            }
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .shadow(radius: isFocused ? 16 : 4)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }

    private var thumbnailView: some View {
        Group {
            if let thumbURL = playlist.thumbURL(config: serverConfig) {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16 / 9, contentMode: .fill)
                    case .failure:
                        thumbnailPlaceholder
                    case .empty:
                        thumbnailPlaceholder
                            .overlay { ProgressView() }
                    @unknown default:
                        thumbnailPlaceholder
                    }
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var infoView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(playlist.playlistName)
                .font(.headline)
                .lineLimit(2)

            if let channel = playlist.playlistChannel {
                Text(channel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("")
            }

            HStack(spacing: 4) {
                Image(systemName: "list.bullet")
                    .font(.caption)
                Text("\(playlist.entryCount) videos")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
        }
    }

    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(.secondary.opacity(0.3))
            .aspectRatio(16 / 9, contentMode: .fill)
            .overlay {
                Image(systemName: "music.note.list")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
    }
}
