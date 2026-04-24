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
        VStack(spacing: 40) {
            LottieView(animation: LottieAnimationFile.credentials.animation)
                .playing(loopMode: .playOnce)
                .frame(width: 220, height: 220)

            Text(String.localised("login.apiKey.title", table: .login))
                .font(.title)
                .fontWeight(.bold)

            Text(String.localised("login.apiKey.disableStaticAuthNotice", table: .login))
                .font(.footnote)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 720)

            TextField(
                String.localised("login.apiKey", table: .login),
                text: $store.apiToken
            )
            .frame(maxWidth: 500)

            if store.isLoading {
                ProgressView()
            } else {
                Button(String.localised("login.login", table: .login)) {
                    send(.loginButtonTapped)
                }
                .disabled(store.apiToken.isEmpty)
            }
        }
        .padding(64)
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}
#endif
