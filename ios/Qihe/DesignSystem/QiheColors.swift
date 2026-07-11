import SwiftUI

enum QiheColor {
    static let brandBlue = Color(hex: 0x1F6EF5)
    static let brandDeep = Color(hex: 0x0D47C8)
    static let brandNavy = Color(hex: 0x0A1B52)
    static let brandLight = Color(hex: 0x5BA3FF)
    static let brandFrost = Color(hex: 0xC2D9FF)

    static let neutral0 = Color(hex: 0xFFFFFF)
    static let neutral50 = Color(hex: 0xF5F7FF)
    static let neutral100 = Color(hex: 0xEAF0FF)
    static let neutral300 = Color(hex: 0xB0C4E8)
    static let neutral600 = Color(hex: 0x4A5A80)
    static let neutral900 = Color(hex: 0x0A1B52)

    static let riskRed = Color(hex: 0xF24747)
    static let riskOrange = Color(hex: 0xFF8C3A)
    static let safeGreen = Color(hex: 0x1DCB8A)
    static let infoBlue = brandBlue

    static let riskRedSoft = Color(hex: 0xF24747, alpha: 0.10)
    static let riskOrangeSoft = Color(hex: 0xFF8C3A, alpha: 0.12)
    static let safeGreenSoft = Color(hex: 0x1DCB8A, alpha: 0.10)
    static let infoBlueSoft = Color(hex: 0x1F6EF5, alpha: 0.10)

    static let glassFill = Color(hex: 0xFFFFFF, alpha: 0.86)
    static let glassStroke = Color(hex: 0xB0C4E8, alpha: 0.50)
    static let shadowBlue = Color(hex: 0x1F6EF5, alpha: 0.30)
    static let shadowNavy = Color(hex: 0x0A1B52, alpha: 0.10)
    static let shadowNavySoft = Color(hex: 0x0A1B52, alpha: 0.06)

    static let primaryGradient = LinearGradient(
        colors: [brandLight, brandBlue, brandDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let markLightGradient = LinearGradient(
        colors: [brandFrost, brandLight, brandBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pageBackgroundGradient = LinearGradient(
        colors: [neutral50, neutral100.opacity(0.72), neutral0],
        startPoint: .top,
        endPoint: .bottom
    )

    static let ink = neutral900
    static let inkSoft = neutral600
    static let muted = neutral600.opacity(0.82)
    static let paper = neutral50
    static let paperDeep = neutral100
    static let card = neutral0
    static let line = neutral100
    static let lineStrong = neutral300
    static let navy = brandBlue
    static let navyDeep = brandNavy
    static let navyMid = brandDeep
    static let navySoft = infoBlueSoft
    static let seal = riskRed
    static let sealDeep = Color(hex: 0xD73C3C)
    static let sealSoft = riskRedSoft
    static let amber = riskOrange
    static let amberSoft = riskOrangeSoft
    static let pine = safeGreen
    static let pineSoft = safeGreenSoft
}

enum QiheRadius {
    static let badge: CGFloat = 8
    static let input: CGFloat = 12
    static let card: CGFloat = 16
    static let cta: CGFloat = 24
    static let feature: CGFloat = 32

    static let lg: CGFloat = cta
    static let md: CGFloat = card
    static let sm: CGFloat = input
    static let xs: CGFloat = badge
}

enum QiheLayout {
    static let rootTabBottomInset: CGFloat = 110
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
