#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import Lottie
import SwiftUI
import ArchivistComponents

@ViewAction(for: AddVideoReducer.self)
public struct AddVideoScreen: View {
    @Bindable public var store: StoreOf<AddVideoReducer>

    public init(store: StoreOf<AddVideoReducer>) {
        self.store = store
    }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool

    public var body: some View {
        NavigationStack {
            // Scrollable, with the Add button pinned above the keyboard: in
            // the medium detent the keyboard used to cover the button, and
            // there was no way to dismiss it to get back there.
            ScrollView {
                VStack(spacing: 16) {
                    LottieView(animation: LottieAnimationFile.video.animation)
                        .playing(loopMode: .playOnce)
                        .frame(width: 200, height: 200)

                    Toggle(
                        String.localised("video.fastAdd", table: .videos),
                        isOn: $store.fastAdd
                    )
                    .tint(Color.Accent.dark)

                    Toggle(
                        String.localised("video.reDownload", table: .videos),
                        isOn: $store.reDownload
                    )
                    .tint(Color.Accent.dark)

                    Toggle(
                        String.localised("video.autoDownload", table: .videos),
                        isOn: $store.autoDownload
                    )
                    .tint(Color.Accent.dark)

                    TextField(
                        String.localised("video.videoUrl", table: .videos),
                        text: $store.videoInput,
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .lineLimit(1...5)
                    .focused($isInputFocused)

                    Text(String.localised("video.pasteUrl", table: .videos))
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                addButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.Brand.primary)
            .navigationTitle(String.localised("video.addVideo", table: .videos))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // The URL field is multi-line, so Return adds a line rather
                // than closing the keyboard.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String.localised("generic.done", table: .generic)) {
                        isInputFocused = false
                    }
                }
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(isPresented: $store.isPresentingPin) {
            PinEntrySheet(
                expectedPin: store.expectedPin,
                subtitle: String.localised("childMode.pinEntry.addVideo.subtitle", table: .login),
                onSuccess: { send(.pinConfirmed) },
                onCancel: { send(.pinCancelled) }
            )
        }
    }

    private var addButton: some View {
        Button {
            send(.addButtonTapped)
        } label: {
            if store.isAdding {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            } else {
                Text(String.localised("video.addToQueue", table: .videos))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
        }
        .background(Color.Accent.dark)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(!store.canAdd)
    }
}
#endif
