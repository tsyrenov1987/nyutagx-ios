//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum StartChatScreenErrorType: Error {
    case failedCreatingRoom
}

enum StartChatScreenViewModelAction: Equatable {
    case close
    case createRoom
    case showRoom(roomID: String)
    case openRoomDirectorySearch
}

struct StartChatScreenViewState: BindableState {
    let userID: String
    var bindings = StartChatScreenViewStateBindings()
    var usersSection: UserDiscoverySection = .init(type: .suggestions, users: [])
    
    var isSearching: Bool {
        !bindings.searchQuery.isEmpty
    }
    
    var hasEmptySearchResults: Bool {
        isSearching && usersSection.type == .searchResult && usersSection.users.isEmpty
    }
    
    var joinByAddressState: JoinByAddressState = .example
    
    /// Нютаг: кто из записной книжки уже здесь.
    var nyutagContacts: NyutagContactsState = .needsPermission
}

/// Нютаг: раздел «Контакты в Нютаге» на экране «Начать чат».
enum NyutagContactsState: Equatable {
    /// Разрешение на контакты ещё не спрашивали — строка «Найти знакомых из контактов».
    case needsPermission
    /// Разрешение отклонено — подсказка про настройки телефона.
    case denied
    /// Сверка идёт; `cached` — прошлый итог, чтобы список не мигал.
    case syncing(cached: [NyutagMatchedContact]?)
    case loaded([NyutagMatchedContact])
    /// Сверка не удалась и прошлого итога нет.
    case failed
}

struct StartChatScreenViewStateBindings {
    var searchQuery = ""
    var roomAddress = ""
    
    /// Information describing the currently displayed alert.
    var alertInfo: AlertInfo<StartChatScreenErrorType>?
    
    var selectedUserToInvite: UserToInvite?
    var isJoinRoomByAddressSheetPresented = false
    /// Нютаг: открытый экран «По номеру телефона».
    var nyutagFindByPhone: NyutagFindByPhoneModel?
}

enum StartChatScreenViewAction {
    case close
    case createRoom
    case createDM(user: UserProfile)
    case selectUser(UserProfile)
    case joinRoomByAddress
    case openRoomDirectorySearch
    /// Нютаг: выпустить код приглашения и поделиться им.
    case nyutagInviteFriend
    case nyutagSavedMessages
    /// Нютаг: найти знакомого по номеру; нет в Нютаге — пригласить ссылкой, QR или SMS.
    case nyutagFindByPhone
    /// Нютаг: спросить разрешение на контакты (или обновить список) и сверить книжку с сервером.
    case nyutagSyncContacts
    /// Нютаг: чат с человеком из записной книжки — без вопроса «начать чат?», как при поиске по номеру.
    case nyutagOpenContact(NyutagMatchedContact)
}

enum JoinByAddressState: Equatable {
    case example
    case invalidAddress
    case addressNotFound
    case addressFound(address: String, roomID: String)
}
