#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import Lottie
import SwiftUI

@ViewAction(for: ServerSetupReducer.self)
public struct ServerSetupScreen: View {
    @Bindable public var store: StoreOf<ServerSetupReducer>

    public init(store: StoreOf<ServerSetupReducer>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ServerSetupContentView(store: store)
        } destination: { store in
            switch store.case {
            case .login(let loginStore):
                LoginScreen(store: loginStore)
            }
        }
        .interactiveDismissDisabled()
    }
}

#Preview {
    ServerSetupScreen(
        store: Store(initialState: ServerSetupReducer.State()) {
            ServerSetupReducer()
        }
    )
}

@ViewAction(for: ServerSetupReducer.self)
private struct ServerSetupContentView: View {
    @Bindable var store: StoreOf<ServerSetupReducer>

    public var body: some View {
        VStack(spacing: 32) {
            LottieView(animation: LottieAnimationFile.server.animation)
                .playing(loopMode: .playOnce)
                .frame(width: 200, height: 200)

            VStack(spacing: 16) {
                Text("TubeArchivist")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.Text.primary)

                Text("Connect to your server")
                    .font(.headline)
                    .foregroundStyle(Color.Brand.secondary)
            }

            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server URL")
                        .font(.subheadline)
                        .foregroundStyle(Color.Text.primary)
                    TextField("Server URL", text: $store.registrationDetails.serverAddress)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Port")
                        .font(.subheadline)
                        .foregroundStyle(Color.Text.primary)
                    TextField("Port", text: $store.registrationDetails.port)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }

                Toggle("Use HTTP", isOn: $store.registrationDetails.useHTTP)
                    .foregroundStyle(Color.Text.primary)
                    .tint(Color.Accent.dark)
            }

            Spacer()

            LoadingButton(title: "Next", isLoading: store.isLoading) {
                send(.nextButtonTapped)
            }
            .disabled(store.registrationDetails.serverAddress.isEmpty || store.isLoading)
        }
        .padding(.all, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Brand.primary)
        .navigationBarTitleDisplayMode(.inline)
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}
#endif
