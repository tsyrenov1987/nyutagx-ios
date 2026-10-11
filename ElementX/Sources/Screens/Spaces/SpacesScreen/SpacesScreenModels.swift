//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum SpacesScreenViewModelAction {
    case selectSpace(SpaceRoomListProxyProtocol)
    case showSettings
    case showCreateSpace
    /// Нютаг: открыть сообщество из каталога, в котором человек ещё не состоит (предпросмотр и вступление).
    case joinCommunity(roomID: String)
}

struct SpacesScreenViewState: BindableState {
    var userProfile: UserProfile
    
    var topLevelSpaces: [SpaceServiceRoom]
    var selectedSpaceID: String?
    
    /// Нютаг: каталог всех сообществ сервера, как поиск сообществ во «ВКонтакте».
    var communities: [NyutagCommunity] = []
    var isLoadingCommunities = false
    var hasLoadedCommunities = false
    
    var bindings = SpacesScreenViewStateBindings()
    
    var isSearching: Bool {
        !bindings.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    /// Свои сообщества с учётом поиска.
    var visibleSpaces: [SpaceServiceRoom] {
        guard isSearching else { return topLevelSpaces }
        let query = bindings.searchQuery.trimmingCharacters(in: .whitespaces)
        return topLevelSpaces.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    
    /// Каталог без тех, где человек уже состоит.
    var catalog: [NyutagCommunity] {
        let joinedIDs = Set(topLevelSpaces.map(\.id))
        return communities.filter { !joinedIDs.contains($0.id) }
    }
}

struct SpacesScreenViewStateBindings {
    var searchQuery = ""
}

enum SpacesScreenViewAction {
    case spaceAction(SpaceRoomCell.Action)
    case showSettings
    case createSpace
    case openCommunity(NyutagCommunity)
    case searchQueryChanged
    case refreshCommunities
}
