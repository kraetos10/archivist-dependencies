import SwiftUI

extension Color {
    public enum Brand {
        public static let primary = Color("brandPrimary", bundle: .module)
        public static let secondary = Color("brandSecondary", bundle: .module)
    }

    public enum Text {
        public static let primary = Color("fontPrimary", bundle: .module)
    }

    public enum Surface {
        public static let highlight = Color("highlightBG", bundle: .module)
    }

    public enum Accent {
        public static let dark = Color("accentDark", bundle: .module)
    }

    public enum Progress {
        public static let tint = Color("progressTint", bundle: .module)
    }
}
