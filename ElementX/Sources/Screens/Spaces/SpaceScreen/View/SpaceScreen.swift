//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct SpaceScreen: View {
    @Bindable var context: SpaceScreenViewModel.Context
    
    private var isEditModeActive: Bool {
        context.viewState.editMode != .inactive
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !isEditModeActive {
                    SpaceHeaderView(spaceServiceRoom: context.viewState.space,
                                    mediaProvider: context.mediaProvider)
                        .background(alignment: .top) { NyutagCommunityCover() }
                    
                    NyutagCommunityActions(context: context)
                }
                
                if context.viewState.shouldShowEmptyState {
                    emptyState
                } else if context.viewState.shouldShowMemberEmptyState, !isEditModeActive {
                    NyutagCommunityMemberEmptyState()
                } else {
                    if !isEditModeActive, !context.viewState.rooms.isEmpty {
                        NyutagCommunitySectionHeader(count: context.viewState.rooms.count)
                    }
                    rooms
                }
            }
        }
        .environment(\.editMode, .constant(context.viewState.editMode))
        .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
        .toolbarRole(RoomHeaderView.toolbarRole)
        .navigationTitle(context.viewState.space.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditModeActive)
        .toolbar { toolbar }
        .sheet(isPresented: $context.isPresentingRemoveChildrenConfirmation) {
            SpaceRemoveChildrenConfirmationView(spaceName: context.viewState.space.name) {
                context.send(viewAction: .confirmRemoveSelectedChildren)
            }
        }
        .sheet(item: $context.leaveSpaceViewModel) { leaveSpaceViewModel in
            LeaveSpaceView(context: leaveSpaceViewModel.context)
        }
    }
    
    @ViewBuilder
    var rooms: some View {
        ForEach(context.viewState.visibleRooms, id: \.id) { spaceServiceRoom in
            SpaceRoomCell(spaceServiceRoom: spaceServiceRoom,
                          isSelected: context.viewState.isSpaceIDSelected(spaceServiceRoom.id),
                          isJoining: context.viewState.joiningRoomIDs.contains(spaceServiceRoom.id),
                          mediaProvider: context.mediaProvider) { action in
                context.send(viewAction: .spaceAction(action))
            }
        }
        
        if context.viewState.paginationState == .paginating {
            ProgressView()
                .padding()
        }
    }
    
    var emptyState: some View {
        VStack(spacing: 24) {
            TitleAndIcon(title: L10n.screenSpaceEmptyStateTitle,
                         icon: \.room,
                         iconStyle: .defaultSolid)
                .padding(.horizontal, 24)
            
            VStack(spacing: 16) {
                Button { context.send(viewAction: .addExistingRooms) } label: {
                    Label(L10n.actionAddExistingRooms, icon: \.plus)
                }
                .buttonStyle(.compound(.primary))
                
                Button(L10n.actionCreateRoom) {
                    context.send(viewAction: .createChildRoom)
                }
                .buttonStyle(.compound(.secondary))
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 40)
    }
    
    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        if isEditModeActive {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.actionCancel, role: .cancel) {
                    context.send(viewAction: .finishManagingChildren)
                }
            }
        }
        
        // Use the same trick as the RoomScreen for a leading title view that
        // also hides the navigation title.
        ToolbarItem(placement: .principal) {
            RoomHeaderView(roomName: context.viewState.space.name,
                           roomAvatar: context.viewState.space.avatar,
                           mediaProvider: context.mediaProvider) {
                if context.viewState.isSpaceManagementEnabled,
                   let roomProxy = context.viewState.roomProxy {
                    context.send(viewAction: .spaceSettings(roomProxy: roomProxy))
                }
            }
        }
        
        if isEditModeActive {
            ToolbarItem(placement: .primaryAction) {
                ToolbarButton(role: .destructive(title: L10n.actionRemove)) {
                    context.send(viewAction: .removeSelectedChildren)
                }
                .disabled(context.viewState.editModeSelectedIDs.isEmpty)
            }
        } else {
            // This should really use a ToolbarItemGroup(placement: .secondaryAction), however it
            // was crashing on iOS 26.0 when tapping the ShareLink as the popover presentation
            // controller attempts to anchor itself to the button that is no longer visible.
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if context.viewState.canEditChildren {
                        Section {
                            Button { context.send(viewAction: .createChildRoom) } label: {
                                Label(L10n.actionCreateRoom, icon: \.plus)
                                    .accessibilityIdentifier(A11yIdentifiers.spaceScreen.createRoom)
                            }
                            
                            Button { context.send(viewAction: .addExistingRooms) } label: {
                                Label(L10n.actionAddExistingRooms, icon: \.room)
                            }
                            .accessibilityIdentifier(A11yIdentifiers.spaceScreen.addExistingRooms)
                            
                            if !context.viewState.rooms.isEmpty {
                                Button { context.send(viewAction: .manageChildren) } label: {
                                    Label(L10n.actionManageRooms, icon: \.edit)
                                }
                            }
                        }
                    }
                    
                    Section {
                        if let roomProxy = context.viewState.roomProxy {
                            Button { context.send(viewAction: .displayMembers(roomProxy: roomProxy)) } label: {
                                Label(L10n.screenSpaceMenuActionMembers, icon: \.user)
                            }
                            .accessibilityIdentifier(A11yIdentifiers.spaceScreen.viewMembers)
                        }
                        
                        if let permalink = context.viewState.permalink {
                            ShareLink(item: permalink) {
                                Label(L10n.actionShare, icon: \.shareIos)
                            }
                        }
                        
                        if context.viewState.isSpaceManagementEnabled,
                           let roomProxy = context.viewState.roomProxy {
                            Button { context.send(viewAction: .spaceSettings(roomProxy: roomProxy)) } label: {
                                Label(L10n.commonSettings, icon: \.settings)
                            }
                            .accessibilityIdentifier(A11yIdentifiers.spaceScreen.settings)
                        }
                    }
                    
                    Section {
                        Button(role: .destructive) { context.send(viewAction: .leaveSpace) } label: {
                            Label(L10n.actionLeaveSpace, icon: \.leave)
                        }
                    }
                } label: {
                    // Use an SF Symbol to match what ToolbarItemGroup(placement: .secondaryAction) would give us.
                    Image(systemSymbol: .ellipsis)
                }
                .accessibilityIdentifier(A11yIdentifiers.spaceScreen.moreMenu)
            }
        }
    }
}

