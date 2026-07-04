import SwiftUI

enum QiheColor {
    static let ink = Color(hex: 0x1D2129)
    static let inkSoft = Color(hex: 0x4B4E55)
    static let muted = Color(hex: 0x8A8A82)
    static let paper = Color(hex: 0xF7F5F0)
    static let card = Color(hex: 0xFEFDFB)
    static let line = Color(hex: 0xE5E1D8)
    static let lineStrong = Color(hex: 0xD0CBBE)
    static let navy = Color(hex: 0x23405F)
    static let seal = Color(hex: 0xC23528)
    static let amber = Color(hex: 0xB07F1E)
    static let pine = Color(hex: 0x3D7A5C)
}

private extension Color {
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

