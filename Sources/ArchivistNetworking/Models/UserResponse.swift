import Foundation

public nonisolated struct UserAccountResponse: Decodable, Sendable, Equatable {
    public let id: Int?
    public let name: String?
    public let isSuperuser: Bool?
    public let isStaff: Bool?
    public let groups: [String]?
    public let userPermissions: [String]?
    public let lastLogin: String?

    public init(
        id: Int?, name: String?, isSuperuser: Bool?, isStaff: Bool?,
        groups: [String]?, userPermissions: [String]?, lastLogin: String?
    ) {
        self.id = id
        self.name = name
        self.isSuperuser = isSuperuser
        self.isStaff = isStaff
        self.groups = groups
        self.userPermissions = userPermissions
        self.lastLogin = lastLogin
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isSuperuser = "is_superuser"
        case isStaff = "is_staff"
        case groups
        case userPermissions = "user_permissions"
        case lastLogin = "last_login"
    }
}

public nonisolated struct LoginResponse: Decodable, Sendable, Equatable {
    public init() {}
}

public nonisolated struct TokenResponse: Decodable, Sendable, Equatable {
    public let token: String?

    public init(token: String?) {
        self.token = token
    }
}

public nonisolated struct UserConfigResponse: Decodable, Sendable, Equatable {
    public let colors: String?
    public let pageSize: Int?
    public let stylesheet: String?
    public let showIgnoredOnly: Bool?
    public let showSubbedOnly: Bool?
    public let gridItems: Int?
    public let hideWatched: Bool?
    public let showHelpText: Bool?
    public let sortBy: String?
    public let sortOrder: String?
    public let viewStyle: String?

    public init(
        colors: String?, pageSize: Int?, stylesheet: String?,
        showIgnoredOnly: Bool?, showSubbedOnly: Bool?, gridItems: Int?,
        hideWatched: Bool?, showHelpText: Bool?, sortBy: String?,
        sortOrder: String?, viewStyle: String?
    ) {
        self.colors = colors
        self.pageSize = pageSize
        self.stylesheet = stylesheet
        self.showIgnoredOnly = showIgnoredOnly
        self.showSubbedOnly = showSubbedOnly
        self.gridItems = gridItems
        self.hideWatched = hideWatched
        self.showHelpText = showHelpText
        self.sortBy = sortBy
        self.sortOrder = sortOrder
        self.viewStyle = viewStyle
    }

    enum CodingKeys: String, CodingKey {
        case colors
        case pageSize = "page_size"
        case stylesheet
        case showIgnoredOnly = "show_ignored_only"
        case showSubbedOnly = "show_subb_only"
        case gridItems = "grid_items"
        case hideWatched = "hide_watched"
        case showHelpText = "show_help_text"
        case sortBy = "sort_by"
        case sortOrder = "sort_order"
        case viewStyle = "view_style"
    }
}
