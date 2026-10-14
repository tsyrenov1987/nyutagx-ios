//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct LegalInformationScreen: View {
    let context: LegalInformationScreenViewModel.Context
    @Environment(\.openURL) private var openURL
    private static let nyutagSourceURL = URL(string: "https://github.com/tsyrenov1987/nyutagx-ios")! // swiftlint:disable:this force_unwrapping
    
    var body: some View {
        Form {
            Section {
                ListRow(label: .plain(title: L10n.commonCopyright),
                        kind: .button { openURL(context.viewState.copyrightURL) })
                ListRow(label: .plain(title: L10n.commonAcceptableUsePolicy),
                        kind: .button { openURL(context.viewState.acceptableUseURL) })
                ListRow(label: .plain(title: L10n.commonPrivacyPolicy),
                        kind: .button { openURL(context.viewState.privacyURL) })
            }
            
            // Нютаг: исходники этой сборки (AGPL-3.0) — ссылка обязана быть доступна каждому пользователю.
            Section {
                ListRow(label: .plain(title: NyutagL10n.sourceCode),
                        kind: .button { openURL(Self.nyutagSourceURL) })
            }
        }
        .compoundList()
        .navigationTitle(L10n.commonAbout)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Previews

struct LegalInformationScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = LegalInformationScreenViewModel(appSettings: .volatile())
    static var previews: some View {
        LegalInformationScreen(context: viewModel.context)
    }
}
