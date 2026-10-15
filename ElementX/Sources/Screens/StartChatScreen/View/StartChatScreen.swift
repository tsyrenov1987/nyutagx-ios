//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct StartChatScreen: View {
    @ObservedObject var context: StartChatScreenViewModel.Context
    
    var body: some View {
        Form {
            if !context.viewState.isSearching {
                mainContent
            } else {
                searchContent
            }
        }
        .compoundList()
        .track(screen: .StartChat)
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(L10n.actionStartChat)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .searchController(query: $context.searchQuery,
                          placeholder: L10n.commonSearchForSomeone,
                          showsCancelButton: false,
                          disablesInteractiveDismiss: true)
        .compoundSearchField()
        .alert(item: $context.alertInfo)
        .sheet(item: $context.selectedUserToInvite) { userToInvite in
            SendInviteConfirmationView(userToInvite: userToInvite,
                                       mediaProvider: context.mediaProvider) {
                context.send(viewAction: .createDM(user: userToInvite.user))
            }
        }
        .sheet(item: $context.nyutagFindByPhone) { model in
            NyutagFindByPhoneView(model: model) { user in
                context.nyutagFindByPhone = nil
                // Сначала закрывается этот экран, потом обычный «Начать чат» (открыть чат или подтвердить новый).
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    context.send(viewAction: .selectUser(user))
                }
            }
        }
        .sheet(isPresented: $context.isJoinRoomByAddressSheetPresented) {
            context.roomAddress = ""
        } content: {
            JoinRoomByAddressView(context: context)
        }
    }
    
    // MARK: - Private
    
    /// The content shown in the form when the search query is empty.
    @ViewBuilder
    private var mainContent: some View {
        // Нютаг: как в Telegram — одним блоком «Новая группа», «Пригласить друга», «Каталог групп», ниже люди.
        // Вход по адресу #группа:сервер убран как технический.
        nyutagActionsSection
        nyutagContactsSection
        usersSection
    }
    
    /// The content shown in the form when a search query has been entered.
    @ViewBuilder
    private var searchContent: some View {
        if context.viewState.hasEmptySearchResults {
            noResultsContent
        } else {
            usersSection
        }
    }
    
    private var nyutagActionsSection: some View {
        Section {
            ListRow(label: .default(title: NyutagL10n.savedMessages, icon: \.favourite),
                    kind: .button { context.send(viewAction: .nyutagSavedMessages) })
            ListRow(label: .default(title: NyutagL10n.byPhoneTitle, icon: \.mobile),
                    kind: .button { context.send(viewAction: .nyutagFindByPhone) })
                .accessibilityIdentifier("startChat-nyutagFindByPhone")
            ListRow(label: .default(title: NyutagL10n.newGroup, icon: \.plus),
                    kind: .navigationLink { context.send(viewAction: .createRoom) })
                .accessibilityIdentifier(A11yIdentifiers.startChatScreen.createRoom)
            // Нютаг: вместо ссылки matrix.to — одноразовый код приглашения.
            ListRow(label: .default(title: NyutagL10n.inviteFriend, icon: \.userAdd),
                    kind: .button { context.send(viewAction: .nyutagInviteFriend) })
                .accessibilityIdentifier(A11yIdentifiers.startChatScreen.inviteFriends)
            ListRow(label: .default(title: L10n.screenRoomDirectorySearchTitle, icon: \.listBulleted),
                    kind: .navigationLink { context.send(viewAction: .openRoomDirectorySearch) })
        }
    }
    
    /// Нютаг: кто из записной книжки уже здесь. Без разрешения — строка «Найти знакомых из контактов».
    @ViewBuilder
    private var nyutagContactsSection: some View {
        switch context.viewState.nyutagContacts {
        case .needsPermission, .denied:
            Section {
                ListRow(label: .default(title: NyutagL10n.contactsAllow,
                                        description: context.viewState.nyutagContacts == .denied ? NyutagL10n.contactsDenied : NyutagL10n.contactsAllowSubtitle,
                                        icon: \.userAdd),
                        kind: .button { context.send(viewAction: .nyutagSyncContacts) })
                    .accessibilityIdentifier("startChat-nyutagContactsAllow")
            }
        case .syncing(let cached):
            nyutagContactsList(cached, isSyncing: true)
        case .loaded(let contacts):
            nyutagContactsList(contacts, isSyncing: false)
        case .failed:
            Section {
                ListRow(kind: .custom {
                    Text(NyutagL10n.byPhoneError(NyutagInviteError.network))
                        .font(.compound.bodyMD)
                        .foregroundColor(.compound.textSecondary)
                        .padding(.horizontal, ListRowPadding.horizontal)
                        .padding(.vertical, ListRowPadding.vertical)
                })
            } header: {
                Text(NyutagL10n.contactsSection).compoundListSectionHeader()
            }
        }
    }
    
    @ViewBuilder
    private func nyutagContactsList(_ contacts: [NyutagMatchedContact]?, isSyncing: Bool) -> some View {
        Section {
            if let contacts, !contacts.isEmpty {
                ForEach(contacts) { contact in
                    UserProfileListRow(user: contact.profile,
                                       membership: nil,
                                       mediaProvider: context.mediaProvider,
                                       kind: .button { context.send(viewAction: .nyutagOpenContact(contact)) })
                }
            } else {
                ListRow(kind: .custom {
                    HStack(spacing: 12) {
                        if isSyncing {
                            ProgressView()
                        }
                        Text(contacts == nil ? NyutagL10n.contactsSyncing : NyutagL10n.contactsEmpty)
                            .font(.compound.bodyMD)
                            .foregroundColor(.compound.textSecondary)
                    }
                    .padding(.horizontal, ListRowPadding.horizontal)
                    .padding(.vertical, ListRowPadding.vertical)
                })
            }
        } header: {
            Text(NyutagL10n.contactsSection).compoundListSectionHeader()
        }
    }
    
    @ViewBuilder
    private var usersSection: some View {
        if !context.viewState.usersSection.users.isEmpty {
            Section {
                ForEach(context.viewState.usersSection.users, id: \.id) { user in
                    UserProfileListRow(user: user,
                                       membership: nil,
                                       mediaProvider: context.mediaProvider,
                                       kind: .button {
                                           context.send(viewAction: .selectUser(user))
                                       })
                }
            } header: {
                if let title = context.viewState.usersSection.title {
                    Text(title)
                        .compoundListSectionHeader()
                }
            }
        } else {
            Section.empty
        }
    }
    
    private var noResultsContent: some View {
        Text(L10n.commonNoResults)
            .font(.compound.bodyLG)
            .foregroundColor(.compound.textSecondary)
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .accessibilityIdentifier(A11yIdentifiers.startChatScreen.searchNoResults)
    }
    
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(L10n.actionCancel) {
                context.send(viewAction: .close)
            }
            .accessibilityIdentifier(A11yIdentifiers.startChatScreen.closeStartChat)
        }
    }
}

// MARK: - Previews

struct StartChatScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = {
        let appSettings = AppSettings.volatile()
        let userSession = UserSessionMock(.init(clientProxy: ClientProxyMock(.init(userID: "@userid:example.com"))))
        let userDiscoveryService = UserDiscoveryServiceMock()
        userDiscoveryService.searchProfilesWithReturnValue = .success([.mockAlice])
        return StartChatScreenViewModel(userSession: userSession,
                                        analytics: AnalyticsServiceMock(.init()),
                                        userIndicatorController: UserIndicatorControllerMock(),
                                        userDiscoveryService: userDiscoveryService)
    }()
    
    static var previews: some View {
        ElementNavigationStack {
            StartChatScreen(context: viewModel.context)
        }
    }
}
