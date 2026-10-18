//
// Нютаг (форк Element X iOS) — вкладка «Контакты».
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol NyutagContactsScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<NyutagContactsScreenViewModelAction, Never> { get }
    var context: NyutagContactsScreenViewModelType.Context { get }
}
