//
// Нютаг (форк Element X iOS) — регистрация по приглашению, по шагам.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

enum NyutagSignUpScreenViewModelAction {
    /// Назад с первого шага — закрыть экран.
    case cancel
    case signedIn(UserSessionProtocol)
}

/// Шаги как в Telegram/WhatsApp: одно поле — одно решение. Шаг «Контакт» есть, только когда на сервере настроены SMS или почта.
enum NyutagSignUpStep: Hashable {
    case code
    case contact
    /// Телефон без SMS-кода (пока у сервера нет SMS): по номеру человека находят друзья.
    case phone
    case name
    case password
}

struct NyutagSignUpScreenViewState: BindableState {
    var steps: [NyutagSignUpStep] = [.code, .name, .password]
    var step: NyutagSignUpStep = .code
    var configuration: NyutagSignUpConfiguration?
    
    /// Код проверен сервером; `inviter` — Matrix ID пригласившего.
    var isCodeValid = false
    var inviter: String?
    
    var verification: NyutagVerification?
    var isContactVerified = false
    /// Номер, который сервер признал годным и свободным, в виде `+79…`.
    var checkedPhone: String?
    var resendIn = 0
    
    /// Аккаунт уже создан, осталось войти (если вход после регистрации сорвался).
    var registeredUserID: String?
    
    var isBusy = false
    /// Ошибка текущего шага — показывается под полем, без всплывающих окон.
    var errorMessage: String?
    
    var bindings = NyutagSignUpScreenBindings()
    
    var stepNumber: Int {
        (steps.firstIndex(of: step) ?? 0) + 1
    }
    
    var availableMedia: [NyutagContactMedium] {
        guard let configuration else { return [] }
        // Почта обязательна — на шаге «Контакт» только она, телефон спрашивается отдельно.
        let phone = configuration.isPhoneAvailable && !configuration.requiresEmail
        return [phone ? .phone : nil, configuration.isEmailAvailable ? .email : nil].compactMap(\.self)
    }
    
    var canSkipContact: Bool {
        configuration.map { !$0.requiresContact && !$0.requiresEmail } ?? false
    }
    
    /// Ник для входа: придуманный самим человеком или из имени.
    var username: String {
        bindings.isEditingUsername ? NyutagUsername.sanitize(bindings.username) : NyutagUsername.suggest(from: bindings.displayName)
    }
    
    var canContinue: Bool {
        guard !isBusy else { return false }
        switch step {
        case .code:
            return bindings.code.count == Self.codeLength
        case .contact:
            if verification == nil {
                return !bindings.contact.trimmingCharacters(in: .whitespaces).isEmpty
            }
            return bindings.verifyCode.count == Self.verifyCodeLength
        case .phone:
            return bindings.phone.count(where: \.isNumber) >= Self.minPhoneDigits
        case .name:
            return !bindings.displayName.trimmingCharacters(in: .whitespaces).isEmpty && !username.isEmpty
        case .password:
            return bindings.password.count >= Self.minPasswordLength && bindings.password == bindings.passwordRepeat
        }
    }
    
    var showsPasswordMismatch: Bool {
        !bindings.passwordRepeat.isEmpty && bindings.passwordRepeat.count >= bindings.password.count && bindings.password != bindings.passwordRepeat
    }
    
    static let codeLength = 9 // XXXX-XXXX
    static let verifyCodeLength = 6
    static let minPasswordLength = 8
    static let minPhoneDigits = 10
}

struct NyutagSignUpScreenBindings {
    var code = ""
    var medium: NyutagContactMedium = .phone
    var contact = ""
    var verifyCode = ""
    var phone = ""
    var displayName = ""
    var username = ""
    var isEditingUsername = false
    var password = ""
    var passwordRepeat = ""
}

enum NyutagSignUpScreenViewAction {
    case back
    case next
    case skipContact
    case resendCode
    case editUsername
    case codeChanged
    case contactChanged
    case verifyCodeChanged
    case phoneChanged
    case inputChanged
}

/// Ник из имени: кириллица (с бурятскими ө, ү, һ) переводится в латиницу, остальное отбрасывается.
enum NyutagUsername {
    static func suggest(from displayName: String) -> String {
        let latin = displayName.lowercased().map { character -> String in
            let value = String(character)
            if let mapped = transliteration[value] { return mapped }
            if character == " " || character == "-" || character == "." || character == "_" { return "." }
            return value
        }
        .joined()
        return sanitize(latin)
    }
    
    /// Только то, что примет сервер: `a-z 0-9 . _ -`, без точек по краям и двойных точек, не длиннее 24.
    static func sanitize(_ value: String) -> String {
        var result = value.lowercased()
            .trimmingCharacters(in: .whitespaces)
            .replacing(/^@/, with: "")
            .replacing(/:.*$/, with: "")
            .filter { ("a"..."z").contains($0) || ("0"..."9").contains($0) || "._-".contains($0) }
        while result.contains("..") {
            result = result.replacingOccurrences(of: "..", with: ".")
        }
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "._-"))
        return String(result.prefix(24))
    }
    
    private static let transliteration: [String: String] = [
        "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e", "ж": "zh", "з": "z", "и": "i", "й": "y",
        "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u", "ф": "f",
        "х": "kh", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "sch", "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya",
        "ө": "o", "ү": "u", "һ": "h"
    ]
}

/// Код приглашения в виде `XXXX-XXXX`: алфавит Crockford, похожие кириллические буквы — как на сервере.
enum NyutagInviteCode {
    static func format(_ input: String) -> String {
        let characters = input.uppercased().compactMap { character -> Character? in
            let mapped = lookalikes[character] ?? character
            return alphabet.contains(mapped) ? mapped : nil
        }
        let code = String(characters.prefix(8))
        return code.count > 4 ? "\(code.prefix(4))-\(code.dropFirst(4))" : code
    }
    
    private static let alphabet = Set("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
    private static let lookalikes: [Character: Character] = [
        "А": "A", "В": "B", "С": "C", "Е": "E", "Н": "H", "К": "K", "М": "M", "О": "0", "Р": "P", "Т": "T",
        "Х": "X", "У": "Y", "З": "3", "O": "0", "I": "1", "L": "1", "Ь": "B"
    ]
}
