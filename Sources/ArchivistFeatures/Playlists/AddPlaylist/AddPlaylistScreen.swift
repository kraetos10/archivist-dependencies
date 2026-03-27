import ArchivistNetworking
import ComposableArchitecture
import Lottie
import SwiftUI
import ArchivistComponents

#if !os(tvOS)
@ViewAction(for: AddPlaylistReducer.self)
public struct AddPlaylistScreen: View {
    @Bindable public var store: StoreOf<AddPlaylistReducer>

    public init(store: StoreOf<AddPlaylistReducer>) {
        self.store = store
    }

    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    LottieView(animation: LottieAnimationFile.playlist.animation)
                        .playing(loopMode: .playOnce)
                        .frame(width: 200, height: 200)

                    Picker("", selection: $store.mode) {
                        Text(String.localised("generic.subscribe"))
                            .tag(AddPlaylistMode.subscribe)
                        Text(String.localised("login.createCustom", table: .login))
                            .tag(AddPlaylistMode.createCustom)
                    }
                    .pickerStyle(.segmented)

                    switch store.mode {
                    case .subscribe:
                        subscribeTextField
                    case .createCustom:
                        createCustomTextField
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .safeAreaInset(edge: .bottom) {
                switch store.mode {
                case .subscribe:
                    subscribeButton
                case .createCustom:
                    createCustomButton
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.Brand.primary)
            .navigationTitle(String.localised("login.addPlaylist", table: .login))
            .navigationBarTitleDisplayMode(.inline)
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
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var subscribeTextField: some View {
        TextField(
            String.localised("login.playlistUrl", table: .login),
            text: $store.playlistInput
        )
        .textFieldStyle(.roundedBorder)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
    }

    private var subscribeButton: some View {
        Button {
            send(.addButtonTapped)
        } label: {
            if store.isSubscribing {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            } else {
                Text(String.localised("generic.subscribe"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
        }
        .background(Color.Accent.dark)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(store.playlistInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isSubscribing)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var createCustomTextField: some View {
        TextField(
            String.localised("login.customPlaylistName", table: .login),
            text: $store.customName
        )
        .textFieldStyle(.roundedBorder)
        .autocorrectionDisabled()
    }

    private var createCustomButton: some View {
        Button {
            send(.createCustomTapped)
        } label: {
            if store.isSubscribing {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            } else {
                Text(String.localised("login.createCustomPlaylist", table: .login))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
        }
        .background(Color.Accent.dark)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(store.customName.trimmingCharacters(in: .newlines).isEmpty || store.isSubscribing)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
#endif
