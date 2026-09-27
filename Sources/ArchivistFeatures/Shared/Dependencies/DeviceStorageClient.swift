#if !os(tvOS)
// Device downloads are iOS-only, and tvOS has no important-usage capacity key.
import ArchivistNetworking
import ComposableArchitecture
import Foundation

/// How much space offline downloads take, and how much is left.
public struct StorageUsage: Equatable, Sendable {
    public var downloadsSize: Int64
    public var available: Int64

    public init(
        downloadsSize: Int64,
        available: Int64
    ) {
        self.downloadsSize = downloadsSize
        self.available = available
    }
}

@DependencyClient
public struct DeviceStorageClient: Sendable {
    public var usage: @Sendable () async -> StorageUsage = {
        StorageUsage(downloadsSize: 0, available: 0)
    }
}

extension DeviceStorageClient: DependencyKey {
    public static var liveValue: DeviceStorageClient {
        DeviceStorageClient(usage: {
            let values = try? URL.homeDirectory
                .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return StorageUsage(
                downloadsSize: LocalVideoStorage.totalDownloadsSize(),
                available: values?.volumeAvailableCapacityForImportantUsage ?? 0
            )
        })
    }

    public static var testValue: DeviceStorageClient { DeviceStorageClient() }

    public static var previewValue: DeviceStorageClient {
        DeviceStorageClient(usage: {
            StorageUsage(downloadsSize: 2_400_000_000, available: 18_000_000_000)
        })
    }
}

extension DependencyValues {
    public var deviceStorage: DeviceStorageClient {
        get { self[DeviceStorageClient.self] }
        set { self[DeviceStorageClient.self] = newValue }
    }
}
#endif
