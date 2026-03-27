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
                    LazyVGrid(columns: columns, spacing: 16) {
                        if store.isLoading && store.videos.isEmpty {
                            ForEach(VideoResponse.placeholders) { video in
                                VideoCardView(
                                    video: video,
                                    serverConfig: store.serverConfig
                                )
                                .redacted(reason: .placeholder)
                            }
                        } else {
                            ForEach(store.displayedItems) { item in
                                let isSelected = store.selectedVideoIds.contains(item.id)
                                Group {
                                    switch item {
                                    case .video(let video):
                                        VideoCardView(
                                            video: video,
                                            serverConfig: store.serverConfig
                                        )
                                    case .download(let download):
                                        VideoCardView(
                                            download: download,
                                            serverConfig: store.serverConfig
                                        )
                                    }
                                }
                                .overlay(alignment: .topTrailing) {
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(Color.Accent.dark)
                                            .background(Circle().fill(.white))
                                            .padding(8)
                                    }
                                }
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
                    .padding()
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
        }
    }
}
#endif
