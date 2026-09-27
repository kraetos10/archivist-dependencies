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
                        .accessibilityHidden(true)

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
                .clipShape(.rect(cornerRadius: 12))
                .disabled(!store.canSubmit)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.Brand.primary)
            .navigationTitle(String.localised("login.addChannel", table: .login))
            .navigationBarTitleDisplayMode(.inline)
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
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(item: $store.pinRequest) { request in
            PinEntrySheet(
                expectedPin: request.expectedPin,
                subtitle: String.localised("childMode.pinEntry.addChannel.subtitle", table: .login),
                onSuccess: { send(.pinConfirmed) },
                onCancel: { send(.pinCancelled) }
            )
        }
    }
}
#endif