// MARK: - Нютаг: страница сообщества

/// Обложка в фирменных цветах за аватаром сообщества (полоса до середины аватара, как во ВКонтакте/Telegram).
private struct NyutagCommunityCover: View {
    var body: some View {
        LinearGradient(colors: [Color(NyutagBrand.blue), Color(NyutagBrand.bluePressed)],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .offset(x: 40, y: 50)
            }
            .frame(height: 64)
            .clipped()
            .accessibilityHidden(true)
    }
}

/// Ряд круглых кнопок под шапкой: пригласить, участники, настройки (админу), выйти.
private struct NyutagCommunityActions: View {
    @Bindable var context: SpaceScreenViewModel.Context
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if let permalink = context.viewState.permalink {
                ShareLink(item: NyutagL10n.communityInviteText(context.viewState.space.name, permalink.absoluteString)) {
                    label(NyutagL10n.communityInvite, icon: \.userAdd)
                }
            }
            
            if let roomProxy = context.viewState.roomProxy {
                Button { context.send(viewAction: .displayMembers(roomProxy: roomProxy)) } label: {
                    label(NyutagL10n.communityMembers, icon: \.user)
                }
                
                if context.viewState.isSpaceManagementEnabled {
                    Button { context.send(viewAction: .spaceSettings(roomProxy: roomProxy)) } label: {
                        label(L10n.commonSettings, icon: \.settings)
                    }
                }
            }
            
