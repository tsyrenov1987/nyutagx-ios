//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct UserDetailsEditScreen: View {
    @Bindable var context: UserDetailsEditScreenViewModel.Context
    @FocusState private var focus: Bool
    
    var body: some View {
        Form {
            Section {
                avatar
            } footer: {
                Text(context.viewState.currentUserProfile.id)
                    .frame(maxWidth: .infinity)
                    .font(.compound.bodyLG)
                    .foregroundColor(.compound.textPrimary)
                    .padding(.bottom, 16)
            }
            
            nameSection
            
            if context.viewState.nyutagProfileOriginal != nil {
                NyutagProfileFieldsEditor(info: $context.nyutagProfile)
            }
        }
        .compoundList()
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(L10n.screenEditProfileTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(context.viewState.canSave)
        .toolbar { toolbar }
        .alert(item: $context.alertInfo)
    }
    
    // MARK: - Private
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if context.viewState.canSave {
                Button(L10n.actionCancel) {
                    context.send(viewAction: .cancel)
                }
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(L10n.actionSave) {
                context.send(viewAction: .save)
                focus = false
            }
            .disabled(!context.viewState.canSave)
        }
    }
    
    /// Нютаг: тап по картинке открывает аватар во весь экран, карандаш — выбор фото.
    private var canPreviewAvatar: Bool {
        context.viewState.localMedia == nil && context.viewState.selectedAvatarURL != nil
    }
    
    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            Button {
                context.send(viewAction: canPreviewAvatar ? .displayAvatar : .presentMediaSource)
            } label: {
                OverridableAvatarImage(overrideURL: context.viewState.localMedia?.thumbnailURL,
                                       url: context.viewState.selectedAvatarURL,
                                       name: context.viewState.currentUserProfile.displayName,
                                       contentID: context.viewState.currentUserProfile.id,
                                       shape: .circle,
                                       avatarSize: .user(on: .editUserDetails),
                                       mediaProvider: context.mediaProvider)
            }
            .buttonStyle(.borderless)
            .disabled(!context.viewState.canEditAvatar && !canPreviewAvatar)
            .accessibilityLabel(canPreviewAvatar ? L10n.a11yAvatar : L10n.a11yEditAvatar)
            
            if context.viewState.canEditAvatar {
                Button {
                    context.send(viewAction: .presentMediaSource)
                } label: {
                    EditAvatarBadge()
                }
                .buttonStyle(.borderless)
                .scaledOffset(x: 8, y: 0, relativeTo: .title)
                .accessibilityLabel(L10n.a11yEditAvatar)
            }
        }
        .confirmationDialog("", isPresented: $context.showMediaSheet) {
            mediaActionSheet
        }
        .interactiveQuickLook(item: $context.mediaPreviewItem, allowEditing: false)
        .frame(maxWidth: .infinity, alignment: .center)
        .listRowBackground(Color.clear)
    }
    
    private var nameSection: some View {
        Section {
            ListRow(label: .plain(title: L10n.screenEditProfileDisplayNamePlaceholder),
                    kind: .textField(text: $context.name, axis: .horizontal))
                .focused($focus)
                .disabled(!context.viewState.canEditDisplayName)
        } header: {
            Text(L10n.screenEditProfileDisplayName)
                .compoundListSectionHeader()
        }
    }
    
    @ViewBuilder
    private var mediaActionSheet: some View {
        Button {
            context.send(viewAction: .displayCameraPicker)
        } label: {
            Text(L10n.actionTakePhoto)
        }
        
        Button {
            context.send(viewAction: .displayMediaPicker)
        } label: {
            Text(L10n.actionChoosePhoto)
        }
        
        Button {
            context.send(viewAction: .displayFilePicker)
        } label: {
            Text(L10n.actionChooseFile)
        }
        
        if context.viewState.showDeleteImageAction {
            Button(role: .destructive) {
                context.send(viewAction: .removeImage)
            } label: {
                Text(L10n.actionRemove)
            }
        }
    }
}

// MARK: - Previews

struct UserDetailsEditScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = makeViewModel()
    static let readOnlyViewModel = makeViewModel(canChangeProfile: false)
    
    static var previews: some View {
        ElementNavigationStack {
            UserDetailsEditScreen(context: viewModel.context)
        }
        .previewDisplayName("Default")
        
        ElementNavigationStack {
            UserDetailsEditScreen(context: readOnlyViewModel.context)
        }
        .previewDisplayName("Read Only")
    }
    
    static func makeViewModel(canChangeProfile: Bool = true) -> UserDetailsEditScreenViewModel {
        let userSession = UserSessionMock(.init(clientProxy: ClientProxyMock(.init(userID: "@stefan:matrix.org",
                                                                                   displayName: "Stefan",
                                                                                   canChangeAvatar: canChangeProfile,
                                                                                   canChangeDisplayName: canChangeProfile))))
        
        return UserDetailsEditScreenViewModel(userSession: userSession,
                                              mediaUploadingPreprocessor: .init(appSettings: .volatile()),
                                              userIndicatorController: UserIndicatorControllerMock())
    }
}
