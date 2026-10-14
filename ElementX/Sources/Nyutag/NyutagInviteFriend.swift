//
// Нютаг (форк Element X iOS) — «Пригласить друга».
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import UIKit

/// Одноразовый код от сервиса ядра и системное «Поделиться» с готовым текстом — как приглашение в WhatsApp/Telegram.
@MainActor
enum NyutagInviteFriend {
    static func share(clientProxy: ClientProxyProtocol, userIndicatorController: UserIndicatorControllerProtocol) async {
        let indicatorID = "NyutagInviteFriend-Loading"
        userIndicatorController.submitIndicator(UserIndicator(id: indicatorID, type: .modal, title: NyutagL10n.inviteCreating, persistent: true))
        
        guard let accessToken = (clientProxy as? ClientProxy)?.nyutagAccessToken else {
            userIndicatorController.retractIndicatorWithId(indicatorID)
            userIndicatorController.submitIndicator(UserIndicator(title: NyutagL10n.inviteFailed, icon: \.errorSolid))
            return
        }
        
        do throws(NyutagInviteError) {
            let invite = try await NyutagInvitesService.shared.createInvite(accessToken: accessToken)
            userIndicatorController.retractIndicatorWithId(indicatorID)
            present(text: NyutagL10n.inviteShareText(appName: InfoPlistReader.main.bundleDisplayName, code: invite.code))
        } catch {
            userIndicatorController.retractIndicatorWithId(indicatorID)
            let message = switch error.errcode {
            case "NYUTAG_INVITE_LIMIT", "M_LIMIT_EXCEEDED": NyutagL10n.inviteLimit
            case NyutagInviteError.network: NyutagL10n.inviteNetwork
            default: NyutagL10n.inviteFailed
            }
            userIndicatorController.submitIndicator(UserIndicator(title: message, icon: \.errorSolid))
        }
    }
    
    private static func present(text: String) {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        guard var presenter = window?.rootViewController else { return }
        while let presented = presenter.presentedViewController, !presented.isBeingDismissed {
            presenter = presented
        }
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let popover = activity.popoverPresentationController, let window {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(activity, animated: true)
    }
}

/// «Избранное» как в Telegram: личная комната, где участник только вы. Создаётся при первом открытии,
/// дальше открывается та же (id в account data).
@MainActor
enum NyutagSavedMessages {
    static func roomID(clientProxy: ClientProxyProtocol, userIndicatorController: UserIndicatorControllerProtocol) async -> String? {
        guard let proxy = clientProxy as? ClientProxy else { return nil }
        
        if let roomID = await proxy.nyutagSavedMessagesRoomID(),
           case .joined = await clientProxy.roomForIdentifier(roomID) {
            return roomID
        }
        
        let indicatorID = "NyutagSavedMessages-Creating"
        userIndicatorController.submitIndicator(UserIndicator(id: indicatorID, type: .modal, title: L10n.commonLoading, persistent: true))
        defer { userIndicatorController.retractIndicatorWithId(indicatorID) }
        
        let avatarURL = await proxy.nyutagUploadSavedMessagesAvatar()
        switch await clientProxy.createRoom(name: NyutagL10n.savedMessages,
                                            topic: NyutagL10n.savedMessagesTopic,
                                            accessType: .private,
                                            isSpace: false,
                                            userIDs: [],
                                            avatarURL: avatarURL.flatMap(URL.init(string:)),
                                            aliasLocalPart: nil) {
        case .success(let roomID):
            _ = await proxy.nyutagSetSavedMessagesRoomID(roomID)
            return roomID
        case .failure:
            userIndicatorController.submitIndicator(UserIndicator(title: L10n.errorUnknown, icon: \.errorSolid))
            return nil
        }
    }
}
