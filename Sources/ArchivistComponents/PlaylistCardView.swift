import ArchivistNetworking
import SwiftUI

public struct PlaylistCardView: View {
    public let playlist: PlaylistResponse
    public let serverConfig: ServerConfig

    public init(
        playlist: PlaylistResponse,
        serverConfig: ServerConfig
    ) {
        self.playlist = playlist
        self.serverConfig = serverConfig
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnailView

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.playlistName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Text.primary)
                    .truncationMode(.middle)
                    .lineLimit(2)

                Text(playlist.playlistChannel ?? " ")
                    .font(.caption)
                    .foregroundStyle(Color.Brand.secondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.caption2)
                    Text("\(playlist.entryCount) videos")
                        .font(.caption)
                }
                .foregroundStyle(Color.Brand.secondary)
            }
            .padding(12)
        }
        .background(Color.Surface.highlight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
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
                            .overlay {
                                ProgressView()
                                    .tint(Color.Progress.tint)
                            }
                    @unknown default:
                        thumbnailPlaceholder
                    }
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipped()
    }

    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(Color.Brand.secondary.opacity(0.3))
            .aspectRatio(16 / 9, contentMode: .fill)
            .overlay {
                Image(systemName: "music.note.list")
                    .font(.title)
                    .foregroundStyle(Color.Brand.secondary)
            }
    }
}
