import SwiftUI

public enum ChildMode {
    public static let enabledKey = "childModeEnabled"
    public static let pinKey = "childModePin"
    public static let pinLength = 4
}

#if !os(tvOS) && !os(watchOS)
public struct PinSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case first, second }

    public let onConfirmed: (String) -> Void
    public let onCancelled: () -> Void

    public init(
        onConfirmed: @escaping (String) -> Void,
        onCancelled: @escaping () -> Void
    ) {
        self.onConfirmed = onConfirmed
        self.onCancelled = onCancelled
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(String.localised("childMode.pinSetup.subtitle", table: .login))
                    .font(.subheadline)
                    .foregroundStyle(Color.Brand.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text(String.localised("childMode.pinSetup.newPin", table: .login))
                        .font(.subheadline)
                        .foregroundStyle(Color.Text.primary)
                    SecureField("", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($focusedField, equals: .first)
                        .padding(12)
                        .background(Color.Surface.highlight)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onChange(of: pin) { _, newValue in
                            pin = String(newValue.prefix(ChildMode.pinLength).filter { $0.isNumber })
                        }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(String.localised("childMode.pinSetup.confirmPin", table: .login))
                        .font(.subheadline)
                        .foregroundStyle(Color.Text.primary)
                    SecureField("", text: $confirmPin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($focusedField, equals: .second)
                        .padding(12)
                        .background(Color.Surface.highlight)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onChange(of: confirmPin) { _, newValue in
                            confirmPin = String(newValue.prefix(ChildMode.pinLength).filter { $0.isNumber })
                        }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button(action: confirm) {
                    Text(String.localised("generic.save", table: .generic))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.Accent.dark)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(pin.count != ChildMode.pinLength || confirmPin.count != ChildMode.pinLength)

                Spacer()
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            .background(Color.Brand.primary)
            .navigationTitle(String.localised("childMode.pinSetup.title", table: .login))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String.localised("generic.cancel", table: .generic)) {
                        onCancelled()
                        dismiss()
                    }
                }
            }
            .onAppear { focusedField = .first }
        }
    }

    private func confirm() {
        guard pin.count == ChildMode.pinLength else { return }
        guard pin == confirmPin else {
            errorMessage = String.localised("childMode.pinSetup.mismatch", table: .login)
            return
        }
        onConfirmed(pin)
        dismiss()
    }
}

public struct PinEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pin: String = ""
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    public let expectedPin: String
    public let title: String
    public let subtitle: String
    public let onSuccess: () -> Void
    public let onCancel: () -> Void

    public init(
        expectedPin: String,
        title: String = String.localised("childMode.pinEntry.title", table: .login),
        subtitle: String = String.localised("childMode.pinEntry.subtitle", table: .login),
        onSuccess: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.expectedPin = expectedPin
        self.title = title
        self.subtitle = subtitle
        self.onSuccess = onSuccess
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.Accent.dark)
                    .padding(.top, 32)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.Brand.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                SecureField("", text: $pin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focused)
                    .multilineTextAlignment(.center)
                    .font(.title2)
                    .padding(12)
                    .background(Color.Surface.highlight)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 32)
                    .onChange(of: pin) { _, newValue in
                        pin = String(newValue.prefix(ChildMode.pinLength).filter { $0.isNumber })
                        if pin.count == ChildMode.pinLength {
                            verify()
                        }
                    }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .background(Color.Brand.primary)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String.localised("generic.cancel", table: .generic)) {
                        onCancel()
                        dismiss()
                    }
                }
            }
            .onAppear { focused = true }
        }
    }

    private func verify() {
        if pin == expectedPin {
            onSuccess()
            dismiss()
        } else {
            errorMessage = String.localised("childMode.pinEntry.invalid", table: .login)
            pin = ""
        }
    }
}
#endif
