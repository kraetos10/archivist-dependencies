import Foundation

public extension String {
    static func localised(
        _ key: String.LocalizationValue,
        table: LocalisationTable = .default
    ) -> String {
        String(localized: key, table: table.rawValue, bundle: .module)
    }
}

public enum LocalisationTable: String {
    case `default` = "Localizable"
    case settings = "Settings"
    case videos = "Videos"
    case login = "Login"
}
