#if os(tvOS)
import ArchivistNetworking
import SwiftUI

public struct TVPlaylistCardView: View {
    public let playlist: PlaylistResponse
    public let serverConfig: ServerConfig
    public var action: () -> Void = {}

    @FocusState private var isFocused: Bool

    public init(
        playlist: PlaylistResponse,
        serverConfig: ServerConfig,
        action: @escaping () -> Void = {}
    ) {
        self.playlist = playlist
        self.serverConfig = serverConfig
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                thumbnailView
                    .tvCardFocusEffect(isFocused)
                infoView
            }
        }
        .buttonStyle(TVCardButtonStyle())
        .focused($isFocused)
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
        .clipShape(RoundedRectangle(cornerRadius: TVLayout.cornerRadius))
    }

    private var infoView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Heights are reserved so playlist cards match video cards
            // (two-line title, then two single-line rows) in mixed rows.
            Text(playlist.playlistName)
                .font(.headline)
                .lineLimit(2, reservesSpace: true)

            Text(playlist.playlistChannel ?? " ")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 8) {
                Image(systemName: "list.bullet")
                    .font(.subheadline)
                    .accessibilityHidden(true)
                Text(String.localised("\(playlist.entryCount) videos"))
                    .font(.subheadline)
                    .lineLimit(1)
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
#endif
