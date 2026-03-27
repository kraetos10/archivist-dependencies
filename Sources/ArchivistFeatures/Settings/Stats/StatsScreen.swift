import ArchivistNetworking
import ComposableArchitecture
import SwiftUI
import ArchivistComponents

@ViewAction(for: StatsReducer.self)
public struct StatsScreen: View {
    public let store: StoreOf<StatsReducer>

    public init(store: StoreOf<StatsReducer>) {
        self.store = store
    }

    public var body: some View {
        List {
            if let video = store.videoStats {
                overviewSection(video)
                videoTypeSection(video)
            } else if !store.loadedSections.contains(.video) {
                placeholderOverviewSection
            }

            if store.channelStats != nil || store.playlistStats != nil || store.downloadStats != nil {
                applicationSection
            } else if !store.loadedSections.contains(.channel) {
                placeholderApplicationSection
            }

            if let watch = store.watchStats {
                watchSection(watch)
            }

            if !store.biggestChannels.isEmpty {
                biggestChannelsSection
            }
        }
        #if os(tvOS)
        .listStyle(.grouped)
        #else
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        #endif
        .background(Color.Brand.primary.ignoresSafeArea())
        #if os(tvOS)
        .navigationTitle("")
        #else
        .navigationTitle(String.localised("settings.stats", table: .settings))
        #endif
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { send(.viewDidAppear) }
    }

    // MARK: - Overview

    private func overviewSection(_ video: VideoStatsResponse) -> some View {
        Section {
            statRow(label: String.localised("video.totalVideos", table: .videos), value: "\(video.docCount ?? 0)", icon: "film.stack")
            statRow(label: "Media Size", value: formatBytes(video.totalSize), icon: "internaldrive")
            statRow(label: "Duration", value: formatDuration(video.totalDuration), icon: "clock")
            statRow(label: String.localised("generic.active"), value: "\(video.activeTrue ?? 0)", icon: "checkmark.circle")
            statRow(label: String.localised("generic.inactive"), value: "\(video.activeFalse ?? 0)", icon: "xmark.circle")
        } header: {
            Text(String.localised("generic.overview"))
        }
        .listRowBackground(Color.Surface.highlight)
    }

    // MARK: - Video Type

    private func videoTypeSection(_ video: VideoStatsResponse) -> some View {
        Section {
            statRow(label: String.localised("video.typeRegular", table: .videos), value: "\(video.typeVideos ?? 0)", icon: "play.rectangle")
            statRow(label: String.localised("video.typeShorts", table: .videos), value: "\(video.typeShorts ?? 0)", icon: "bolt.circle")
            statRow(label: String.localised("video.typeStreams", table: .videos), value: "\(video.typeStreams ?? 0)", icon: "dot.radiowaves.left.and.right")
        } header: {
            Text(String.localised("video.videoType", table: .videos))
        }
        .listRowBackground(Color.Surface.highlight)
    }

    // MARK: - Application

    private var applicationSection: some View {
        Section {
            if let channel = store.channelStats {
                statRow(label: String.localised("generic.channels"), value: "\(channel.docCount ?? 0)", icon: "person.2")
                statRow(label: "Subscribed Channels", value: "\(channel.subscribedTrue ?? 0)", icon: "bell")
            }
            if let playlist = store.playlistStats {
                statRow(label: String.localised("generic.playlists"), value: "\(playlist.docCount ?? 0)", icon: "list.bullet.rectangle")
                statRow(label: "Subscribed Playlists", value: "\(playlist.subscribedTrue ?? 0)", icon: "bell")
            }
            if let download = store.downloadStats {
                statRow(label: String.localised("video.downloadsPending", table: .videos), value: "\(download.pending ?? 0)", icon: "arrow.down.circle")
            }
        } header: {
            Text(String.localised("settings.application", table: .settings))
        }
        .listRowBackground(Color.Surface.highlight)
    }

    // MARK: - Watch Progress

    private func watchSection(_ watch: WatchStatsResponse) -> some View {
        Section {
            statRow(label: String.localised("video.watched", table: .videos), value: "\(watch.watched ?? 0)", icon: "eye")
            statRow(label: String.localised("video.unwatched", table: .videos), value: "\(watch.unwatched ?? 0)", icon: "eye.slash")
        } header: {
            Text(String.localised("video.watchProgress", table: .videos))
        }
        .listRowBackground(Color.Surface.highlight)
    }

    // MARK: - Biggest Channels

    private var biggestChannelsSection: some View {
        Section {
            ForEach(store.biggestChannels) { channel in
                HStack {
                    Image(systemName: "person.circle")
                        .font(.body)
                        .foregroundStyle(Color.Accent.dark)
                        .frame(width: 28)
                    Text(channel.name ?? "")
                        .font(.subheadline)
                        .foregroundStyle(Color.Text.primary)
                    Spacer()
                    Text("\(channel.docCount ?? 0) videos")
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                }
            }
        } header: {
            Text(String.localised("settings.biggestChannels", table: .settings))
        }
        .listRowBackground(Color.Surface.highlight)
    }

    // MARK: - Placeholders

    private var placeholderOverviewSection: some View {
        Section {
            statRow(label: "Total Videos", value: "0000", icon: "film.stack")
            statRow(label: "Media Size", value: "00.0 GB", icon: "internaldrive")
            statRow(label: "Duration", value: "000h 00m", icon: "clock")
            statRow(label: String.localised("generic.active"), value: "000", icon: "checkmark.circle")
            statRow(label: String.localised("generic.inactive"), value: "000", icon: "xmark.circle")
        } header: {
            Text(String.localised("generic.overview"))
        }
        .listRowBackground(Color.Surface.highlight)
        .redacted(reason: .placeholder)
    }

    private var placeholderApplicationSection: some View {
        Section {
            statRow(label: String.localised("generic.channels"), value: "000", icon: "person.2")
            statRow(label: "Subscribed", value: "000", icon: "bell")
            statRow(label: String.localised("generic.playlists"), value: "000", icon: "list.bullet.rectangle")
            statRow(label: String.localised("video.downloadsPending", table: .videos), value: "000", icon: "arrow.down.circle")
        } header: {
            Text(String.localised("settings.application", table: .settings))
        }
        .listRowBackground(Color.Surface.highlight)
        .redacted(reason: .placeholder)
    }

    // MARK: - Helpers

    private func statRow(label: String, value: String, icon: String) -> some View {
        #if os(tvOS)
        Button {} label: {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(Color.Accent.dark)
                    .frame(width: 28)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Color.Text.primary)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Text.primary)
            }
        }
        .buttonStyle(.plain)
        #else
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.Accent.dark)
                .frame(width: 28)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.Text.primary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.Text.primary)
        }
        #endif
    }

    private func formatBytes(_ bytes: Int?) -> String {
        guard let bytes else { return "0 B" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func formatDuration(_ seconds: Int?) -> String {
        guard let seconds, seconds > 0 else { return "NA" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m \(secs)s"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        }
        return "\(secs)s"
    }
}
