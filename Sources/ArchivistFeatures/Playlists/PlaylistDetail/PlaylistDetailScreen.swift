import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: PlaylistDetailReducer.self)
public struct PlaylistDetailScreen: View {
    @Bindable public var store: StoreOf<PlaylistDetailReducer>

    public init(store: StoreOf<PlaylistDetailReducer>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                headerView

                Section {
                    entriesContent
                } header: {
                    PinnedSectionHeader(title: String.localised("generic.videos", table: .generic))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(Color.Brand.primary)
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .safeAreaInset(edge: .bottom) {
            if store.isCustomPlaylist {
                FloatingAddButton { send(.addVideoTapped) }
            }
        }
        .toolbar {
            #if !os(tvOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if !store.isCustomPlaylist, let youtubeURL = store.playlist.youtubeURL {
                        ShareLink(item: youtubeURL) {
                            Label(
                                String.localised("generic.share", table: .generic),
                                systemImage: "square.and.arrow.up"
                            )
                        }
                    }

                    Button(role: .destructive) {
                        send(.unsubscribeTapped)
                    } label: {
                        Label(
                            store.isCustomPlaylist
                                ? String.localised("generic.delete", table: .generic)
                                : String.localised("video.removePlaylist", table: .videos),
                            systemImage: "trash"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3.weight(.semibold))
                }
            }
            #endif
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        #if !os(tvOS)
        .sheet(item: $store.scope(state: \.videoPicker, action: \.videoPicker)) { pickerStore in
            VideoPickerScreen(store: pickerStore)
        }
        #endif
        .onAppear { send(.viewDidAppear) }
        .onChange(of: store.playlist.playlistId) {
            send(.viewDidAppear)
        }
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            bannerView

            Text(store.playlist.playlistName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.Text.primary)

            if let channel = store.playlist.playlistChannel {
                Text(channel)
                    .font(.subheadline)
                    .foregroundStyle(Color.Brand.secondary)
            }

            Text("\(store.playlist.entryCount) videos")
                .font(.caption)
                .foregroundStyle(Color.Brand.secondary)

            if let description = store.playlist.playlistDescription,
               !description.isEmpty,
               description.lowercased() != "false" {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.Text.primary)
                    .lineLimit(4)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 16)
    }

    private let bannerHeight: CGFloat = 180

    private var bannerView: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .scrollView).minY
            let stretchOffset = max(minY, 0)
            let height = bannerHeight + stretchOffset

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
            .frame(width: geo.size.width, height: height)
            .clipped()
            .offset(y: -stretchOffset)
        }
        .frame(height: bannerHeight)
    }

    private var bannerPlaceholder: some View {
        Rectangle()
            .fill(Color.Surface.highlight)
    }

    @ViewBuilder
    private var entriesContent: some View {
        if store.isLoadingEntries && store.entries.isEmpty {
            ProgressView()
                .tint(Color.Progress.tint)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
        } else if store.entries.isEmpty && store.hasLoadedEntries {
            Text(String.localised("video.empty.noVideos", table: .videos))
                .font(.subheadline)
                .foregroundStyle(Color.Brand.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                    let isAvailable = entry.youtubeId.map { store.availableVideoIDs.contains($0) } ?? false
                    entryRow(entry, index: index, isAvailable: isAvailable)
                        .pressable {
                            if isAvailable {
                                send(.entryTapped(entry))
                            } else {
                                send(.queueServerDownloadTapped(entry))
                            }
                        }
                        #if !os(tvOS)
                        .contextMenu {
                            if let videoId = entry.youtubeId,
                               let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)") {
                                ShareLink(item: url) {
                                    Label(
                                        String.localised("generic.share", table: .generic),
                                        systemImage: "square.and.arrow.up"
                                    )
                                }
                            }

                            Button {
                                send(.downloadToDeviceTapped(entry))
                            } label: {
                                Label(
                                    String.localised("video.downloadToDevice", table: .videos),
                                    systemImage: "arrow.down.circle"
                                )
                            }

                            Button {
                                send(.markAsWatchedTapped(entry))
                            } label: {
                                Label(
                                    String.localised("video.markAsWatched", table: .videos),
                                    systemImage: "eye"
                                )
                            }

                            if store.isCustomPlaylist {
                                Button(role: .destructive) {
                                    send(.removeEntryTapped(entry))
                                } label: {
                                    Label(
                                        String.localised("video.removeFromPlaylist", table: .videos),
                                        systemImage: "minus.circle"
                                    )
                                }
                            }
                        }
                        #endif
                        .transition(.asymmetric(
                            insertion: .identity,
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .animation(.default, value: store.entries.map(\.id))
            .padding(.bottom, 24)
        }
    }

    private func entryRow(
        _ entry: PlaylistEntry,
        index: Int,
        isAvailable: Bool = true
    ) -> some View {
        HStack {
            VideoRowView(
                title: entry.title ?? "",
                subtitle: entry.uploader,
                thumbnailURL: entry.youtubeId.flatMap { store.entryThumbURLs[$0] }
            )

            if !isAvailable {
                Image(systemName: "arrow.down.circle")
                    .font(.title3)
                    .foregroundStyle(Color.Accent.dark)
                    .padding(.trailing, 16)
            }
        }
        .opacity(isAvailable ? 1 : 0.6)
    }

}
