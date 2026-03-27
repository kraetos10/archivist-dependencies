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

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                LottieView(animation: LottieAnimationFile.video.animation)
                    .playing(loopMode: .playOnce)
                    .frame(width: 200, height: 200)

                TextField(
                    String.localised("video.videoUrl", table: .videos),
                    text: $store.videoInput,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .lineLimit(1...5)

                Text(String.localised("video.pasteUrl", table: .videos))
                    .font(.caption)
                    .foregroundStyle(Color.Brand.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
                .disabled(store.videoInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isAdding)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.Brand.primary)
            .navigationTitle(String.localised("video.addVideo", table: .videos))
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
