//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct SpacesScreen: View {
    @Bindable var context: SpacesScreenViewModel.Context
    
    var body: some View {
        mainContent
            .navigationTitle(L10n.screenSpaceListTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .toolbarRole(Compound.supportsGlass ? .editor : .automatic)
            .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
            .toolbarBloom(hasSearchBar: false)
    }
    
    // Нютаг: как «Сообщества» во «ВКонтакте» — поиск, свои сообщества и каталог всех сообществ сервера.
    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !context.viewState.visibleSpaces.isEmpty {
                    sectionHeader(NyutagL10n.communitiesMine)
                    spaces
                }
                
                if !context.viewState.catalog.isEmpty {
                    sectionHeader(NyutagL10n.communitiesAll)
                    ForEach(context.viewState.catalog) { community in
                        NyutagCommunityCell(community: community, mediaProvider: context.mediaProvider) {
                            context.send(viewAction: .openCommunity(community))
                        }
                    }
                }
                
                if context.viewState.visibleSpaces.isEmpty, context.viewState.catalog.isEmpty {
                    emptyState
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .searchable(text: $context.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: NyutagL10n.communitiesSearch)
        .onChange(of: context.searchQuery) { context.send(viewAction: .searchQueryChanged) }
        .refreshable { context.send(viewAction: .refreshCommunities) }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.compound.bodySMSemibold)
            .foregroundStyle(.compound.textSecondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }
    
    @ViewBuilder
    private var emptyState: some View {
        if context.viewState.isLoadingCommunities, !context.viewState.hasLoadedCommunities {
            ProgressView()
                .padding(.top, 64)
        } else if context.viewState.isSearching {
            Text(L10n.commonNoResults)
                .font(.compound.bodyLG)
                .foregroundStyle(.compound.textSecondary)
                .padding(.top, 64)
        } else {
            VStack(spacing: 0) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color(NyutagBrand.blue))
                    .frame(width: 96, height: 96)
                    .background(Color(NyutagBrand.blueSubtle), in: Circle())
                    .padding(.bottom, 20)
                    .accessibilityHidden(true)
                
                Text(NyutagL10n.communitiesEmpty)
                    .font(.compound.bodyLG)
                    .foregroundStyle(.compound.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
                
                Button(L10n.actionCreateSpace) {
                    context.send(viewAction: .createSpace)
                }
                .buttonStyle(.compound(.primary))
                .frame(maxWidth: 320)
            }
            .padding(.horizontal, 32)
            .padding(.top, 64)
        }
    }
    
    private var spaces: some View {
        ForEach(context.viewState.visibleSpaces, id: \.id) { spaceServiceRoom in
            SpaceRoomCell(spaceServiceRoom: spaceServiceRoom,
                          isSelected: spaceServiceRoom.id == context.viewState.selectedSpaceID,
                          mediaProvider: context.mediaProvider) { action in
                context.send(viewAction: .spaceAction(action))
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // Use the title placement on iOS 26 to match the chats tab and fix a weird animation.
        ToolbarItem(placement: Compound.supportsGlass ? .title : .navigationBarLeading) {
            Button {
                context.send(viewAction: .showSettings)
            } label: {
                AvatarSettingsButtonLabel(userProfile: context.viewState.userProfile,
                                          mediaProvider: context.mediaProvider)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(L10n.commonSettings)
            .accessibilityIdentifier(A11yIdentifiers.homeScreen.userAvatar)
        }
        .backportSharedBackgroundVisibility(.hidden)
        
        // No need to hide the title on iOS 26, as we use the .title placement for the settings
        // button to workaround a weird liquid glass transition.
        if #unavailable(iOS 26) {
            ToolbarItem(placement: .principal) {
                // Hides the navigationTitle (which is set for the navigation stack label).
                Text("").accessibilityHidden(true)
            }
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button {
                context.send(viewAction: .createSpace)
            } label: {
                CompoundIcon(\.plus)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel(L10n.actionCreateSpace)
        }
    }
}

// MARK: - Previews

struct SpacesScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = makeViewModel()
    static let emptyViewModel = makeViewModel(isEmpty: true)
    
    static var previews: some View {
        ElementNavigationStack {
            SpacesScreen(context: viewModel.context)
        }
        
        ElementNavigationStack {
            SpacesScreen(context: emptyViewModel.context)
        }
        .previewDisplayName("Empty")
    }
    
    static func makeViewModel(isEmpty: Bool = false) -> SpacesScreenViewModel {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.spaceService = SpaceServiceProxyMock(.init(topLevelSpaces: isEmpty ? [] : .mockJoinedSpaces))
        
        return SpacesScreenViewModel(userSession: UserSessionMock(.init(clientProxy: clientProxy)),
                                     selectedSpacePublisher: .init(nil),
                                     userIndicatorController: UserIndicatorControllerMock())
    }
}

/// Нютаг: сообщество из каталога — аватар, название, открытое/закрытое и число участников.
private struct NyutagCommunityCell: View {
    let community: NyutagCommunity
    let mediaProvider: MediaProviderProtocol?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                LoadableAvatarImage(url: community.avatarURL,
                                    name: community.name,
                                    contentID: community.id,
                                    shape: .roundedRect,
                                    avatarSize: .room(on: .spaces),
                                    mediaProvider: mediaProvider)
                    .accessibilityHidden(true)
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(community.name)
                            .font(.compound.bodyLGSemibold)
                            .foregroundStyle(.compound.textPrimary)
                            .lineLimit(1)
                        
                        Label {
                            Text(community.isOpen ? NyutagL10n.communityOpen : NyutagL10n.communityClosedBadge)
                                .font(.compound.bodyMD)
                                .foregroundStyle(.compound.textSecondary)
                                .lineLimit(1)
                        } icon: {
                            CompoundIcon(community.isOpen ? \.public : \.lockSolid, size: .xSmall, relativeTo: .compound.bodyMD)
                                .foregroundStyle(.compound.iconTertiary)
                        }
                        .labelStyle(.custom(spacing: 4))
                        
                        Text(L10n.commonMemberCount(community.membersCount))
                            .font(.compound.bodyMD)
                            .foregroundStyle(.compound.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    CompoundIcon(\.chevronRight, size: .small, relativeTo: .compound.bodyLG)
                        .foregroundStyle(.compound.iconTertiary)
                }
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.compound.borderDisabled)
                        .frame(height: 1 / UIScreen.main.scale)
                        .padding(.trailing, -16)
                }
            }
            .padding(.horizontal, 16)
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(SpaceRoomCellButtonStyle(isHighlighted: false))
    }
}
