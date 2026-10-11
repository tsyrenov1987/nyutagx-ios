//
// Нютаг (форк Element X iOS) — настройки и сборка клиента SDK.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import MatrixRustSDK

/// Единственный сервер nyutag.chat: выбора сервера нет, ссылок на веб-клиент Element и аналитики тоже.
struct NyutagAppSettingsHook: AppSettingsHookProtocol {
    func configure(_ appSettings: AppSettings) -> AppSettings {
        // swiftlint:disable:next force_unwrapping
        let homeserver = URL(string: NyutagTunnel.homeserverURL)!
        appSettings.override(accountProviders: [.managed(serverName: NyutagTunnel.serverName, baseURL: homeserver, canUseServerName: false)],
                             allowOtherAccountProviders: false,
                             hideBrandChrome: false,
                             pushGatewayBaseURL: appSettings.pushGatewayBaseURL,
                             oAuthRedirectURL: appSettings.oAuthRedirectURL,
                             oAuthClientURIPath: appSettings.oAuthClientURIPath,
                             websiteURL: appSettings.websiteURL,
                             logoURL: appSettings.logoURL,
                             copyrightURL: appSettings.copyrightURL,
                             acceptableUseURL: appSettings.acceptableUseURL,
                             privacyURL: appSettings.privacyURL,
                             encryptionURL: appSettings.encryptionURL,
                             deviceVerificationURL: appSettings.deviceVerificationURL,
                             chatBackupDetailsURL: appSettings.chatBackupDetailsURL,
                             identityPinningViolationDetailsURL: appSettings.identityPinningViolationDetailsURL,
                             historySharingDetailsURL: appSettings.historySharingDetailsURL,
                             elementWebHosts: [],
                             accountProvisioningHost: appSettings.accountProvisioningHost,
                             bugReportApplicationID: "nyutag-ios",
                             analyticsTermsURL: nil,
                             mapTilerConfiguration: AppSettings.bundledMapTilerConfiguration)
        return appSettings
    }
}

/// Весь трафик SDK идёт через кильватер, и доверие только нашему CA (встроенные корни выключены).
nonisolated struct NyutagClientFactoryHook: ClientFactoryHookProtocol {
    func configure(_ builder: ClientBuilder, toRestore session: Session?) -> ClientBuilder {
        var builder = builder
            .disableBuiltInRootCertificates()
            .addRootCertificates(certificates: [NyutagTunnel.caDER])
        if let proxyURL = NyutagTunnel.proxyURL() {
            builder = builder.proxy(url: proxyURL)
        }
        return builder
    }
    
    func updateAuthenticationClient(_ client: ClientProtocol) -> ClientProtocol {
        client
    }
}
