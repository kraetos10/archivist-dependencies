#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

@ViewAction(for: VideoDetailReducer.self)
public struct ChildVideoPlayerScreen: View {
    @Bindable public var store: StoreOf<VideoDetailReducer>
    @State private var overlayShown: Bool = true
    @State private var hideTask: Task<Void, Never>?

    public init(store: StoreOf<VideoDetailReducer>) {
        self.store = store
    }

    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    private var cardWidth: CGFloat { isPhone ? 140 : 200 }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            playerLayer

            VStack(alignment: .leading, spacing: 0) {
                topBar
                Spacer()
                if !store.similarVideos.isEmpty {
                    similarVideosOverlay
                        .padding(.bottom, 80)
                }
            }
            .opacity(overlayShown ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: overlayShown)
            .allowsHitTesting(overlayShown)
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .bottomBar)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            send(.viewDidAppear)
            scheduleAutoHide()
        }
        .onDisappear { hideTask?.cancel() }
        .onChange(of: store.video.videoId) {
            send(.videoChanged)
            overlayShown = true
            scheduleAutoHide()
        }
        .onChange(of: store.isPlaying) { _, playing in
            if playing {
                scheduleAutoHide()
            } else {
                hideTask?.cancel()
                overlayShown = true
            }
        }
    }

    @ViewBuilder
    private var playerLayer: some View {
        if store.isPlaying {
            VLCPlayerView()
                .ignoresSafeArea()
                .simultaneousGesture(
                    TapGesture().onEnded { toggleOverlay() }
                )
        } else {
            thumbnailLayer
        }
    }

    private var thumbnailLayer: some View {
        ZStack {
            Color.black

            if let thumbURL,
               let url = store.serverConfig.fullURL(for: thumbURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    default:
                        Color.black
                    }
                }
            }

            Image(systemName: "play.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.white.opacity(0.95))
                .shadow(radius: 8)
        }
        .contentShape(Rectangle())
        .onTapGesture { send(.playTapped) }
    }

    private var topBar: some View {
        HStack {
            Button { send(.dismissTapped) } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.5), in: Circle())
            }
            Spacer()
        }
        .padding(.top, 56)
        .padding(.leading, 56)
        .padding(.trailing, 16)
    }

    private var similarVideosOverlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String.localised("video.similarVideos", table: .videos))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 56)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.similarVideos) { video in
                        Button {
                            send(.similarVideoTapped(video))
                        } label: {
                            SimilarVideoCard(
                                video: video,
                                serverConfig: store.serverConfig
                            )
                            .frame(width: cardWidth)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 56)
            }
        }
        .padding(.vertical, 8)
        .background(LinearGradient(
            colors: [.black.opacity(0), .black.opacity(0.6)],
            startPoint: .top,
            endPoint: .bottom
        ))
    }

    private var thumbURL: String? {
        store.video.vidThumbUrl
    }

    private func toggleOverlay() {
        overlayShown.toggle()
        if overlayShown { scheduleAutoHide() } else { hideTask?.cancel() }
    }

    private func scheduleAutoHide() {
        hideTask?.cancel()
        guard store.isPlaying, overlayShown else { return }
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if !Task.isCancelled, store.isPlaying {
                overlayShown = false
            }
        }
    }
}
#endif
