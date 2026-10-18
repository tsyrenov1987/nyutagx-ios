//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct HomeScreenRoomList: View {
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    
    @ObservedObject var context: HomeScreenViewModel.Context
    
    var body: some View {
        // Hide the room list when the search bar is focused but the query is empty
        // This works hand in hand with the room list service layer filtering and
        // avoids glitches when focusing the search bar
        if !context.viewState.shouldHideRoomList {
            content
        }
    }
    
    private var content: some View {
        ForEach(context.viewState.visibleRooms) { room in
            switch room.type {
            case .placeholder:
                HomeScreenRoomCell(room: room, isSelected: false, mediaProvider: context.mediaProvider, action: context.send)
                    .redacted(reason: .placeholder)
            case .invite:
                HomeScreenInviteCell(room: room, context: context, hideInviteAvatars: context.viewState.hideInviteAvatars)
            case .knock:
                HomeScreenKnockedCell(room: room, context: context)
            case .room:
                let isSelected = context.viewState.selectedRoomID == room.id
                
                HomeScreenRoomCell(room: room,
                                   roomListActivityVisibility: context.viewState.roomListActivityVisibility,
                                   roomListNotificationCountEnabled: context.viewState.roomListNotificationCountEnabled,
                                   isSelected: isSelected,
                                   mediaProvider: context.mediaProvider,
                                   action: context.send)
                    .simultaneousGesture(TapGesture(count: 2).onEnded {
                        context.send(viewAction: .detachRoom(roomIdentifier: room.id))
                    })
                    .contextMenu {
                        if room.badges.isDotShown {
                            Button {
                                context.send(viewAction: .markRoomAsRead(roomIdentifier: room.id))
                            } label: {
                                Label(L10n.screenRoomlistMarkAsRead, icon: \.markAsRead)
                            }
                        } else {
                            Button {
                                context.send(viewAction: .markRoomAsUnread(roomIdentifier: room.id))
                            } label: {
                                Label(L10n.screenRoomlistMarkAsUnread, icon: \.markAsUnread)
                            }
                        }
                        
                        if supportsMultipleWindows {
                            Button {
                                context.send(viewAction: .detachRoom(roomIdentifier: room.id))
                            } label: {
                                Label("Open in new window", icon: \.spotlight)
                            }
                        }
                        
                        if room.isFavourite {
                            Button {
                                context.send(viewAction: .markRoomAsFavourite(roomIdentifier: room.id, isFavourite: false))
                            } label: {
                                Label(L10n.commonFavourited, icon: \.favouriteSolid)
                            }
                        } else {
                            Button {
                                context.send(viewAction: .markRoomAsFavourite(roomIdentifier: room.id, isFavourite: true))
                            } label: {
                                Label(L10n.commonFavourite, icon: \.favourite)
                            }
                        }
                        
                        nyutagLayoutMenu(room: room)
                        
                        Button {
                            context.send(viewAction: .showRoomDetails(roomIdentifier: room.id))
                        } label: {
                            Label(L10n.commonSettings, icon: \.settings)
                        }
                        
                        if context.viewState.reportRoomEnabled {
                            Button(role: .destructive) {
                                context.send(viewAction: .reportRoom(roomIdentifier: room.id))
                            } label: {
                                Label(L10n.actionReportRoom, icon: \.chatProblem)
                            }
                        }
                        
                        Button(role: .destructive) {
                            context.send(viewAction: .leaveRoom(roomIdentifier: room.id))
                        } label: {
                            Label(L10n.actionLeaveRoom, icon: \.leave)
                        }
                    }
            }
        }
    }
    
    /// Нютаг: закрепить наверху (до 5) и разложить по папкам, как в Telegram.
    @ViewBuilder
    private func nyutagLayoutMenu(room: HomeScreenRoom) -> some View {
        Button {
            context.send(viewAction: .nyutagSetPinned(roomIdentifier: room.id, isPinned: !room.isNyutagPinned))
        } label: {
            if room.isNyutagPinned {
                Label(L10n.actionUnpin, icon: \.unpin)
            } else {
                Label(L10n.actionPin, icon: \.pin)
            }
        }
        
        Menu {
            ForEach(context.viewState.nyutagChatLayout.folders) { folder in
                let isIn = folder.rooms.contains(room.id)
                Toggle(folder.name, isOn: Binding(get: { isIn },
                                                  set: { context.send(viewAction: .nyutagSetRoomInFolder(roomIdentifier: room.id, folderID: folder.id, isIn: $0)) }))
            }
            
            Button {
                context.send(viewAction: .nyutagPromptFolder(.create(roomID: room.id)))
            } label: {
                Label(NyutagL10n.folderNew, icon: \.plus)
            }
        } label: {
            Label(NyutagL10n.folderAdd, icon: \.folder)
        }
    }
}
