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
                    PinnedSectionHeader(title: String.localised("generic.videos"))
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
            if store.isCustomPlaylist {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        send(.editTapped)
                    } label: {
                        Text(store.isEditing ? String.localised("generic.done") : String.localised("generic.edit"))
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ShareLink(item: store.playlist.youtubeURL) {
                        Label(String.localised("generic.share"), systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        send(.unsubscribeTapped)
                    } label: {
                        Label(String.localised("video.removePlaylist", table: .videos), systemImage: "trash")
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

            if let description = store.playlist.playlistDescription, !description.isEmpty {
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
        } else if store.isEditing {
            List {
                ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                    entryRow(entry, index: index)
                }
                .onMove { source, destination in
                    send(.moveEntry(source, destination))
                }
                .onDelete { offsets in
                    for index in offsets {
                        send(.removeEntryTapped(store.entries[index]))
                    }
                }
            }
            .listStyle(.plain)
            #if !os(tvOS)
            .scrollContentBackground(.hidden)
            #endif
            .frame(minHeight: CGFloat(store.entries.count) * 84)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                    entryRow(entry, index: index)
                        .pressable {
                            send(.entryTapped(entry))
                        }
                        #if !os(tvOS)
                        .contextMenu {
                            if store.isCustomPlaylist {
                                Button(role: .destructive) {
                                    send(.removeEntryTapped(entry))
                                } label: {
                                    Label(String.localised("video.removeFromPlaylist", table: .videos), systemImage: "minus.circle")
                                }
                            }
                        }
                        #endif
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func entryRow(_ entry: PlaylistEntry, index: Int) -> some View {
        HStack(spacing: 12) {
            if let videoId = entry.youtubeId, let thumbURL = store.entryThumbURLs[videoId] {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16 / 9, contentMode: .fill)
                    default:
                        Rectangle()
                            .fill(Color.Brand.secondary.opacity(0.3))
                            .aspectRatio(16 / 9, contentMode: .fill)
                    }
                }
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .fill(Color.Brand.secondary.opacity(0.3))
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title ?? "")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Text.primary)
                    .lineLimit(2)

                if let uploader = entry.uploader {
                    Text(uploader)
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

}
