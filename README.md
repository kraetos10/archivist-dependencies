# Archivist Dependencies

Swift packages powering the [Archivist](https://github.com/kraetos10/archivist) iOS and tvOS client for [TubeArchivist](https://www.tubearchivist.com) — a self-hosted YouTube media server.

## Packages

### ArchivistNetworking

Networking layer for communicating with a TubeArchivist server instance.

- **Core** — `ServerConfig`, `APIRequest`, HTTP methods, API path definitions, error handling
- **Models** — Response and request DTOs for videos, channels, playlists, downloads, stats, tasks, search, and user/auth
- **Services** — Protocol-based service layer with async/await implementations for each API domain (`VideoService`, `ChannelService`, `PlaylistService`, `DownloadService`, `SearchService`, `StatsService`, `TaskService`, `UserService`, `PingService`, `HealthService`)
- **Dependencies** — [TCA dependency](https://github.com/pointfreeco/swift-dependencies) registrations for all services, plus `KeychainService` for secure token storage

### ArchivistComponents

Shared SwiftUI components and design tokens used across the app.

- **Design Tokens** — Semantic color system (`Color.Brand.primary`, `Color.Text.primary`, `Color.Surface.highlight`, etc.) backed by an asset catalog with light/dark mode support
- **Card Views** — `VideoCardView`, `ChannelCardView`, `PlaylistCardView` with tvOS variants (`TVVideoCardView`, `TVChannelCardView`, `TVPlaylistCardView`)
- **Player** — `PlayerManager` (singleton AVPlayer controller), `AVPlayerViewControllerWrapper` (iOS), `TVPlayerView` (tvOS)
- **UI Primitives** — `EmptyStateView`, `WatchProgressBar`, `WatchFilterRow`, `PinnedSectionHeader`, `LoadingButton`, `FloatingAddButton`, `HapticFeedback`, `VideoContextMenu`
- **Resources** — Lottie animation files for onboarding flows

### ArchivistFeatures

Feature modules built with [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) (TCA).

Each feature follows a consistent structure:

```
FeatureName/
  FeatureReducer.swift          # State, Action, body
  FeatureScreen.swift           # Shared SwiftUI view
  Extensions/
    FeatureReducer+ViewActions.swift     # User-initiated action handlers
    FeatureReducer+InternalActions.swift # Response/effect handlers
  Platform/
    iPhoneFeatureScreen.swift   # iPhone layout
    iPadFeatureScreen.swift     # iPad layout
    TVFeatureScreen.swift       # tvOS layout
```

**Features:**

| Feature | Description |
|---------|-------------|
| **VideoList** | Paginated video grid with watch/download filters and search |
| **VideoDetail** | Video playback, metadata, comments, similar videos, play next queue |
| **Channels** | Channel list with subscribe/unsubscribe, channel detail with videos |
| **Playlists** | Playlist management, custom playlists, video picker |
| **Settings** | Server downloads queue, stats, watch history, device downloads |
| **Login** | Authentication with username/password and token management |
| **ServerSetup** | Server discovery, health check, and initial connection setup |
| **Tab** | Root tab coordinator managing all feature navigation |

**Database** — SQLite persistence via [SQLiteData](https://github.com/pointfreeco/sqlite-data) with `@Table` schema definitions for device downloads, play-next queue, and server connection state.

## Architecture

- **TCA** for state management, navigation, and dependency injection
- **NavigationStack** with path-based routing via `@Reducer enum` path types
- **Platform-specific views** using `#if os(tvOS)` / `#else` compiler directives
- **Protocol-based services** with TCA `DependencyKey` registrations for testability

## Requirements

- iOS 18.0+ / tvOS 18.0+
- Swift 6.0+
- Xcode 16.0+

## Dependencies

- [swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture)
- [swift-dependencies](https://github.com/pointfreeco/swift-dependencies)
- [swift-identified-collections](https://github.com/pointfreeco/swift-identified-collections)
- [sqlite-data](https://github.com/pointfreeco/sqlite-data)
- [lottie-ios](https://github.com/airbnb/lottie-ios)

## Usage

Add the package as a dependency in your Xcode project or `Package.swift`:

```swift
.package(url: "https://github.com/kraetos10/archivist-dependencies", from: "1.0.0")
```

Then import the modules you need:

```swift
import ArchivistNetworking  // Models, services, API
import ArchivistComponents  // UI components, design tokens
import ArchivistFeatures    // TCA feature reducers and screens
```

## License

MIT
