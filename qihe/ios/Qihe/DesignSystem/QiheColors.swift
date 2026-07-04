import SwiftUI

enum QiheColor {
    static let ink = Color(hex: 0x1D2129)
    static let inkSoft = Color(hex: 0x4B4E55)
    static let muted = Color(hex: 0x858179)
    static let paper = Color(hex: 0xF6F3EC)
    static let paperDeep = Color(hex: 0xECE6DA)
    static let card = Color(hex: 0xFFFDF8)
    static let line = Color(hex: 0xE2DDD2)
    static let lineStrong = Color(hex: 0xCFC7B8)
    static let navy = Color(hex: 0x183A59)
    static let navySoft = Color(hex: 0xE6EDF3)
    static let seal = Color(hex: 0xC23528)
    static let sealSoft = Color(hex: 0xF7E7E3)
    static let amber = Color(hex: 0xA87318)
    static let amberSoft = Color(hex: 0xF5EAD2)
    static let pine = Color(hex: 0x2F6F54)
    static let pineSoft = Color(hex: 0xE4F0EA)
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
