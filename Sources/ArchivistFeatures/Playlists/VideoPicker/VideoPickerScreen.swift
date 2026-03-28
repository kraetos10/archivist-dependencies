#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: VideoPickerReducer.self)
public struct VideoPickerScreen: View {
    @Bindable public var store: StoreOf<VideoPickerReducer>

    public init(store: StoreOf<VideoPickerReducer>) {
        self.store = store
    }
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible())]

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if store.isLoading && store.videos.isEmpty {
                            ForEach(VideoResponse.placeholders) { video in
                                VideoRowView(
                                    title: video.title,
                                    subtitle: video.channelName,
                                    thumbnailURL: video.vidThumbUrl.flatMap { store.serverConfig.fullURL(for: $0) },
                                    badge: video.durationStr
                                )
                                .redacted(reason: .placeholder)
                            }
                        } else {
                            ForEach(store.displayedItems) { item in
                                let isSelected = store.selectedVideoIds.contains(item.id)
                                pickerRow(for: item)
                                    .overlay(alignment: .trailing) {
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(Color.Accent.dark)
                                                .background(Circle().fill(.white))
                                                .padding(.trailing, 16)
                                        }
                                    }
                                    .background(isSelected ? Color.Accent.dark.opacity(0.08) : Color.clear)
                                    .pressable {
                                        send(.videoToggled(item))
                                    }
                                    .onAppear {
                                        if item.id == store.lastVideoId {
                                            send(.lastItemAppeared)
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.bottom, 80)

                    if store.isLoadingMore {
                        ProgressView()
                            .tint(Color.Progress.tint)
                            .padding()
                    }
                }
                .background(Color.Brand.primary)

                if !store.selectedVideoIds.isEmpty {
                    Button {
                        send(.addTapped)
                    } label: {
                        if store.isAdding {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        } else {
                            Text("Add \(store.selectedVideoIds.count)")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                    }
                    .background(Color.Accent.dark)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(store.isAdding)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle(String.localised("video.addVideos", table: .videos))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $store.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: String.localised("video.search", table: .videos)
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.Text.primary)
                    }
                }
            }
            .onAppear { send(.viewDidAppear) }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }

    private func pickerRow(for item: VideoListItem) -> some View {
        switch item {
        case .video(let video):
            VideoRowView(
                title: video.title,
                subtitle: "\(video.channelName) · \(video.publishedFormatted ?? "")",
                thumbnailURL: video.vidThumbUrl.flatMap { store.serverConfig.fullURL(for: $0) },
                badge: video.durationStr
            )
        case .download(let download):
            VideoRowView(
                title: download.title ?? "",
                subtitle: download.channelName ?? "",
                thumbnailURL: download.thumbURL(config: store.serverConfig),
                badge: download.duration
            )
        }
    }
}
#endif
