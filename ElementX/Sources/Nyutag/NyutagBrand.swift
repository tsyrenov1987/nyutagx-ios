//
// Нютаг (форк Element X iOS) — фирменные цвета.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

/// Палитра Нютага: синий неба (#1C6FB3) — действия и акцент, золото соёмбо (#D9A227) — особые акценты.
enum NyutagBrand {
    static let blue = UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: 0x4C9BE6) : UIColor(rgb: 0x1C6FB3) }
    static let bluePressed = UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: 0x3B86CF) : UIColor(rgb: 0x155A92) }
    static let blueSubtle = UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: 0x13314D) : UIColor(rgb: 0xE1EEFA) }
    static let blueSelected = UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: 0x4C9BE6, alpha: 0.24) : UIColor(rgb: 0x1C6FB3, alpha: 0.14) }
    static let gold = UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: 0xE5B547) : UIColor(rgb: 0xD9A227) }
    /// Фон ленты чата под орнаментом.
    static let wallpaper = UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: 0x0E141B) : UIColor(rgb: 0xE6EEF6) }
    static let wallpaperInk = UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: 0x4C9BE6, alpha: 0.10) : UIColor(rgb: 0x1C6FB3, alpha: 0.09) }
    /// Текст на синих кнопках — белый в обеих темах.
    static let onBlue = UIColor.white
}

/// Перекрашивает акцент Compound (зелёный Element и чёрные кнопки) в синий Нютага.
struct NyutagCompoundHook: CompoundHookProtocol {
    func override(colors: CompoundColors, uiColors: CompoundUIColors) {
        let swiftUI: [(KeyPath<CompoundColorTokens, Color>, UIColor)] = [
            (\.bgActionPrimaryRest, NyutagBrand.blue),
            (\.bgActionPrimaryHovered, NyutagBrand.bluePressed),
            (\.bgActionPrimaryPressed, NyutagBrand.bluePressed),
            (\.textOnSolidPrimary, NyutagBrand.onBlue),
            (\.iconOnSolidPrimary, NyutagBrand.onBlue),
            (\.bgAccentRest, NyutagBrand.blue),
            (\.bgAccentHovered, NyutagBrand.bluePressed),
            (\.bgAccentPressed, NyutagBrand.bluePressed),
            (\.bgAccentSelected, NyutagBrand.blueSelected),
            (\.bgAccentSubtle, NyutagBrand.blueSubtle),
            (\.bgBadgeAccent, NyutagBrand.blueSubtle),
            (\.textBadgeAccent, NyutagBrand.blue),
            (\.iconAccentPrimary, NyutagBrand.blue),
            (\.iconAccentTertiary, NyutagBrand.blue),
            (\.textActionAccent, NyutagBrand.blue),
            (\.borderAccentPrimary, NyutagBrand.blue),
            (\.borderAccentSubtle, NyutagBrand.blueSubtle),
            (\.gradientActionStop1, NyutagBrand.blue),
            (\.gradientActionStop2, NyutagBrand.blue),
            (\.gradientActionStop3, NyutagBrand.bluePressed),
            (\.gradientActionStop4, NyutagBrand.bluePressed)
        ]
        for (keyPath, color) in swiftUI {
            colors.override(keyPath, with: Color(color))
        }
        let uiKit: [(KeyPath<CompoundUIColorTokens, UIColor> & Sendable, UIColor)] = [
            (\.bgActionPrimaryRest, NyutagBrand.blue),
            (\.textOnSolidPrimary, NyutagBrand.onBlue),
            (\.iconOnSolidPrimary, NyutagBrand.onBlue),
            (\.bgAccentRest, NyutagBrand.blue),
            (\.iconAccentPrimary, NyutagBrand.blue),
            (\.iconAccentTertiary, NyutagBrand.blue),
            (\.textActionAccent, NyutagBrand.blue)
        ]
        for (keyPath, color) in uiKit {
            uiColors.override(keyPath, with: color)
        }
    }
}

extension UIColor {
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255, blue: CGFloat(rgb & 0xFF) / 255, alpha: alpha)
    }
}
