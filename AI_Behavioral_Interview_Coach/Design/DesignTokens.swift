import SwiftUI

enum CoachColor {
    static let canvas = Color(hex: 0xF5F5F7)
    static let surface = Color.white
    static let surfaceMuted = Color(hex: 0xFAFAFC)
    static let text = Color(hex: 0x1D1D1F)
    static let text80 = Color(hex: 0x4A4A4D)
    static let text48 = Color(hex: 0x7C7C80)
    static let line = Color(hex: 0xD2D2D7)
    static let blue = Color(hex: 0x0071E3)
    static let linkBlue = Color(hex: 0x0066CC)
    static let dark = Color.black
    static let darkPanel = Color(hex: 0x272729)
    static let darkPanelRaised = Color(hex: 0x2A2A2D)
    static let darkPanel2 = Color(hex: 0x2A2A2D)
    static let darkText = Color.white
    static let darkMuted = Color(hex: 0xB8B8BD)
    static let overlay = Color(hex: 0x000000, alpha: 0.4)
    static let transparent = Color(hex: 0xFFFFFF, alpha: 0)
    static let darkLinkBlue = Color(hex: 0x2997FF)
    static let recordingPanel = Color(hex: 0x303033)
    static let darkBorder = Color(hex: 0xFFFFFF, alpha: 0.13)
    static let darkBorderStrong = Color(hex: 0xFFFFFF, alpha: 0.26)
}

enum CoachSpace {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let screenHorizontal: CGFloat = 24
    static let screenX: CGFloat = 24
}

enum CoachRadius {
    static let small: CGFloat = 5
    static let standard: CGFloat = 8
    static let sheet: CGFloat = 24
}

enum CoachSize {
    static let primaryButtonHeight: CGFloat = 50
    static let secondaryButtonHeight: CGFloat = 46
    static let rowHeight: CGFloat = 66
    static let tagHeight: CGFloat = 32
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

extension Font {
    static var coachDisplay: Font { .system(size: 27, weight: .bold, design: .default) }
    static var coachTitle: Font { .system(size: 24, weight: .bold, design: .default) }
    static var coachSectionTitle: Font { .system(size: 13, weight: .semibold, design: .default) }
    static var coachCardTitle: Font { .system(size: 17, weight: .semibold, design: .default) }
    static var coachBody: Font { .system(size: 15, weight: .regular, design: .default) }
    static var coachBodySecondary: Font { .system(size: 14, weight: .regular, design: .default) }
    static var coachCaption: Font { .system(size: 12, weight: .regular, design: .default) }
    static var coachButton: Font { .system(size: 17, weight: .medium, design: .default) }
}
