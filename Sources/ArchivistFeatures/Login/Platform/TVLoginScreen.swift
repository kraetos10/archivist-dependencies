#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Lottie
import SwiftUI

@ViewAction(for: LoginReducer.self)
public struct TVLoginScreen: View {
    @Bindable public var store: StoreOf<LoginReducer>

    public init(store: StoreOf<LoginReducer>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 48) {
            LottieView(animation: LottieAnimationFile.credentials.animation)
                .playing(loopMode: .playOnce)
                .frame(width: 250, height: 250)

            Text("Sign In")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 24) {
                TextField(String.localised("login.username", table: .login), text: $store.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField(String.localised("login.password", table: .login), text: $store.password)
            }
            .frame(maxWidth: 500)

            if store.isLoading {
                ProgressView()
            } else {
                Button(String.localised("login.login", table: .login)) {
                    send(.loginButtonTapped)
                }
                .disabled(store.username.isEmpty || store.password.isEmpty)
            }
        }
        .padding(64)
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}
#endif
