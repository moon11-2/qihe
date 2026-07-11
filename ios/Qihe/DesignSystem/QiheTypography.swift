import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum QiheTypography {
    static let bodyLineSpacing: CGFloat = 9
    static let contractLineSpacing: CGFloat = 12

    static func display() -> Font {
        QiheFont.display()
    }

    static func h1() -> Font {
        QiheFont.h1()
    }

    static func h2() -> Font {
        QiheFont.h2()
    }

    static func h3() -> Font {
        QiheFont.h3()
    }

    static func body(weight: Font.Weight = .regular) -> Font {
        QiheFont.body(size: 15, weight: weight)
    }

    static func caption(weight: Font.Weight = .regular) -> Font {
        QiheFont.caption(size: 13, weight: weight)
    }

    static func micro(weight: Font.Weight = .medium) -> Font {
        QiheFont.micro(weight: weight)
    }

    static func contractDocument(weight: Font.Weight = .regular) -> Font {
        QiheFont.contractDocument(weight: weight)
    }
}

enum QiheFont {
    static func display(size: CGFloat = 32, weight: Font.Weight = .bold) -> Font {
        QiheDynamicTypeFont.system(size: size, weight: weight, role: .display)
    }

    static func h1(size: CGFloat = 24, weight: Font.Weight = .semibold) -> Font {
        QiheDynamicTypeFont.system(size: size, weight: weight, role: .title1)
    }

    static func h2(size: CGFloat = 20, weight: Font.Weight = .semibold) -> Font {
        QiheDynamicTypeFont.system(size: size, weight: weight, role: .title2)
    }

    static func h3(size: CGFloat = 17, weight: Font.Weight = .medium) -> Font {
        QiheDynamicTypeFont.system(size: size, weight: weight, role: .headline)
    }

    static func micro(size: CGFloat = 11, weight: Font.Weight = .medium) -> Font {
        QiheDynamicTypeFont.system(size: size, weight: weight, role: .caption2)
    }

    static func contractDocument(size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        QiheDynamicTypeFont.system(size: size, weight: weight, role: .body)
    }

    static func seal(size: CGFloat) -> Font {
        QiheDynamicTypeFont.system(size: size, weight: .bold, role: .headline)
    }

    static func title(size: CGFloat) -> Font {
        QiheDynamicTypeFont.system(size: size, weight: .semibold, role: .headline)
    }

    static func body(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        QiheDynamicTypeFont.system(size: size, weight: weight, role: .body)
    }

    static func document(size: CGFloat) -> Font {
        QiheDynamicTypeFont.system(size: size, weight: .regular, role: .body)
    }

    static func caption(size: CGFloat = 12, weight: Font.Weight = .medium) -> Font {
        QiheDynamicTypeFont.system(size: size, weight: weight, role: .caption1)
    }
}

private enum QiheFontRole {
    case display
    case title1
    case title2
    case headline
    case body
    case caption1
    case caption2
}

private enum QiheDynamicTypeFont {
    static func system(size: CGFloat, weight: Font.Weight, role: QiheFontRole) -> Font {
        #if canImport(UIKit)
        let metrics = UIFontMetrics(forTextStyle: textStyle(for: role))
        let scaledSize = metrics.scaledValue(for: size)
        return .system(size: scaledSize, weight: weight, design: .default)
        #else
        return .system(size: size, weight: weight, design: .default)
        #endif
    }

    #if canImport(UIKit)
    private static func textStyle(for role: QiheFontRole) -> UIFont.TextStyle {
        switch role {
        case .display:
            return .largeTitle
        case .title1:
            return .title1
        case .title2:
            return .title2
        case .headline:
            return .headline
        case .body:
            return .body
        case .caption1:
            return .caption1
        case .caption2:
            return .caption2
        }
    }
    #endif
}
