//
// Нютаг (форк Element X iOS) — вкладка «Контакты»: кто из книжки в Нютаге (сверху) и кого позвать.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

enum NyutagContactsScreenViewModelAction {
    case openRoom(roomID: String)
}

struct NyutagContactsScreenViewState: BindableState {
    /// Кто из книжки уже в Нютаге — тот же расклад, что на экране «Начать чат».
    var inNyutag: NyutagContactsState = .needsPermission
    /// Остальные записи книжки: им — приглашение.
    var others: [NyutagContact] = []
}

enum NyutagContactsScreenViewAction {
    case load(requestPermission: Bool)
    case openContact(NyutagMatchedContact)
    case invite
}
