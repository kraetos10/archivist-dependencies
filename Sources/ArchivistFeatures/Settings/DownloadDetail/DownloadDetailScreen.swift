#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI
import ArchivistComponents

@ViewAction(for: DownloadDetailReducer.self)
public struct DownloadDetailScreen: View {
    @Bindable public var store: StoreOf<DownloadDetailReducer>

    public init(store: StoreOf<DownloadDetailReducer>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            thumbnailView

            VStack(alignment: .leading, spacing: 8) {
                Text(store.displayTitle)
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
                    if let youtubeURL = store.youtubeURL {
                        ShareLink(item: youtubeURL) {
                            Label(
                                String.localised("generic.share", table: .generic),
                                systemImage: "square.and.arrow.up"
                            )
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .foregroundStyle(Color.Text.primary)
                        }
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
        .navigationTitle(store.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(item: $store.scope(state: \.pinEntry, action: \.pinEntry)) { pinStore in
            PinEntrySheet(
                expectedPin: pinStore.expectedPin,
                subtitle: String.localised("childMode.pinEntry.download.subtitle", table: .login),
                onSuccess: { pinStore.send(.succeeded) },
                onCancel: { pinStore.send(.cancelled) }
            )
        }
    }

    private var thumbnailView: some View {
        GeometryReader { geo in
            if let thumbURL = store.thumbURL {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        thumbnailPlaceholder
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width * 9 / 16)
                .clipped()
            } else {
                thumbnailPlaceholder
                    .frame(width: geo.size.width, height: geo.size.width * 9 / 16)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
    }

    private var thumbnailPlaceholder: some View {
        Color.Brand.secondary.opacity(0.3)
    }

    private var statusBadge: some View {
        Text(String.localised("generic.pending", table: .generic))
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(Color.Accent.dark)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.Accent.dark.opacity(0.15), in: .rect(cornerRadius: 6))
    }

    /// Stays on the spinner once the request succeeds, rather than swapping
    /// in a "queued" confirmation.
    ///
    /// The screen dismisses itself on a successful request, so a success
    /// state here would render for a frame on the way out, resizing the
    /// button (and with it the popover) just as it disappears. The
    /// confirmation is the dismissal; the queued video is already visible
    /// in the list behind.
    /// Label height shared by the download and delete buttons, so the pair
    /// line up. The bordered style's own padding takes each button past the
    /// 44pt minimum tap target.
    private static let actionContentHeight: CGFloat = 32

    private var downloadButton: some View {
        Button {
            send(.downloadTapped)
        } label: {
            Group {
                if store.isDownloadBusy {
                    ProgressView()
                } else {
                    Label(
                        String.localised("video.downloadNow", table: .videos),
                        systemImage: "arrow.down.circle.fill"
                    )
                }
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, minHeight: Self.actionContentHeight)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.Accent.dark)
        .disabled(store.isDownloadBusy)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            send(.deleteTapped)
        } label: {
            Group {
                if store.isDeleting {
                    ProgressView()
                } else {
                    Label(
                        String.localised("generic.delete", table: .generic),
                        systemImage: "trash"
                    )
                    .labelStyle(.iconOnly)
                }
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .frame(minWidth: Self.actionContentHeight, minHeight: Self.actionContentHeight)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel(String.localised("generic.delete", table: .generic))
        .disabled(store.isDeleting)
    }
}
#endif
