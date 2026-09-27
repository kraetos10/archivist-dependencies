#if os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: PlaylistDetailReducer.self)
public struct TVPlaylistDetailScreen: View {
    @Bindable public var store: StoreOf<PlaylistDetailReducer>

    private enum HeaderFocus: Hashable {
        case loop
        case description
    }

    /// Focusing anything in the header scrolls the whole header (banner
    /// included) back into view, not just the focused control.
    @FocusState private var headerFocus: HeaderFocus?

    public init(store: StoreOf<PlaylistDetailReducer>) {
        self.store = store
    }

    private static let headerID = "playlistHeader"

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    headerView
                        .id(Self.headerID)
                        .focusSection()

                    Section {
                        entriesContent
                    } header: {
                        PinnedSectionHeader(title: String.localised("generic.videos", table: .generic))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 48)
            }
            .onChange(of: headerFocus) { _, focus in
                guard focus != nil else { return }
                withAnimation { proxy.scrollTo(Self.headerID, anchor: .top) }
            }
        }
        .onAppear { send(.viewDidAppear) }
        .fullScreenCover(isPresented: $store.isShowingFullDescription) {
            TVFullDescriptionView(
                title: store.playlist.playlistName,
                blocks: store.descriptionBlocks
            )
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 16) {
            TVDetailBannerView(url: store.playlistThumbURL)

            VStack(spacing: 8) {
                Text(store.playlist.playlistName)
                    .font(.title2)
                    .fontWeight(.bold)

                if let channel = store.playlist.playlistChannel {
                    Text(channel)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Text(String.localised("playlist.entryCount \(store.playlist.entryCount)", table: .videos))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Button {
                send(.loopToggled)
            } label: {
                Label(
                    String.localised("video.loopPlaylist", table: .videos),
                    systemImage: store.loopPlaylistEnabled ? "repeat.circle.fill" : "repeat"
                )
            }
            .focused($headerFocus, equals: .loop)

            if let description = store.displayDescription,
               !store.descriptionBlocks.isEmpty {
                TVDescriptionCard(text: description) {
                    send(.descriptionTapped)
                }
                .focused($headerFocus, equals: .description)
                .padding(.top, 8)
            }
        }
        .padding(.top, TVLayout.rowVerticalPadding)
        .padding(.bottom, 32)
    }

    // MARK: - Sections

    @ViewBuilder
    private var entriesContent: some View {
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
            // Direct children of the lazy stack, so rows are built as
            // they scroll in rather than all up front.
            // Read once per pass: builds a dictionary over every entry.
            let thumbURLs = store.entryThumbURLs
            ForEach(store.entries) { entry in
                TVPlaylistEntryRow(
                    entry: entry,
                    thumbURL: entry.youtubeId.flatMap { thumbURLs[$0] },
                    isAvailable: store.state.isEntryAvailable(entry)
                ) {
                    send(.entryTapped(entry))
                }
            }
        }
    }
}

/// A playlist entry: the thumbnail takes the shared card focus treatment
/// and the text stays put, as on every other tvOS card.
private struct TVPlaylistEntryRow: View {
    let entry: PlaylistEntry
    let thumbURL: URL?
    let isAvailable: Bool
    let action: () -> Void

    @FocusState private var isFocused: Bool

    private static let thumbSize = CGSize(width: 240, height: 135)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 32) {
                thumbnail
                    .tvCardFocusEffect(isFocused)

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

                if !isAvailable {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                        .foregroundStyle(Color.Accent.dark)
                        .accessibilityLabel(
                            String.localised("playlist.notOnServer", table: .videos)
                        )
                }
            }
            .opacity(isAvailable ? 1 : 0.6)
            // Room for the lifted thumbnail and its shadow.
            .padding(.vertical, 20)
        }
        .buttonStyle(TVCardButtonStyle())
        .focused($isFocused)
    }

    private var thumbnail: some View {
        Group {
            if let thumbURL {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16 / 9, contentMode: .fill)
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: Self.thumbSize.width, height: Self.thumbSize.height)
        .clipShape(RoundedRectangle(cornerRadius: TVLayout.cornerRadius))
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.secondary.opacity(0.3))
    }
}
#endif
