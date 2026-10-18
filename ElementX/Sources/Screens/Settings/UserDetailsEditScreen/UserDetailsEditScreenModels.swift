//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum UserDetailsEditScreenViewModelAction {
    case dismiss
    case displayCameraPicker
    case displayMediaPicker
    case displayFilePicker
}

struct UserDetailsEditScreenViewState: BindableState {
    var currentUserProfile: UserProfile
    
    var canEditAvatar = true
    var canEditDisplayName = true
    
    var selectedAvatarURL: URL?
    var localMedia: MediaInfo?
    
    /// Нютаг: «о себе» как на сервере; nil — ещё не загружено (поля не показываем и не сохраняем).
    var nyutagProfileOriginal: NyutagProfileInfo?
    
    var bindings: UserDetailsEditScreenViewStateBindings
    
    var nameDidChange: Bool {
        bindings.name != currentUserProfile.displayName
    }
    
    var avatarDidChange: Bool {
        localMedia != nil || selectedAvatarURL != currentUserProfile.avatarURL
    }
    
    var nyutagProfileDidChange: Bool {
        guard let nyutagProfileOriginal else { return false }
        return bindings.nyutagProfile.normalized != nyutagProfileOriginal.normalized
    }
    
    var canSave: Bool {
        !bindings.name.isEmpty && (avatarDidChange || nameDidChange || nyutagProfileDidChange)
    }
    
    var showDeleteImageAction: Bool {
        localMedia != nil || selectedAvatarURL != nil
    }
}

struct UserDetailsEditScreenViewStateBindings {
    var name = ""
    var nyutagProfile = NyutagProfileInfo()
    var showMediaSheet = false
    /// Нютаг: просмотр своего аватара во весь экран.
    var mediaPreviewItem: MediaPreviewItem?
    
    var alertInfo: AlertInfo<UserDetailsEditScreenAlertType>?
}

enum UserDetailsEditScreenAlertType {
    case failedProcessingMedia
    case unsavedChanges
    case saveError
    case unknown
}

enum UserDetailsEditScreenViewAction {
    case cancel
    case save
    case presentMediaSource
    case displayAvatar
    case displayCameraPicker
    case displayMediaPicker
    case displayFilePicker
    case removeImage
}
