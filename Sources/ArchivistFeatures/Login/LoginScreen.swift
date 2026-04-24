#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import Lottie
import SwiftUI

@ViewAction(for: LoginReducer.self)
public struct LoginScreen: View {
    @Bindable public var store: StoreOf<LoginReducer>

    public init(store: StoreOf<LoginReducer>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                LottieView(animation: LottieAnimationFile.credentials.animation)
                    .playing(loopMode: .playOnce)
                    .frame(width: 200, height: 200)

                Text(String.localised("login.apiKey.title", table: .login))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.Text.primary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 12) {
                    Text(String.localised("login.apiKey.disableStaticAuthNotice", table: .login))
                        .font(.footnote)
                        .foregroundStyle(Color.Text.primary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.Surface.highlight)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String.localised("login.apiKey", table: .login))
                            .font(.subheadline)
                            .foregroundStyle(Color.Text.primary)

                        SecureField(
                            String.localised("login.apiKey", table: .login),
                            text: $store.apiToken
                        )
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    }

                    Text(String.localised("login.apiKey.hint", table: .login))
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                }

                LoadingButton(
                    title: String.localised("login.login", table: .login),
                    isLoading: store.isLoading
                ) {
                    send(.loginButtonTapped)
                }
                .disabled(store.apiToken.isEmpty || store.isLoading)
            }
            .padding(.all, 32)
        }
        .background {
            Color.Brand.primary
                .ignoresSafeArea()
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

#Preview {
    LoginScreen(
        store: Store(initialState: LoginReducer.State(registrationDetails: Shared(value: RegistrationDetails()))) {
            LoginReducer()
        }
    )
}
#endif
