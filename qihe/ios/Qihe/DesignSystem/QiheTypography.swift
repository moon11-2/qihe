import SwiftUI

enum QiheFont {
    static func seal(size: CGFloat) -> Font {
        .custom("Songti SC", size: size).weight(.bold)
    }

    static func title(size: CGFloat) -> Font {
        .custom("Songti SC", size: size).weight(.semibold)
    }

    static func body(size: CGFloat) -> Font {
        .system(size: size, weight: .regular)
    }
}

