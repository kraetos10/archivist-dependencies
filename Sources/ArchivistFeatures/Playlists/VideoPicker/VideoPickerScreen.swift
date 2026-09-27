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
                                    thumbnailURL: nil,
                                    badge: video.durationStr
                                )
                                .redacted(reason: .placeholder)
                            }
                        } else {
                            ForEach(store.displayedItems) { item in
                                let isSelected = store.state.isSelected(item)
                                VideoRowView(
                                    title: item.pickerTitle,
                                    subtitle: item.pickerSubtitle,
                                    thumbnailURL: item.pickerThumbnailURL(config: store.serverConfig),
                                    badge: item.pickerBadge
                                )
                                .overlay(alignment: .trailing) {
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(Color.Accent.dark)
                                            .background(Circle().fill(.white))
                                            .padding(.trailing, 16)
                                            .accessibilityHidden(true)
                                    }
                                }
                                .background(isSelected ? Color.Accent.dark.opacity(0.08) : Color.clear)
                                .pressable {
                                    send(.videoToggled(item))
                                }
                                .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                            Text(String.localised("video.addSelected \(store.selectedVideoIds.count)", table: .videos))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                    }
                    .background(Color.Accent.dark)
                    .clipShape(.rect(cornerRadius: 12))
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
                    Button(
                        String.localised("generic.close", table: .generic),
                        systemImage: "xmark"
                    ) {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Color.Text.primary)
                }
            }
            .onAppear { send(.viewDidAppear) }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
#endif
