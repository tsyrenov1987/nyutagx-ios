//
// Нютаг (форк Element X iOS) — вкладка «Контакты».
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

struct NyutagContactsScreen: View {
    @Bindable var context: NyutagContactsScreenViewModel.Context
    
    var body: some View {
        Form {
            inNyutagSection
            othersSection
        }
        .compoundList()
        .navigationTitle(NyutagL10n.tabContacts)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { context.send(viewAction: .load(requestPermission: false)) }
        .onAppear { context.send(viewAction: .load(requestPermission: false)) }
    }
    
    @ViewBuilder
    private var inNyutagSection: some View {
        switch context.viewState.inNyutag {
        case .needsPermission, .denied:
            Section {
                ListRow(label: .default(title: NyutagL10n.contactsAllow,
                                        description: context.viewState.inNyutag == .denied ? NyutagL10n.contactsDenied : NyutagL10n.contactsAllowSubtitle,
                                        icon: \.userAdd),
                        kind: .button { context.send(viewAction: .load(requestPermission: true)) })
                    .accessibilityIdentifier("nyutagContacts-allow")
            }
        case .syncing(let cached):
            inNyutagList(cached, isSyncing: true)
        case .loaded(let contacts):
            inNyutagList(contacts, isSyncing: false)
        case .failed:
            Section {
                note(NyutagL10n.byPhoneError(NyutagInviteError.network), isSyncing: false)
            } header: {
                Text(NyutagL10n.contactsOnNyutag).compoundListSectionHeader()
            }
        }
    }
    
    private func inNyutagList(_ contacts: [NyutagMatchedContact]?, isSyncing: Bool) -> some View {
        Section {
            if let contacts, !contacts.isEmpty {
                ForEach(contacts) { contact in
                    UserProfileListRow(user: contact.profile,
                                       membership: nil,
                                       mediaProvider: context.mediaProvider,
                                       kind: .button { context.send(viewAction: .openContact(contact)) })
                }
            } else {
                note(contacts == nil ? NyutagL10n.contactsSyncing : NyutagL10n.contactsEmpty, isSyncing: isSyncing)
            }
        } header: {
            Text(NyutagL10n.contactsOnNyutag).compoundListSectionHeader()
        }
    }
    
    @ViewBuilder
    private var othersSection: some View {
        if !context.viewState.others.isEmpty {
            Section {
                ForEach(context.viewState.others, id: \.phone) { contact in
                    ListRow(label: .avatar(title: contact.name.isEmpty ? contact.phone : contact.name,
                                           description: contact.name.isEmpty ? nil : contact.phone,
                                           icon: LoadableAvatarImage(url: nil,
                                                                     name: contact.name.isEmpty ? nil : contact.name,
                                                                     contentID: contact.phone,
                                                                     avatarSize: .user(on: .startChat),
                                                                     mediaProvider: nil)),
                            details: .icon(\.userAdd),
                            kind: .button { context.send(viewAction: .invite) })
                }
            } header: {
                Text(NyutagL10n.contactsInviteSection).compoundListSectionHeader()
            }
        }
    }
    
    private func note(_ text: String, isSyncing: Bool) -> some View {
        ListRow(kind: .custom {
            HStack(spacing: 12) {
                if isSyncing {
                    ProgressView()
                }
                Text(text)
                    .font(.compound.bodyMD)
                    .foregroundColor(.compound.textSecondary)
            }
            .padding(.horizontal, ListRowPadding.horizontal)
            .padding(.vertical, ListRowPadding.vertical)
        })
    }
}

// MARK: - Previews

struct NyutagContactsScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = makeViewModel()
    
    static var previews: some View {
        ElementNavigationStack {
            NyutagContactsScreen(context: viewModel.context)
        }
    }
    
    static func makeViewModel() -> NyutagContactsScreenViewModel {
        let viewModel = NyutagContactsScreenViewModel(clientProxy: ClientProxyMock(.init(userID: "@alice:example.com")),
                                                      mediaProvider: MediaProviderMock(.init()),
                                                      userIndicatorController: UserIndicatorControllerMock())
        viewModel.state.inNyutag = .loaded([.init(name: "Аюна", phone: "+79990000001", userID: "@ayuna:nyutag.chat", displayName: "Аюна", avatarURL: nil)])
        viewModel.state.others = [.init(name: "Сэсэг", phone: "+79990000002")]
        return viewModel
    }
}
