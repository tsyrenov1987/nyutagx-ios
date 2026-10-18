//
// Нютаг (форк Element X iOS) — свои строки (таблица Nyutag.strings, генерирует Tools/Nyutag/gen-strings.py).
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

nonisolated enum NyutagL10n {
    static var startSignIn: String { tr("nyutag_start_sign_in") }
    static var startHaveInvite: String { tr("nyutag_start_have_invite") }
    static var startSignUp: String { tr("nyutag_start_sign_up") }
    static var notInContacts: String { tr("nyutag_not_in_contacts") }
    static var notInContactsCheck: String { tr("nyutag_not_in_contacts_check") }
    static var languageTitle: String { tr("nyutag_language_title") }
    static var languageSystem: String { tr("nyutag_language_system") }
    static var languageRestart: String { tr("nyutag_language_restart") }
    static var loginIdentifierHint: String { tr("nyutag_login_identifier_hint") }
    static var loginNoAccount: String { tr("nyutag_login_no_account") }
    static var inviteFriend: String { tr("nyutag_invite_friend") }
    static var donateTitle: String { tr("nyutag_donate_title") }
    static var donateBody: String { tr("nyutag_donate_body") }
    static var donateThanks: String { tr("nyutag_donate_thanks") }
    static var donateUnavailable: String { tr("nyutag_donate_unavailable") }
    static var sourceCode: String { tr("nyutag_source_code") }
    static var newChat: String { tr("nyutag_new_chat") }
    static var newGroup: String { tr("nyutag_new_group") }
    static var callReturn: String { tr("nyutag_call_return") }
    static var callEnd: String { tr("nyutag_call_end") }
    
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
    static var communityInvite: String { tr("nyutag_community_invite") }
    static var savedMessages: String { tr("nyutag_saved_messages") }
    static var savedMessagesTopic: String { tr("nyutag_saved_messages_topic") }
    static var roomSearch: String { tr("nyutag_room_search") }
    static var roomSearchHint: String { tr("nyutag_room_search_hint") }
    static var roomSearchEmpty: String { tr("nyutag_room_search_empty") }
    static var roomSearchNote: String { tr("nyutag_room_search_note") }
    static var wallpaperTitle: String { tr("nyutag_wallpaper_title") }
    static var wallpaperSky: String { tr("nyutag_wallpaper_sky") }
    static var wallpaperSteppe: String { tr("nyutag_wallpaper_steppe") }
    static var wallpaperSand: String { tr("nyutag_wallpaper_sand") }
    static var wallpaperDusk: String { tr("nyutag_wallpaper_dusk") }
    static var wallpaperPlain: String { tr("nyutag_wallpaper_plain") }
    static var communityMembers: String { tr("nyutag_community_members") }
    static var communityLeave: String { tr("nyutag_community_leave") }
    static var communityGroups: String { tr("nyutag_community_groups") }
    static var communityEmptyTitle: String { tr("nyutag_community_empty_title") }
    static var communityEmptySubtitle: String { tr("nyutag_community_empty_subtitle") }
    static func communityInviteText(_ name: String, _ link: String) -> String { tr("nyutag_community_invite_text", name, link) }
    
    // MARK: Регистрация
    
    static func signUpStep(_ step: Int, of total: Int) -> String { tr("nyutag_signup_step", step, total) }
    static var signUpCodeTitle: String { tr("nyutag_signup_code_title") }
    static var signUpTitle: String { tr("nyutag_signup_title") }
    static var signUpFormSubtitle: String { tr("nyutag_signup_form_subtitle") }
    static func signUpVerifySubtitle(_ contact: String) -> String { tr("nyutag_signup_verify_subtitle", contact) }
    static var signUpOptional: String { tr("nyutag_signup_optional") }
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
    static var signUpPhoneSubtitle: String { tr("nyutag_signup_phone_subtitle") }
    
    // MARK: Сброс пароля
    
    static var passwordResetTitle: String { tr("nyutag_password_reset_title") }
    static var passwordResetSubtitle: String { tr("nyutag_password_reset_subtitle") }
    static var passwordResetNew: String { tr("nyutag_password_reset_new") }
    static var passwordResetSubmit: String { tr("nyutag_password_reset_submit") }
    
    // MARK: Поиск по номеру телефона
    
    static var byPhoneTitle: String { tr("nyutag_by_phone_title") }
    static var byPhoneSubtitle: String { tr("nyutag_by_phone_subtitle") }
    static var byPhoneLabel: String { tr("nyutag_by_phone_label") }
    static var byPhonePickContact: String { tr("nyutag_by_phone_pick_contact") }
    static var byPhoneSearch: String { tr("nyutag_by_phone_search") }
    static var byPhoneFound: String { tr("nyutag_by_phone_found") }
    static var byPhoneWrite: String { tr("nyutag_by_phone_write") }
    static var byPhoneNotFoundTitle: String { tr("nyutag_by_phone_not_found_title") }
    static var byPhoneNotFoundSubtitle: String { tr("nyutag_by_phone_not_found_subtitle") }
    static var byPhoneInvite: String { tr("nyutag_by_phone_invite") }
    static var byPhoneQRHint: String { tr("nyutag_by_phone_qr_hint") }
    static func byPhoneCode(_ code: String) -> String { tr("nyutag_by_phone_code", code) }
    static var byPhoneSMS: String { tr("nyutag_by_phone_sms") }
    static var byPhoneShare: String { tr("nyutag_by_phone_share") }
    static func byPhoneInviteText(code: String, link: String) -> String { tr("nyutag_by_phone_invite_text", code, link) }
    static var byPhoneOwnTitle: String { tr("nyutag_by_phone_own_title") }
    static var byPhoneOwnSubtitle: String { tr("nyutag_by_phone_own_subtitle") }
    static var byPhoneOwnLabel: String { tr("nyutag_by_phone_own_label") }
    static var contactsSection: String { tr("nyutag_contacts_section") }
    static var contactsAllow: String { tr("nyutag_contacts_allow") }
    static var contactsAllowSubtitle: String { tr("nyutag_contacts_allow_subtitle") }
    static var contactsEmpty: String { tr("nyutag_contacts_empty") }
    static var contactsDenied: String { tr("nyutag_contacts_denied") }
    static var contactsSyncing: String { tr("nyutag_contacts_syncing") }
    
    /// Ошибка экрана «По номеру телефона».
    static func byPhoneError(_ errcode: String) -> String {
        let key = switch errcode {
        case NyutagInviteError.network: "nyutag_by_phone_error_network"
        case "M_LIMIT_EXCEEDED": "nyutag_by_phone_error_limit"
        case "NYUTAG_INVITE_LIMIT": "nyutag_by_phone_error_invite_limit"
        case "NYUTAG_BAD_CONTACT": "nyutag_by_phone_error_bad_phone"
        case "NYUTAG_CONTACT_IN_USE": "nyutag_by_phone_error_phone_in_use"
        default: "nyutag_by_phone_error_generic"
        }
        return tr(key)
    }
    
    // MARK: Приглашения
    
    static var inviteCreating: String { tr("nyutag_invite_creating") }
    static func inviteShareText(appName: String, code: String, link: String) -> String { tr("nyutag_invite_share_text", appName, code, link) }
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
        case "NYUTAG_EMAIL_REQUIRED": "nyutag_signup_error_email_required"
        case "NYUTAG_PHONE_REQUIRED": "nyutag_signup_error_phone_required"
        case "NYUTAG_CONTACT_NOT_VERIFIED": "nyutag_contact_error_not_verified"
        case "NYUTAG_CHANNEL_UNAVAILABLE": "nyutag_contact_error_channel_unavailable"
        case "NYUTAG_DELIVERY_FAILED": "nyutag_contact_error_delivery"
        case "NYUTAG_VERIFY_WRONG": "nyutag_contact_error_wrong_code"
        case "NYUTAG_VERIFY_EXPIRED": "nyutag_contact_error_code_expired"
        case "NYUTAG_VERIFY_ATTEMPTS": "nyutag_contact_error_attempts"
        case "NYUTAG_CONTACT_UNKNOWN": "nyutag_password_reset_error_unknown"
        default: "nyutag_invite_error_generic"
        }
        return tr(key)
    }
    
    /// Как `L10n.tr`: перебирает языки пользователя (или выбранный в приложении), иначе английский.
    static var messageRead: String { tr("nyutag_message_read") }
    static var presenceOnline: String { tr("nyutag_presence_online") }
    static var presenceJustNow: String { tr("nyutag_presence_just_now") }
    static var presenceRecently: String { tr("nyutag_presence_recently") }
    static func presenceMinutesAgo(_ minutes: Int) -> String { tr("nyutag_presence_minutes_ago", minutes) }
    static func presenceTodayAt(_ time: String) -> String { tr("nyutag_presence_today_at", time) }
    static func presenceYesterdayAt(_ time: String) -> String { tr("nyutag_presence_yesterday_at", time) }
    static func presenceDate(_ date: String) -> String { tr("nyutag_presence_date", date) }
    
    /// Сведения о личном чате — как в Telegram.
    static var dmDetailsTitle: String { tr("nyutag_dm_details_title") }
    static var dmDeleteChat: String { tr("nyutag_dm_delete_chat") }
    static var dmDeleteChatSubtitle: String { tr("nyutag_dm_delete_chat_subtitle") }
    
    /// Вкладка «Контакты» и боковое меню главного экрана — как в Telegram.
    static var tabContacts: String { tr("nyutag_tab_contacts") }
    static var contactsOnNyutag: String { tr("nyutag_contacts_on_nyutag") }
    static var contactsInviteSection: String { tr("nyutag_contacts_invite_section") }
    static var drawerOpen: String { tr("nyutag_drawer_open") }
    static var drawerMyProfile: String { tr("nyutag_drawer_my_profile") }
    static var drawerNewGroup: String { tr("nyutag_drawer_new_group") }
    static var drawerContacts: String { tr("nyutag_drawer_contacts") }
    static var drawerSavedMessages: String { tr("nyutag_drawer_saved_messages") }
    static var drawerSettings: String { tr("nyutag_drawer_settings") }
    static var drawerInvite: String { tr("nyutag_drawer_invite") }
    
    /// Переключатель качества на экране отправки фото и видео.
    static var mediaQualityHigh: String { tr("nyutag_media_quality_high") }
    static var mediaQualityHighOn: String { tr("nyutag_media_quality_high_on") }
    static var mediaQualityHighOff: String { tr("nyutag_media_quality_high_off") }
    
    /// Закреплённые чаты и папки.
    static var pinLimit: String { tr("nyutag_pin_limit") }
    static var folderAdd: String { tr("nyutag_folder_add") }
    static var folderAll: String { tr("nyutag_folder_all") }
    static var folderNew: String { tr("nyutag_folder_new") }
    static var folderName: String { tr("nyutag_folder_name") }
    static var folderRename: String { tr("nyutag_folder_rename") }
    static var folderDelete: String { tr("nyutag_folder_delete") }
    static var folderDeleteHint: String { tr("nyutag_folder_delete_hint") }
    static var folderEmptyTitle: String { tr("nyutag_folder_empty_title") }
    static var folderEmpty: String { tr("nyutag_folder_empty") }
    static var a11yPinnedChat: String { tr("a11y_nyutag_pinned_chat") }

    /// «О себе» в профиле.
    static var profileAbout: String { tr("nyutag_profile_about") }
    static var profileToonto: String { tr("nyutag_profile_toonto") }
    static var profileUg: String { tr("nyutag_profile_ug") }
    static var profileEastYear: String { tr("nyutag_profile_east_year") }
    static var profileAboutPlaceholder: String { tr("nyutag_profile_about_placeholder") }
    static var profileToontoPlaceholder: String { tr("nyutag_profile_toonto_placeholder") }
    static var profileUgPlaceholder: String { tr("nyutag_profile_ug_placeholder") }
    static var profileEastYearNone: String { tr("nyutag_profile_east_year_none") }
    static var profileEastYearPick: String { tr("nyutag_profile_east_year_pick") }
    static var profileEastYearHint: String { tr("nyutag_profile_east_year_hint") }
    static func eastYearFormat(_ element: String, _ animal: String) -> String { tr("nyutag_east_year_format", element, animal) }
    static func eastYearElementMasculine(_ index: Int) -> String { tr("nyutag_east_year_elements_m_\(index)") }
    static func eastYearElementFeminine(_ index: Int) -> String { tr("nyutag_east_year_elements_f_\(index)") }
    static func eastYearAnimal(_ index: Int) -> String { tr("nyutag_east_year_animals_\(index)") }

    static var autoDeleteTitle: String { tr("nyutag_autodelete_title") }
    static var autoDeleteSubtitle: String { tr("nyutag_autodelete_subtitle") }
    static var autoDeleteOff: String { tr("nyutag_autodelete_off") }
    static var autoDeleteDay: String { tr("nyutag_autodelete_day") }
    static var autoDeleteWeek: String { tr("nyutag_autodelete_week") }
    static var autoDeleteMonth: String { tr("nyutag_autodelete_month") }
    static var autoDeleteError: String { tr("nyutag_autodelete_error") }
    static var viewOnceToggle: String { tr("nyutag_view_once_toggle") }
    static var viewOnceReceived: String { tr("nyutag_view_once_received") }
    static var viewOnceSent: String { tr("nyutag_view_once_sent") }
    static var viewOnceOpened: String { tr("nyutag_view_once_opened") }
    static var scheduleSend: String { tr("nyutag_schedule_send") }
    static var scheduleTitle: String { tr("nyutag_schedule_title") }
    static func scheduleBanner(_ count: Int) -> String { tr("nyutag_schedule_banner", count) }
    static var scheduleSendNow: String { tr("nyutag_schedule_send_now") }
    static func scheduleAt(_ time: String) -> String { tr("nyutag_schedule_at", time) }
    static var scheduleHint: String { tr("nyutag_schedule_hint_ios") }
    static var scheduleErrorPast: String { tr("nyutag_schedule_error_past") }

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
