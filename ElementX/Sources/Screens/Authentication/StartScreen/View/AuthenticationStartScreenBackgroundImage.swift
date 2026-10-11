//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

/// The background gradient shown on the launch, splash and onboarding screens.
struct AuthenticationStartScreenBackgroundImage: View {
    var body: some View {
        // Нютаг: небо над степью — синий бренда сверху растворяется в фоне экрана (вместо радуги Element).
        ZStack {
            Color.compound.bgCanvasDefault
            LinearGradient(colors: [Color(NyutagBrand.blue).opacity(0.32), Color(NyutagBrand.blue).opacity(0.08), .clear],
                           startPoint: .top,
                           endPoint: .center)
            RadialGradient(colors: [Color(NyutagBrand.gold).opacity(0.10), .clear],
                           center: .init(x: 0.85, y: 0.12),
                           startRadius: 0,
                           endRadius: 260)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
