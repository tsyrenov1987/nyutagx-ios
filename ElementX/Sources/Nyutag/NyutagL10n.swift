//
// Нютаг (форк Element X iOS) — свои строки (таблица Nyutag.strings, генерирует Tools/Nyutag/gen-strings.py).
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

nonisolated enum NyutagL10n {
    static var startSignIn: String { tr("nyutag_start_sign_in") }
    static var startHaveInvite: String { tr("nyutag_start_have_invite") }
    static var languageTitle: String { tr("nyutag_language_title") }
    static var languageSystem: String { tr("nyutag_language_system") }
    static var languageRestart: String { tr("nyutag_language_restart") }
    static var loginIdentifierHint: String { tr("nyutag_login_identifier_hint") }
    static var loginNoAccount: String { tr("nyutag_login_no_account") }
    static var inviteFriend: String { tr("nyutag_invite_friend") }
    static var sourceCode: String { tr("nyutag_source_code") }
    static var newChat: String { tr("nyutag_new_chat") }
    static var newGroup: String { tr("nyutag_new_group") }
    
    // MARK: Сообщества
    
    static var communityOpen: String { tr("nyutag_community_open") }
    static var communityOpenDescription: String { tr("nyutag_community_open_description") }
    static var communityClosed: String { tr("nyutag_community_closed") }
    static var communityClosedDescription: String { tr("nyutag_community_closed_description") }
    static var communityClosedBadge: String { tr("nyutag_community_closed_badge") }
    static var communitiesSearch: String { tr("nyutag_communities_search") }
    static var communitiesMine: String { tr("nyutag_communities_mine") }
    static var communitiesAll: String { tr("nyutag_communities_all") }
    static var communitiesEmpty: String { tr("nyutag_communities_empty") }
    
    // MARK: Регистрация
    
    static func signUpStep(_ step: Int, of total: Int) -> String { tr("nyutag_signup_step", step, total) }
    static var signUpCodeTitle: String { tr("nyutag_signup_code_title") }
    static var signUpCodeSubtitle: String { tr("nyutag_invite_signup_subtitle") }
    static var signUpCodeLabel: String { tr("nyutag_invite_code_label") }
    static var signUpPaste: String { tr("nyutag_signup_paste") }
    static var signUpContactTitle: String { tr("nyutag_contact_title") }
    static var signUpContactTitleOptional: String { tr("nyutag_contact_title_optional") }
    static var signUpContactSubtitle: String { tr("nyutag_signup_contact_subtitle") }
    static var contactPhone: String { tr("nyutag_contact_phone") }
    static var contactEmail: String { tr("nyutag_contact_email") }
    static var contactPhoneHint: String { tr("nyutag_contact_phone_hint") }
    static var contactEmailHint: String { tr("nyutag_contact_email_hint") }
    static var contactSendCode: String { tr("nyutag_contact_send_code") }
    static var contactSending: String { tr("nyutag_contact_sending") }
    static func contactResendIn(_ seconds: Int) -> String { tr("nyutag_contact_resend_in", seconds) }
    static var contactResend: String { tr("nyutag_contact_resend") }
    static var contactCodeSMS: String { tr("nyutag_contact_code_sms") }
    static var contactCodeEmail: String { tr("nyutag_contact_code_email") }
    static var signUpNameTitle: String { tr("nyutag_signup_name_title") }
    static var signUpNameSubtitle: String { tr("nyutag_signup_name_subtitle") }
    static var signUpNameLabel: String { tr("nyutag_signup_name_label") }
    static func signUpUsernameFooter(_ username: String) -> String { tr("nyutag_signup_username_footer", username) }
    static var signUpUsernameEdit: String { tr("nyutag_signup_username_edit") }
    static var signUpUsernameLabel: String { tr("nyutag_invite_username_label") }
    static var signUpUsernameHint: String { tr("nyutag_invite_username_hint") }
    static var signUpPasswordTitle: String { tr("nyutag_signup_password_title") }
    static var signUpPasswordSubtitle: String { tr("nyutag_signup_password_subtitle") }
    static var signUpPasswordLabel: String { tr("nyutag_invite_password_label") }
    static var signUpPasswordRepeat: String { tr("nyutag_signup_password_repeat") }
    static var signUpPasswordMismatch: String { tr("nyutag_signup_password_mismatch") }
    static var signUpSubmit: String { tr("nyutag_invite_submit") }
    static var signUpCreating: String { tr("nyutag_signup_creating") }
    static func signUpInvitedBy(_ inviter: String) -> String { tr("nyutag_signup_invited_by", inviter) }
    static var signUpLoginAfterRegisterFailed: String { tr("nyutag_invite_error_login_after_register") }
    
    // MARK: Приглашения
    
    static var inviteCreating: String { tr("nyutag_invite_creating") }
    static func inviteShareText(appName: String, code: String) -> String { tr("nyutag_invite_share_text", appName, code) }
    static var inviteLimit: String { tr("nyutag_invite_limit") }
    static var inviteNetwork: String { tr("nyutag_invite_network") }
    static var inviteFailed: String { tr("nyutag_invite_failed") }
    
    /// Текст ошибки сервиса приглашений по `errcode`.
    static func inviteError(_ errcode: String) -> String {
        let key = switch errcode {
        case "NYUTAG_UNKNOWN_CODE": "nyutag_invite_error_unknown_code"
        case "NYUTAG_CODE_USED": "nyutag_invite_error_used"
        case "NYUTAG_CODE_EXPIRED": "nyutag_invite_error_expired"
        case "NYUTAG_BAD_CODE": "nyutag_invite_error_bad_code"
        case "M_USER_IN_USE": "nyutag_invite_error_user_in_use"
        case "M_INVALID_USERNAME": "nyutag_invite_error_invalid_username"
        case "M_WEAK_PASSWORD": "nyutag_invite_error_weak_password"
        case "M_LIMIT_EXCEEDED": "nyutag_invite_error_limit"
        case "NYUTAG_NETWORK": "nyutag_invite_error_network"
        case "NYUTAG_BAD_CONTACT": "nyutag_contact_error_bad"
        case "NYUTAG_CONTACT_IN_USE": "nyutag_contact_error_in_use"
        case "NYUTAG_CONTACT_REQUIRED": "nyutag_contact_error_required"
        case "NYUTAG_CONTACT_NOT_VERIFIED": "nyutag_contact_error_not_verified"
        case "NYUTAG_CHANNEL_UNAVAILABLE": "nyutag_contact_error_channel_unavailable"
        case "NYUTAG_DELIVERY_FAILED": "nyutag_contact_error_delivery"
        case "NYUTAG_VERIFY_WRONG": "nyutag_contact_error_wrong_code"
        case "NYUTAG_VERIFY_EXPIRED": "nyutag_contact_error_code_expired"
        case "NYUTAG_VERIFY_ATTEMPTS": "nyutag_contact_error_attempts"
        default: "nyutag_invite_error_generic"
        }
        return tr(key)
    }
    
    /// Как `L10n.tr`: перебирает языки пользователя (или выбранный в приложении), иначе английский.
    private static func tr(_ key: String, _ args: CVarArg...) -> String {
        let languages = (Bundle.overrideLocalizations ?? Bundle.app.preferredLocalizations) + ["en"]
        for language in languages {
            guard let bundle = Bundle.lprojBundle(for: language) else { continue }
            let format = NSLocalizedString(key, tableName: "Nyutag", bundle: bundle, comment: "")
            if format != key {
                return String(format: format, locale: Locale(identifier: language), arguments: args)
            }
        }
        return key
    }
}
