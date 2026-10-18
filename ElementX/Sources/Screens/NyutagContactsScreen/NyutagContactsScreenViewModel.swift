//
// Нютаг (форк Element X iOS) — вкладка «Контакты».
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import Contacts
import SwiftUI

typealias NyutagContactsScreenViewModelType = StateStoreViewModelV2<NyutagContactsScreenViewState, NyutagContactsScreenViewAction>

class NyutagContactsScreenViewModel: NyutagContactsScreenViewModelType, NyutagContactsScreenViewModelProtocol {
    private let clientProxy: ClientProxyProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    private var loadTask: Task<Void, Never>?
    
    private let actionsSubject: PassthroughSubject<NyutagContactsScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<NyutagContactsScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(clientProxy: ClientProxyProtocol, mediaProvider: MediaProviderProtocol, userIndicatorController: UserIndicatorControllerProtocol) {
        self.clientProxy = clientProxy
        self.userIndicatorController = userIndicatorController
        super.init(initialViewState: .init(), mediaProvider: mediaProvider)
    }
    
    override func process(viewAction: NyutagContactsScreenViewAction) {
        switch viewAction {
        case .load(let requestPermission):
            load(requestPermission: requestPermission)
        case .openContact(let contact):
            Task { await open(contact) }
        case .invite:
            Task { await NyutagInviteFriend.share(clientProxy: clientProxy, userIndicatorController: userIndicatorController) }
        }
    }
    
    /// Записи книжки, которых нет среди найденных в Нютаге; номер сравнивается по последним 10 цифрам (+7… и 8… — один).
    nonisolated static func others(book: [NyutagContact], matched: [NyutagMatchedContact]) -> [NyutagContact] {
        let matchedKeys = Set(matched.map { phoneKey($0.phone) })
        return book
            .filter { !matchedKeys.contains(phoneKey($0.phone)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    // MARK: - Private
    
    private nonisolated static func phoneKey(_ phone: String) -> String {
        String(phone.filter(\.isNumber).suffix(10))
    }
    
    /// Сначала книжка и прошлый итог сверки — список виден сразу; потом свежая сверка с сервером.
    private func load(requestPermission: Bool) {
        guard loadTask == nil else { return }
        loadTask = Task {
            defer { loadTask = nil }
            var status = CNContactStore.authorizationStatus(for: .contacts)
            if status == .notDetermined, requestPermission {
                _ = try? await CNContactStore().requestAccess(for: .contacts)
                status = CNContactStore.authorizationStatus(for: .contacts)
            }
            switch status {
            case .authorized, .limited:
                break
            case .notDetermined:
                state.inNyutag = .needsPermission
                return
            default:
                state.inNyutag = .denied
                return
            }
            
            let book = await Task.detached { NyutagAddressBook.contacts() }.value
            let cached = NyutagContactsSync.cached(userID: clientProxy.userID)
            state.inNyutag = .syncing(cached: cached)
            state.others = Self.others(book: book, matched: cached ?? [])
            do throws(NyutagInviteError) {
                let matched = try await NyutagContactsSync.sync(clientProxy: clientProxy, force: requestPermission)
                state.inNyutag = .loaded(matched)
                state.others = Self.others(book: book, matched: matched)
            } catch {
                state.inNyutag = cached.map { .loaded($0) } ?? .failed
            }
        }
    }
    
    /// Есть личный чат — открываем, нет — создаём без подтверждения (как на экране «Начать чат»).
    private func open(_ contact: NyutagMatchedContact) async {
        if case .success(.some(let roomID)) = clientProxy.directRoomForUserID(contact.userID) {
            actionsSubject.send(.openRoom(roomID: roomID))
            return
        }
        let indicatorID = "NyutagContacts-CreatingDM"
        userIndicatorController.submitIndicator(UserIndicator(id: indicatorID,
                                                              type: .modal(progress: .indeterminate, interactiveDismissDisabled: true, allowsInteraction: false),
                                                              title: L10n.commonLoading,
                                                              persistent: true))
        defer { userIndicatorController.retractIndicatorWithId(indicatorID) }
        switch await clientProxy.createDirectRoom(with: contact.userID, expectedRoomName: contact.name) {
        case .success(let roomID):
            actionsSubject.send(.openRoom(roomID: roomID))
        case .failure:
            userIndicatorController.submitIndicator(UserIndicator(title: L10n.screenStartChatErrorStartingChat, icon: \.errorSolid))
        }
    }
}
