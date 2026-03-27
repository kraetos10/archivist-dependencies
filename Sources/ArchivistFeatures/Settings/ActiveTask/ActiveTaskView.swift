import ArchivistNetworking
import ComposableArchitecture
import SwiftUI
import ArchivistComponents

@ViewAction(for: ActiveTaskReducer.self)
public struct ActiveTaskView: View {
    public let store: StoreOf<ActiveTaskReducer>

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
                        Text(active.currentStep.isEmpty ? String.localised("video.downloading", table: .videos) : active.currentStep)
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

                    if active.messages.count > 1 {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(active.messages.dropLast(), id: \.self) { message in
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Color.Accent.dark)
                                    Text(message)
                                        .font(.caption)
                                        .foregroundStyle(Color.Brand.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)

                Button {
                    send(.cancelTaskTapped)
                } label: {
                    if store.isCancelling {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else {
                        Text(String.localised("settings.cancelTask", table: .settings))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(store.isCancelling)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } header: {
                Text(String.localised("settings.activeTasks", table: .settings))
            }
        }
    }
}
