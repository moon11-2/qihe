import SwiftUI

enum QiheFont {
    static func seal(size: CGFloat) -> Font {
        .custom("Songti SC", fixedSize: size).weight(.bold)
    }

    static func title(size: CGFloat) -> Font {
        .custom("Songti SC", fixedSize: size).weight(.semibold)
    }

    static func body(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func caption(size: CGFloat = 12, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight)
    }
}
