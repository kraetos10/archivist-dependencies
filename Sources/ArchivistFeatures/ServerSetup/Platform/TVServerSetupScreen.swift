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

    /// Keyboard submit walks the form: URL → port → Next.
    private enum Field: Hashable {
        case serverURL
        case port
        case next
    }

    @FocusState private var focusedField: Field?

    public var body: some View {
        // Scrolls when the content outgrows the ~960pt safe height (large
        // Dynamic Type); centred otherwise.
        GeometryReader { geometry in
            ScrollView {
                content
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var content: some View {
        VStack(spacing: 40) {
            LottieView(animation: LottieAnimationFile.server.animation)
                .playing(loopMode: .playOnce)
                .frame(width: 160, height: 160)
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                Text(String.localised("login.title", table: .login))
                    .font(.title)
                    .bold()

                Text(String.localised("login.subtitle", table: .login))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 24) {
                TextField(
                    String.localised("login.serverUrl", table: .login),
                    text: $store.registrationDetails.serverAddress
                )
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focusedField, equals: .serverURL)
                .onSubmit { focusedField = .port }

                TextField(
                    String.localised("login.port", table: .login),
                    text: $store.registrationDetails.port
                )
                .keyboardType(.numberPad)
                .submitLabel(.next)
                .focused($focusedField, equals: .port)
                .onSubmit { focusedField = .next }

                Toggle(
                    String.localised("login.useHttp", table: .login),
                    isOn: $store.registrationDetails.useHTTP
                )
            }
            .frame(maxWidth: 500)

            // The button stays in place during the health check, with the
            // spinner inside it: swapping it for a ProgressView took away
            // the focused view, so focus jumped away and didn't come back
            // after an error. The reducer ignores presses while loading.
            Button {
                send(.nextButtonTapped)
            } label: {
                HStack(spacing: 16) {
                    if store.isLoading {
                        ProgressView()
                    }
                    Text(String.localised("generic.next", table: .generic))
                }
            }
            .disabled(store.registrationDetails.serverAddress.isEmpty)
            .focused($focusedField, equals: .next)
        }
        .padding(.vertical, 40)
    }
}
#endif
