#if os(watchOS)
import ArchivistNetworking
import Foundation

/// Page bookkeeping shared by the paginated lists. Each load is stamped with
/// a generation, so a page that lands after a refresh started is dropped
/// instead of being appended to the new list.
struct WatchPaging: Equatable {
    struct Request: Equatable {
        let generation: Int
        let page: Int
    }

    private(set) var currentPage = 1
    private(set) var lastPage = 1
    private(set) var hasLoaded = false
    private var generation = 0

    mutating func firstPageRequest() -> Request {
        generation += 1
        return Request(generation: generation, page: 1)
    }

    func nextPageRequest() -> Request? {
        guard hasLoaded, currentPage < lastPage else { return nil }
        return Request(generation: generation, page: currentPage + 1)
    }

    func isCurrent(_ request: Request) -> Bool {
        request.generation == generation
    }

    /// Records a page's metadata; false when the request has been superseded.
    mutating func accept<Item: Decodable & Sendable>(
        _ info: PaginatedResponse<Item>.PaginateInfo,
        for request: Request
    ) -> Bool {
        guard isCurrent(request) else { return false }
        currentPage = info.currentPage
        lastPage = info.lastPage
        hasLoaded = true
        return true
    }
}
#endif