            Button { context.send(viewAction: .leaveSpace) } label: {
                label(NyutagL10n.communityLeave, icon: \.leave, isDestructive: true)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.compound.borderDisabled)
                .frame(height: 1 / UIScreen.main.scale)
        }
    }
    
    private func label(_ title: String, icon: KeyPath<CompoundIcons, Image>, isDestructive: Bool = false) -> some View {
        VStack(spacing: 6) {
            CompoundIcon(icon, size: .medium, relativeTo: .compound.bodyLG)
                .foregroundStyle(isDestructive ? .compound.iconCriticalPrimary : .compound.iconAccentPrimary)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.compound.bgSubtleSecondary))
            Text(title)
                .font(.compound.bodySM)
                .foregroundStyle(isDestructive ? .compound.textCriticalPrimary : .compound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

/// «Группы · 3» над списком.
private struct NyutagCommunitySectionHeader: View {
    let count: Int
    
    var body: some View {
        Text("\(NyutagL10n.communityGroups) · \(count)")
            .font(.compound.bodySMSemibold)
            .foregroundStyle(.compound.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Пустое сообщество для обычного участника: без кнопок админа, с понятной подсказкой.
private struct NyutagCommunityMemberEmptyState: View {
    var body: some View {
        TitleAndIcon(title: NyutagL10n.communityEmptyTitle,
                     subtitle: NyutagL10n.communityEmptySubtitle,
                     icon: \.room,
                     iconStyle: .defaultSolid)
            .padding(.horizontal, 24)
            .padding(.top, 40)
    }
}

// MARK: - Previews

@available(iOS 26.0, *)
struct SpaceScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = makeViewModel()
    static let managingViewModel = makeViewModel(isManagingRooms: true)
    static let newSpaceViewModel = makeViewModel(isNewSpace: true)
    
    static var previews: some View {
        ElementNavigationStack {
            SpaceScreen(context: viewModel.context)
        }
        
        ElementNavigationStack {
            SpaceScreen(context: managingViewModel.context)
        }
        .previewDisplayName("Managing")
        
        ElementNavigationStack {
            SpaceScreen(context: newSpaceViewModel.context)
        }
        .previewDisplayName("New Space")
        .snapshotPreferences(expect: newSpaceViewModel.context.observe(\.viewState.canEditChildren))
    }
    
    static func makeViewModel(isManagingRooms: Bool = false, isNewSpace: Bool = false) -> SpaceScreenViewModel {
        let spaceServiceRoom = SpaceServiceRoom.mock(id: "!eng-space:matrix.org",
                                                     name: "Engineering Team",
                                                     isSpace: true,
                                                     childrenCount: 30,
                                                     joinedMembersCount: 76,
                                                     heroes: [.mockDan, .mockBob, .mockCharlie, .mockVerbose],
                                                     topic: "Description of the space goes right here. Lorem ipsum dolor sit amet consectetur. Leo viverra morbi habitant in.",
                                                     canonicalAlias: "#engineering-team:element.io",
                                                     joinRule: .knockRestricted(rules: [.roomMembership(roomID: "")]))
        let spaceRoomListProxy = SpaceRoomListProxyMock(.init(spaceServiceRoom: spaceServiceRoom,
                                                              initialSpaceRooms: isNewSpace ? [] : .mockSpaceList))
        
        let clientProxy = ClientProxyMock(.init())
        clientProxy.roomForIdentifierClosure = { _ in
            .joined(JoinedRoomProxyMock(.init(members: .allMembersAsAdmin)))
        }
        let userSession = UserSessionMock(.init(clientProxy: clientProxy))
        
        let viewModel = SpaceScreenViewModel(spaceRoomListProxy: spaceRoomListProxy,
                                             spaceServiceProxy: SpaceServiceProxyMock(.init()),
                                             selectedSpaceRoomPublisher: .init(nil),
                                             userSession: userSession,
                                             userIndicatorController: UserIndicatorControllerMock())
        
        if isManagingRooms {
            viewModel.state.editMode = .transient
            viewModel.state.editModeSelectedIDs = [viewModel.state.visibleRooms[0].id]
        }
        
        return viewModel
    }
}
