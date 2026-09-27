import Foundation

/// Holds a mocked request open until the test releases it, so two merged
/// effects deliver in a fixed order instead of racing.
struct TestGate: Sendable {
    let stream: AsyncStream<Void>
    let continuation: AsyncStream<Void>.Continuation

    init() {
        (stream, continuation) = AsyncStream.makeStream(of: Void.self)
    }

    func wait() async {
        for await _ in stream { break }
    }

    func open() {
        continuation.yield()
        continuation.finish()
    }
}
