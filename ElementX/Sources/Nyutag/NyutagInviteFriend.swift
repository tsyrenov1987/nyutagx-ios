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
