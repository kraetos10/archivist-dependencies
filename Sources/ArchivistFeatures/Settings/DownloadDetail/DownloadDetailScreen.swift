#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI
import ArchivistComponents

@ViewAction(for: DownloadDetailReducer.self)
public struct DownloadDetailScreen: View {
    public let store: StoreOf<DownloadDetailReducer>

    public init(store: StoreOf<DownloadDetailReducer>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            thumbnailView

            VStack(alignment: .leading, spacing: 8) {
                Text(store.download.title ?? store.download.youtubeId)
                    .font(.headline)
                    .foregroundStyle(Color.Text.primary)

                if let channelName = store.download.channelName {
                    Text(channelName)
                        .font(.subheadline)
                        .foregroundStyle(Color.Brand.secondary)
                }

                HStack {
                    HStack(spacing: 8) {
                        statusBadge

                        if let published = store.download.publishedRelative {
                            Text(published)
                                .font(.caption)
                                .foregroundStyle(Color.Brand.secondary)
                        }

                        if let duration = store.download.duration {
                            Text(duration)
                                .font(.caption)
                                .foregroundStyle(Color.Brand.secondary)
                        }
                    }

                    Spacer()

                    #if !os(tvOS)
                    ShareLink(item: store.youtubeURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundStyle(Color.Text.primary)
                    }
                    #endif
                }
                .padding(.top, 2)

                Spacer(minLength: 0)

                HStack(spacing: 12) {
                    downloadButton
                    deleteButton
                }
                .padding(.top, 8)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

        }
        .background(Color.Brand.primary)
        .navigationTitle(store.download.title ?? store.download.youtubeId)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { send(.viewDidAppear) }
    }

    private var thumbnailView: some View {
        Group {
            if let thumbURL = store.thumbURL {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16 / 9, contentMode: .fill)
                    default:
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
            .aspectRatio(16 / 9, contentMode: .fit)
    }

    private var statusBadge: some View {
        Text(String.localised("generic.pending"))
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.Accent.dark)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var downloadButton: some View {
        Button {
            send(.downloadTapped)
        } label: {
            HStack(spacing: 8) {
                if store.isDownloading {
                    ProgressView()
                        .tint(.white)
                } else if store.downloadTriggered {
                    Image(systemName: "checkmark.circle.fill")
                    Text(String.localised("video.downloadQueued", table: .videos))
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                    Text(String.localised("video.downloadNow", table: .videos))
                }
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(store.downloadTriggered ? Color.Brand.secondary : Color.Accent.dark)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(store.isDownloading || store.downloadTriggered)
    }

    private var deleteButton: some View {
        Button {
            send(.deleteTapped)
        } label: {
            Group {
                if store.isDeleting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "trash")
                }
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(width: 44)
            .padding(.vertical, 12)
            .background(.red)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(store.isDeleting)
    }
}
#endif
