#if !os(tvOS)
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: DiscoverSetupReducer.self)
public struct DiscoverSetupScreen: View {
    @Bindable public var store: StoreOf<DiscoverSetupReducer>
    @FocusState private var isKeyFocused: Bool

    public init(store: StoreOf<DiscoverSetupReducer>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    progressDots
                    stepContent
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .background(Color.Brand.primary)
            .navigationTitle(String.localised("discover.setup.navTitle", table: .discover))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(
                        String.localised("generic.close", table: .generic),
                        systemImage: "xmark"
                    ) {
                        send(.closeTapped)
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Color.Text.primary)
                }
            }
        }
        .interactiveDismissDisabled(store.isVerifying)
        .presentationDragIndicator(.visible)
    }

    // MARK: - Progress

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(DiscoverSetupReducer.State.Step.allCases, id: \.self) { step in
                Capsule()
                    .fill(step.rawValue <= store.step.rawValue ? Color.Accent.dark : Color.Surface.highlight)
                    .frame(height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String.localised(
                "discover.setup.progress \(store.stepNumber) \(store.stepCount)",
                table: .discover
            )
        )
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch store.step {
        case .intro:
            introStep
        case .project:
            projectStep
        case .enableAPI:
            enableAPIStep
        case .createKey:
            createKeyStep
        case .paste:
            pasteStep
        }
    }

    private var introStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                icon: "safari",
                title: String.localised("discover.setup.intro.title", table: .discover),
                message: String.localised("discover.setup.intro.body", table: .discover)
            )
            VStack(alignment: .leading, spacing: 14) {
                FactRow(
                    icon: "clock",
                    text: String.localised("discover.setup.intro.time", table: .discover)
                )
                FactRow(
                    icon: "gift",
                    text: String.localised("discover.setup.intro.free", table: .discover)
                )
                FactRow(
                    icon: "lock.shield",
                    text: String.localised("discover.setup.intro.private", table: .discover)
                )
                FactRow(
                    icon: "magnifyingglass",
                    text: String.localised("discover.setup.intro.limit", table: .discover)
                )
            }
        }
    }

    private var projectStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                icon: "folder.badge.plus",
                title: String.localised("discover.setup.project.title", table: .discover),
                message: nil
            )
            NumberedStep(
                number: 1,
                text: String.localised("discover.setup.project.step1", table: .discover)
            )
            NumberedStep(
                number: 2,
                text: String.localised("discover.setup.project.step2", table: .discover)
            )
            NumberedStep(
                number: 3,
                text: String.localised("discover.setup.project.step3", table: .discover)
            )
            linkButton(
                title: String.localised("discover.setup.project.open", table: .discover),
                link: .createProject
            )
        }
    }

    private var enableAPIStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                icon: "switch.2",
                title: String.localised("discover.setup.enable.title", table: .discover),
                message: nil
            )
            NumberedStep(
                number: 1,
                text: String.localised("discover.setup.enable.step1", table: .discover)
            )
            NumberedStep(
                number: 2,
                text: String.localised("discover.setup.enable.step2", table: .discover)
            )
            linkButton(
                title: String.localised("discover.setup.enable.open", table: .discover),
                link: .enableAPI
            )
        }
    }

    private var createKeyStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                icon: "key.fill",
                title: String.localised("discover.setup.key.title", table: .discover),
                message: nil
            )
            NumberedStep(
                number: 1,
                text: String.localised("discover.setup.key.step1", table: .discover)
            )
            NumberedStep(
                number: 2,
                text: String.localised("discover.setup.key.step2", table: .discover)
            )
            NumberedStep(
                number: 3,
                text: String.localised("discover.setup.key.step3", table: .discover)
            )
            Text(String.localised("discover.setup.key.tip", table: .discover))
                .font(.footnote)
                .foregroundStyle(Color.Brand.secondary)
            linkButton(
                title: String.localised("discover.setup.key.open", table: .discover),
                link: .credentials
            )
        }
    }

    private var pasteStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                icon: "doc.on.clipboard",
                title: String.localised("discover.setup.paste.title", table: .discover),
                message: String.localised("discover.setup.paste.body", table: .discover)
            )

            if store.wasKeyRejected {
                Label(
                    String.localised("discover.setup.paste.rejected", table: .discover),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.subheadline)
                .foregroundStyle(Color.Text.primary)
            }

            TextField(
                String.localised("discover.setup.paste.placeholder", table: .discover),
                text: $store.keyInput
            )
            .textFieldStyle(.roundedBorder)
            .font(.body.monospaced())
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($isKeyFocused)
            .submitLabel(.go)
            .onSubmit { send(.verifyTapped) }

            PasteButton(payloadType: String.self) { strings in
                guard let first = strings.first else { return }
                Task { @MainActor in
                    send(.pasted(first))
                }
            }
            .labelStyle(.titleAndIcon)
            .buttonBorderShape(.capsule)

            if let failure = store.failure {
                failureView(failure)
            }
        }
    }

    @ViewBuilder
    private func failureView(_ failure: DiscoverSetupReducer.State.Failure) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(failureMessage(failure), systemImage: "exclamationmark.circle")
                .font(.subheadline)
                .foregroundStyle(Color.Text.primary)
            if failure == .apiNotEnabled {
                linkButton(
                    title: String.localised("discover.setup.enable.open", table: .discover),
                    link: .enableAPI
                )
            }
        }
    }

    private func failureMessage(_ failure: DiscoverSetupReducer.State.Failure) -> String {
        switch failure {
        case .invalidKey:
            String.localised("discover.setup.failure.invalid", table: .discover)
        case .apiNotEnabled:
            String.localised("discover.setup.failure.apiNotEnabled", table: .discover)
        case .network:
            String.localised("discover.setup.failure.network", table: .discover)
        case .unexpected:
            String.localised("discover.setup.failure.unexpected", table: .discover)
        }
    }

    private func linkButton(
        title: String,
        link: DiscoverSetupReducer.Link
    ) -> some View {
        Button {
            send(.openLinkTapped(link))
        } label: {
            Label(title, systemImage: "arrow.up.right.square")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(Color.Accent.dark)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if !store.isFirstStep {
                Button {
                    send(.backTapped, animation: .default)
                } label: {
                    Text(String.localised("discover.setup.back", table: .discover))
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .frame(height: 48)
                }
                .buttonStyle(.bordered)
                .tint(Color.Accent.dark)
                .disabled(store.isVerifying)
            }

            if store.isLastStep {
                LoadingButton(
                    title: String.localised("discover.setup.verify", table: .discover),
                    isLoading: store.isVerifying
                ) {
                    isKeyFocused = false
                    send(.verifyTapped)
                }
                .frame(height: 48)
                .background(Color.Accent.dark)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(!store.canVerify)
                .opacity(store.canVerify || store.isVerifying ? 1 : 0.5)
            } else {
                Button {
                    send(.nextTapped, animation: .default)
                } label: {
                    Text(
                        store.isFirstStep
                            ? String.localised("discover.setup.start", table: .discover)
                            : String.localised("discover.setup.next", table: .discover)
                    )
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .background(Color.Accent.dark)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

// MARK: - Pieces

private struct StepHeader: View {
    let icon: String
    let title: String
    let message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .scaledSystemFont(size: 40, relativeTo: .largeTitle)
                .foregroundStyle(Color.Accent.dark)
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(Color.Text.primary)
                .accessibilityAddTraits(.isHeader)
            if let message {
                Text(message)
                    .font(.body)
                    .foregroundStyle(Color.Brand.secondary)
            }
        }
    }
}

private struct FactRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(Color.Accent.dark)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .foregroundStyle(Color.Text.primary)
        }
    }
}

private struct NumberedStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.Accent.dark, in: Circle())
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .foregroundStyle(Color.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
#endif
