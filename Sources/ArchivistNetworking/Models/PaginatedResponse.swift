import Foundation

public nonisolated struct PaginatedResponse<T: Decodable & Sendable>: Decodable, Sendable {
    public let data: [T]
    public let paginate: PaginateInfo

    public init(
        data: [T],
        paginate: PaginateInfo
    ) {
        self.data = data
        self.paginate = paginate
    }

    public struct PaginateInfo: Decodable, Sendable {
        public let pageSize: Int
        public let pageFrom: Int
        public let currentPage: Int
        public let lastPage: Int
        public let totalHits: Int
        public let nextPages: [Int]
        public let prevPages: [Int]?
        public let maxHits: Bool
        public let params: String?

        public init(
            pageSize: Int,
            pageFrom: Int,
            currentPage: Int,
            lastPage: Int,
            totalHits: Int,
            nextPages: [Int],
            prevPages: [Int]?,
            maxHits: Bool,
            params: String?
        ) {
            self.pageSize = pageSize
            self.pageFrom = pageFrom
            self.currentPage = currentPage
            self.lastPage = lastPage
            self.totalHits = totalHits
            self.nextPages = nextPages
            self.prevPages = prevPages
            self.maxHits = maxHits
            self.params = params
        }

        enum CodingKeys: String, CodingKey {
            case pageSize = "page_size"
            case pageFrom = "page_from"
            case currentPage = "current_page"
            case lastPage = "last_page"
            case totalHits = "total_hits"
            case nextPages = "next_pages"
            case prevPages = "prev_pages"
            case maxHits = "max_hits"
            case params
        }
    }
}
