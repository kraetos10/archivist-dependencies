#if os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: PlaylistDetailReducer.self)
public struct TVPlaylistDetailScreen: View {
    @Bindable public var store: StoreOf<PlaylistDetailReducer>

    public init(store: StoreOf<PlaylistDetailReducer>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                headerView
                    .focusSection()

                Section {
                    entriesContent
                } header: {
                    PinnedSectionHeader(title: String.localised("generic.videos"))
                }
                .focusSection()
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear { send(.viewDidAppear) }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 16) {
            bannerView

            Text(store.playlist.playlistName)
                .font(.title2)
                .fontWeight(.bold)

            if let channel = store.playlist.playlistChannel {
                Text(channel)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Text("\(store.playlist.entryCount) videos")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let description = store.playlist.playlistDescription, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 80)
            }
        }
        .padding(.bottom, 32)
    }

    private let bannerHeight: CGFloat = 300

    private var bannerView: some View {
        Group {
            if let thumbURL = store.playlistThumbURL {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        bannerPlaceholder
                    }
                }
            } else {
                bannerPlaceholder
            }
        }
        .frame(height: bannerHeight)
        .clipped()
    }

    private var bannerPlaceholder: some View {
        Rectangle()
            .fill(.secondary.opacity(0.2))
            .frame(height: bannerHeight)
    }

    // MARK: - Sections

    private var entriesContent: some View {
        VStack(spacing: 0) {
            if store.isLoadingEntries && store.entries.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
            } else if store.entries.isEmpty && store.hasLoadedEntries {
                Text(String.localised("video.empty.noVideos", table: .videos))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
            } else {
                ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                    Button {
                        send(.entryTapped(entry))
                    } label: {
                        entryRow(entry, index: index)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 48)
    }

    private func entryRow(_ entry: PlaylistEntry, index: Int) -> some View {
        HStack(spacing: 24) {
            if let thumbURL = entry.thumbURL(config: store.serverConfig) {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16 / 9, contentMode: .fill)
                    default:
                        Rectangle()
                            .fill(.secondary.opacity(0.3))
                            .aspectRatio(16 / 9, contentMode: .fill)
                    }
                }
                .frame(width: 240, height: 135)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .fill(.secondary.opacity(0.3))
                    .frame(width: 240, height: 135)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title ?? "")
                    .font(.headline)
                    .lineLimit(2)

                if let uploader = entry.uploader {
                    Text(uploader)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 12)
    }
}
#endif
