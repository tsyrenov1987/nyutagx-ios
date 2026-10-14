//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

struct APSAlert: Encodable {
    let locKey: String
    let locArgs: [String]
    
    enum CodingKeys: String, CodingKey {
        case locKey = "loc-key"
        case locArgs = "loc-args"
    }
}

struct APSInfo: Encodable {
    /// Нютаг: `nil` — расширение уведомлений не запускается (у него нет туннеля до сервера), текст собирает шлюз.
    var mutableContent: Int?
    let alert: APSAlert
    /// Нютаг: звук уведомления.
    var sound: String?
    
    enum CodingKeys: String, CodingKey {
        case mutableContent = "mutable-content"
        case alert
        case sound
    }
}

struct APNSPayload: Encodable {
    let aps: APSInfo
    let pusherNotificationClientIdentifier: String?
    /// Нютаг: чей аккаунт — для перехода в чат по нажатию (раньше это дописывало расширение уведомлений).
    var receiverID: String?
    
    enum CodingKeys: String, CodingKey {
        case aps
        case pusherNotificationClientIdentifier = "pusher_notification_client_identifier"
        case receiverID = "receiver_id"
    }
}
