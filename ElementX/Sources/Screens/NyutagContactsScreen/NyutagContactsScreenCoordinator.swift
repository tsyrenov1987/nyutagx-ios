//
// Нютаг (форк Element X iOS) — вкладка «Контакты».
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import SwiftUI

struct NyutagContactsScreenCoordinatorParameters {
    let clientProxy: ClientProxyProtocol
    let mediaProvider: MediaProviderProtocol
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum NyutagContactsScreenCoordinatorAction {
    case openRoom(roomID: String)
}

final class NyutagContactsScreenCoordinator: CoordinatorProtocol {
    private let viewModel: NyutagContactsScreenViewModelProtocol
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<NyutagContactsScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<NyutagContactsScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: NyutagContactsScreenCoordinatorParameters) {
        viewModel = NyutagContactsScreenViewModel(clientProxy: parameters.clientProxy,
                                                  mediaProvider: parameters.mediaProvider,
                                                  userIndicatorController: parameters.userIndicatorController)
    }
    
    func start() {
        viewModel.actionsPublisher.sink { [weak self] action in
            switch action {
            case .openRoom(let roomID):
                self?.actionsSubject.send(.openRoom(roomID: roomID))
            }
        }
        .store(in: &cancellables)
    }
    
    func toPresentable() -> AnyView {
        AnyView(NyutagContactsScreen(context: viewModel.context))
    }
}
