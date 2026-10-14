//
// Нютаг (форк Element X iOS) — язык интерфейса внутри приложения.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import Observation

/// Бурятского нет среди языков iOS, поэтому язык выбирается в самом приложении (на старте и в настройках).
/// Для бурятского запасной язык — русский: чего нет в черновике перевода, покажется по-русски.
nonisolated enum NyutagLanguage: String, CaseIterable, Identifiable {
    case system = ""
    case russian = "ru"
    case buryat = "bxr"
    case english = "en"
    
    private static let key = "nyutag.language"
    
    var id: String { rawValue }
    
    /// Название на самом языке — так его узнают, даже не понимая текущего.
    var nativeName: String {
        switch self {
        case .system: NyutagL10n.languageSystem
        case .russian: "Русский"
        case .buryat: "Буряад"
        case .english: "English"
        }
    }
    
    /// Язык уже выбран (на первом экране или в настройках) — иначе первым показывается выбор языка.
    static var isChosen: Bool {
        UserDefaults.standard.object(forKey: key) != nil
    }
    
    static var current: NyutagLanguage {
        NyutagLanguage(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .system
    }
    
    /// Сохраняет выбор и сразу применяет к строкам приложения; системные части iOS подхватят его после перезапуска.
    static func select(_ language: NyutagLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: key)
        if let localizations = language.localizations {
            UserDefaults.standard.set(localizations, forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        apply()
        Task { @MainActor in NyutagLanguageRevision.shared.value += 1 }
    }
    
    /// Вызывается при запуске до первого экрана.
    static func apply() {
        Bundle.overrideLocalizations = current.localizations
    }
    
    private var localizations: [String]? {
        switch self {
        case .system: nil
        case .russian: ["ru"]
        case .buryat: ["bxr", "ru"]
        case .english: ["en"]
        }
    }
}

/// Счётчик смен языка: корневой экран привязан к нему через `.id`, поэтому весь интерфейс перерисовывается сразу.
@MainActor @Observable
final class NyutagLanguageRevision {
    static let shared = NyutagLanguageRevision()
    var value = 0
}
