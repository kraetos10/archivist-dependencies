#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

/// A YouTube video with its add-to-queue control. Used by the search feed
/// and by a channel's page.
struct DiscoverVideoCard: View {
    let video: YouTubeVideo
    let status: DiscoverReducer.State.ItemStatus?
    let isPending: Bool
    /// False on a channel's own page, where the channel link is redundant.
    let showsChannel: Bool
    let onAdd: (_ startNow: Bool) -> Void
    let onChannelTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnail
            Text(video.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            metadata
            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var thumbnail: some View {
        Color.Surface.highlight
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                AsyncImage(url: video.thumbnailURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let duration = video.durationText {
                    Text(duration)
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var metadata: some View {
        VStack(alignment: .leading, spacing: 2) {
            if showsChannel {
                Button(action: onChannelTapped) {
                    Text(video.channelTitle)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.Brand.secondary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
            if !video.detailText.isEmpty {
                Text(video.detailText)
                    .font(.caption)
                    .foregroundStyle(Color.Brand.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch status {
        case .inArchive:
            statusLabel(
                String.localised("discover.inArchive", table: .discover),
                systemImage: "checkmark.circle.fill"
            )
        case .queued:
            statusLabel(
                String.localised("discover.queued", table: .discover),
                systemImage: "clock.badge.checkmark"
            )
        case nil:
            HStack(spacing: 8) {
                Button {
                    onAdd(false)
                } label: {
                    Group {
                        if isPending {
                            ProgressView()
                        } else {
                            Label(
                                String.localised("discover.addToQueue", table: .discover),
                                systemImage: "plus"
                            )
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.Accent.dark)
                .disabled(isPending)

                Menu {
                    Button(
                        String.localised("discover.addAndDownload", table: .discover),
                        systemImage: "arrow.down.circle"
                    ) {
                        onAdd(true)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                }
                .tint(Color.Accent.dark)
                .disabled(isPending)
                .accessibilityLabel(String.localised("discover.addAndDownload", table: .discover))
            }
        }
    }

    private func statusLabel(
        _ title: String,
        systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.Brand.secondary)
            .padding(.vertical, 6)
    }
}
#endif
