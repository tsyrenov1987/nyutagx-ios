//
// Нютаг (форк Element X iOS) — регистрация по приглашению, по шагам.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import SwiftUI

struct NyutagSignUpScreenCoordinatorParameters {
    let authenticationService: AuthenticationServiceProtocol
    /// Сервер из `accountProviders` — к нему входим после регистрации.
    let serverNameOrBaseURL: String
    let userIndicatorController: UserIndicatorControllerProtocol
    /// Код из ссылки-приглашения; пусто — человек введёт его сам.
    var initialCode = ""
}

enum NyutagSignUpScreenCoordinatorAction {
    case cancel
    case signedIn(UserSessionProtocol)
}

final class NyutagSignUpScreenCoordinator: CoordinatorProtocol {
    private let viewModel: NyutagSignUpScreenViewModel
    
    private let actionsSubject: PassthroughSubject<NyutagSignUpScreenCoordinatorAction, Never> = .init()
    private var cancellables = Set<AnyCancellable>()
    
    var actions: AnyPublisher<NyutagSignUpScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: NyutagSignUpScreenCoordinatorParameters) {
        viewModel = NyutagSignUpScreenViewModel(authenticationService: parameters.authenticationService,
                                                serverNameOrBaseURL: parameters.serverNameOrBaseURL,
                                                userIndicatorController: parameters.userIndicatorController,
                                                initialCode: parameters.initialCode)
    }
    
    func start() {
        viewModel.actions
            .sink { [weak self] action in
                guard let self else { return }
                switch action {
                case .cancel:
                    actionsSubject.send(.cancel)
                case .signedIn(let userSession):
                    actionsSubject.send(.signedIn(userSession))
                }
            }
            .store(in: &cancellables)
    }
    
    func toPresentable() -> AnyView {
        AnyView(NyutagSignUpScreen(context: viewModel.context))
    }
}
