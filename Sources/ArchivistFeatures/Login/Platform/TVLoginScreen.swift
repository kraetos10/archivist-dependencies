#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Lottie
import SwiftUI

@ViewAction(for: LoginReducer.self)
public struct TVLoginScreen: View {
    @Bindable public var store: StoreOf<LoginReducer>

    /// Submitting from the keyboard parks focus on the Login button, so
    /// any alert that follows hands focus back there rather than to the
    /// field.
    @FocusState private var isLoginButtonFocused: Bool

    public init(store: StoreOf<LoginReducer>) {
        self.store = store
    }

    public var body: some View {
        // Scrolls when the content outgrows the ~960pt safe height (large
        // Dynamic Type, a long localised notice); centred otherwise.
        GeometryReader { geometry in
            ScrollView {
                content
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var content: some View {
        VStack(spacing: 32) {
            LottieView(animation: LottieAnimationFile.credentials.animation)
                .playing(loopMode: .playOnce)
                .frame(width: 160, height: 160)
                .accessibilityHidden(true)

            Text(String.localised("login.apiKey.title", table: .login))
                .font(.title)
                .fontWeight(.bold)

            StaticAuthNoticeView(variable: store.staticAuthVariable)
                .frame(maxWidth: 720)

            TextField(
                String.localised("login.apiKey", table: .login),
                text: $store.apiToken
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .onSubmit {
                isLoginButtonFocused = true
                send(.loginButtonTapped)
            }
            .frame(maxWidth: 500)

            // The button stays in place while logging in, with the spinner
            // inside it: swapping it for a ProgressView (or disabling it)
            // took away the focused view, so focus jumped back to the field
            // and didn't return after an error. The reducer ignores presses
            // while a login is in flight.
            Button {
                send(.loginButtonTapped)
            } label: {
                HStack(spacing: 16) {
                    if store.isLoading {
                        ProgressView()
                    }
                    Text(String.localised("login.login", table: .login))
                }
            }
            .disabled(store.apiToken.isEmpty)
            .focused($isLoginButtonFocused)
        }
        .padding(.vertical, 40)
    }
}
#endif
