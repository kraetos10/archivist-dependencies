import SwiftUI

extension Color {
    public enum Brand {
        public static var primary: Color { AppTheme.current.color(\.brandPrimary) }
        public static var secondary: Color { AppTheme.current.color(\.brandSecondary) }
    }

    public enum Text {
        // Body text stays neutral across themes — keep it asset-backed.
        public static let primary = Color("fontPrimary", bundle: .module)
    }

    public enum Surface {
        public static var highlight: Color { AppTheme.current.color(\.highlightBG) }
    }

    public enum Accent {
        public static var dark: Color { AppTheme.current.color(\.accentDark) }
    }

    public enum Progress {
        public static var tint: Color { AppTheme.current.color(\.progressTint) }
    }
}
