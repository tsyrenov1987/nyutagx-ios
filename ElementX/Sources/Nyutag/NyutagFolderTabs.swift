//
// Нютаг (форк Element X iOS) — вкладки папок над списком чатов, как в Telegram:
// «Все» и папки пользователя; зажать папку — переименовать или удалить.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

struct NyutagFolderTabs: View {
    let folders: [NyutagChatFolder]
    let selectedFolderID: String?
    let send: (HomeScreenViewAction) -> Void

    @State private var folderPendingDeletion: NyutagChatFolder?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                tab(title: NyutagL10n.folderAll, isSelected: selectedFolderID == nil) {
                    send(.nyutagSelectFolder(folderID: nil))
                }

                ForEach(folders) { folder in
                    tab(title: folder.name, isSelected: selectedFolderID == folder.id) {
                        send(.nyutagSelectFolder(folderID: folder.id))
                    }
                    .contextMenu {
                        Button {
                            send(.nyutagPromptFolder(.rename(folderID: folder.id)))
                        } label: {
                            Label(NyutagL10n.folderRename, icon: \.edit)
                        }

                        Button(role: .destructive) {
                            folderPendingDeletion = folder
                        } label: {
                            Label(NyutagL10n.folderDelete, icon: \.delete)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .confirmationDialog(folderPendingDeletion?.name ?? "",
                            isPresented: Binding(get: { folderPendingDeletion != nil },
                                                 set: { if !$0 { folderPendingDeletion = nil } }),
                            titleVisibility: .visible,
                            presenting: folderPendingDeletion) { folder in
            Button(NyutagL10n.folderDelete, role: .destructive) {
                send(.nyutagDeleteFolder(folderID: folder.id))
            }
        } message: { _ in
            Text(NyutagL10n.folderDeleteHint)
        }
    }

    private func tab(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(isSelected ? .compound.bodyMDSemibold : .compound.bodyMD)
                .foregroundStyle(isSelected ? .compound.textActionAccent : .compound.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Capsule()
                            .fill(.compound.textActionAccent)
                            .frame(height: 3)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Пустая папка: как добавить в неё чат.
struct NyutagFolderEmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text(NyutagL10n.folderEmptyTitle)
                .multilineTextAlignment(.center)
                .font(.compound.headingSMSemibold)
                .foregroundColor(.compound.textPrimary)

            Text(NyutagL10n.folderEmpty)
                .multilineTextAlignment(.center)
                .font(.compound.bodyMD)
                .foregroundColor(.compound.textSecondary)
        }
        .padding(.horizontal, 60)
    }
}
