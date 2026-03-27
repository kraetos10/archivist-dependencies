import ArchivistNetworking
import ComposableArchitecture
import Lottie
import SwiftUI
import ArchivistComponents

#if !os(tvOS)
@ViewAction(for: AddChannelReducer.self)
public struct AddChannelScreen: View {
    @Bindable public var store: StoreOf<AddChannelReducer>

    public init(store: StoreOf<AddChannelReducer>) {
        self.store = store
    }

    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    LottieView(animation: LottieAnimationFile.channel.animation)
                        .playing(loopMode: .playOnce)
                        .frame(width: 200, height: 200)

                    TextField(
                        String.localised("login.channelUrl", table: .login),
                        text: $store.channelInput
                    )
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    send(.addButtonTapped)
                } label: {
                    if store.isSubscribing {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    } else {
                        Text(String.localised("login.addChannel", table: .login))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                }
                .background(Color.Accent.dark)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(store.channelInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isSubscribing)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.Brand.primary)
            .navigationTitle(String.localised("login.addChannel", table: .login))
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
}
#endif
