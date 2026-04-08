#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Lottie
import SwiftUI

@ViewAction(for: ServerSetupReducer.self)
public struct TVServerSetupScreen: View {
    @Bindable public var store: StoreOf<ServerSetupReducer>

    public init(store: StoreOf<ServerSetupReducer>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            TVServerSetupContentView(store: store)
        } destination: { store in
            switch store.case {
            case .login(let loginStore):
                TVLoginScreen(store: loginStore)
            }
        }
    }
}

@ViewAction(for: ServerSetupReducer.self)
private struct TVServerSetupContentView: View {
    @Bindable var store: StoreOf<ServerSetupReducer>

    public var body: some View {
        VStack(spacing: 48) {
            LottieView(animation: LottieAnimationFile.server.animation)
                .playing(loopMode: .playOnce)
                .frame(width: 250, height: 250)

            VStack(spacing: 16) {
                Text(String.localised("login.title", table: .login))
                    .font(.title)
                    .fontWeight(.bold)

                Text(String.localised("login.subtitle", table: .login))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 24) {
                TextField(
                    String.localised("login.serverUrl", table: .login),
                    text: $store.registrationDetails.serverAddress
                )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField(String.localised("login.port", table: .login), text: $store.registrationDetails.port)

                Toggle(String.localised("login.useHttp", table: .login), isOn: $store.registrationDetails.useHTTP)
            }
            .frame(maxWidth: 500)

            if store.isLoading {
                ProgressView()
            } else {
                Button(String.localised("generic.next", table: .generic)) {
                    send(.nextButtonTapped)
                }
                .disabled(store.registrationDetails.serverAddress.isEmpty)
            }
        }
        .padding(64)
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}
#endif
