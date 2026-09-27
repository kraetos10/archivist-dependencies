import ArchivistNetworking
import ComposableArchitecture
import SwiftUI
import ArchivistComponents

@ViewAction(for: ActiveTaskReducer.self)
public struct ActiveTaskView: View {
    @Bindable public var store: StoreOf<ActiveTaskReducer>

    public init(store: StoreOf<ActiveTaskReducer>) {
        self.store = store
    }

    public var body: some View {
        if let active = store.activeDownload {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(Color.Accent.dark)
                        Text(store.stepDescription)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.Accent.dark)
                    }

                    if let videoTitle = active.videoTitle {
                        Text(videoTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.Text.primary)
                            .lineLimit(2)
                    }

                    if !store.completedMessages.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(store.completedMessages.enumerated()), id: \.offset) { _, message in
                                Label {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundStyle(Color.Brand.secondary)
                                } icon: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.Accent.dark)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text(String.localised("settings.activeTasks", table: .settings))
            } footer: {
                Button(role: .destructive) {
                    send(.cancelTaskTapped)
                } label: {
                    if store.isCancelling {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(String.localised("settings.cancelTask", table: .settings))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isCancelling)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
