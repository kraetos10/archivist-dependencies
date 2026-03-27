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
        VStack(spacing: 32) {
            LottieView(animation: LottieAnimationFile.credentials.animation)
                .playing(loopMode: .playOnce)
                .frame(width: 200, height: 200)

            Text("Sign In")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color.Text.primary)

            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Username")
                        .font(.subheadline)
                        .foregroundStyle(Color.Text.primary)

                    TextField("Username", text: $store.username)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Password")
                        .font(.subheadline)
                        .foregroundStyle(Color.Text.primary)

                    SecureField("Password", text: $store.password)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Spacer()

            LoadingButton(title: "Login", isLoading: store.isLoading) {
                send(.loginButtonTapped)
            }
            .disabled(store.username.isEmpty || store.password.isEmpty || store.isLoading)
        }
        .padding(.all, 32)
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
