//
// Нютаг (форк Element X iOS) — автоудаление сообщений в чате, как в Telegram.
// Таймер — state-событие комнаты `chat.nyutag.autodelete` `{"ttl": <секунды>, "since": <мс>}`, формат общий с Android.
// Сервер (E2EE) содержимое не видит, поэтому удаляют клиенты: все прячут истёкшие сообщения, отправитель удаляет свои.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

nonisolated struct NyutagAutoDeleteRule: Equatable {
    static let eventType = "chat.nyutag.autodelete"
    static let day: Int64 = 86400
    static let week: Int64 = 7 * day
    static let month: Int64 = 31 * day
    /// Варианты как в Telegram: выкл, 1 день, 1 неделя, 1 месяц.
    static let options: [Int64] = [0, day, week, month]

    var ttlSeconds: Int64 = 0
    var sinceMs: Int64 = 0

    var isEnabled: Bool {
        ttlSeconds > 0
    }

    init(ttlSeconds: Int64 = 0, sinceMs: Int64 = 0) {
        self.ttlSeconds = max(0, ttlSeconds)
        self.sinceMs = max(0, sinceMs)
    }

    init(json: [String: Any]) {
        self.init(ttlSeconds: (json["ttl"] as? NSNumber)?.int64Value ?? 0,
                  sinceMs: (json["since"] as? NSNumber)?.int64Value ?? 0)
    }

    var json: [String: Any] {
        ["ttl": ttlSeconds, "since": sinceMs]
    }

    /// Сообщения, отправленные до включения таймера, не трогаем — как в Telegram.
    /// Время события на iOS округлено до секунды вниз, поэтому к `since` даётся секунда запаса.
    func isExpired(_ timestamp: Date, now: Date) -> Bool {
        guard isEnabled else { return false }
        let timestampMs = Int64(timestamp.timeIntervalSince1970 * 1000)
        return timestampMs + 999 >= sinceMs && timestampMs + ttlSeconds * 1000 <= Int64(now.timeIntervalSince1970 * 1000)
    }

    /// Нестандартный срок (задан другим клиентом) показывается ближайшим из вариантов Telegram.
    static func label(_ ttlSeconds: Int64) -> String {
        if ttlSeconds <= 0 { return NyutagL10n.autoDeleteOff }
        if ttlSeconds <= day { return NyutagL10n.autoDeleteDay }
        if ttlSeconds <= week { return NyutagL10n.autoDeleteWeek }
        return NyutagL10n.autoDeleteMonth
    }
}

nonisolated enum NyutagAutoDeleteTimeline {
    /// Как в Telegram: удаляются сообщения, служебные события (вход, переименование) остаются.
    static func isMessage(_ item: RoomTimelineItemProtocol) -> Bool {
        item is EventBasedMessageTimelineItemProtocol
            || item is StickerRoomTimelineItem
            || item is PollRoomTimelineItem
            || item is RedactedRoomTimelineItem
            || item is EncryptedRoomTimelineItem
    }

    static func visibleItems(_ items: [RoomTimelineItemProtocol], rule: NyutagAutoDeleteRule, now: Date) -> [RoomTimelineItemProtocol] {
        guard rule.isEnabled else { return items }
        return items.filter { !isExpired($0, rule: rule, now: now) }
    }

    /// Свои отправленные истёкшие сообщения, которые ещё не удалены на сервере.
    static func ownToRedact(_ items: [RoomTimelineItemProtocol], rule: NyutagAutoDeleteRule, now: Date) -> [String] {
        guard rule.isEnabled else { return [] }
        return items.compactMap { item in
            guard let event = item as? EventBasedTimelineItemProtocol,
                  event.isOutgoing,
                  !(item is RedactedRoomTimelineItem),
                  isExpired(item, rule: rule, now: now) else {
                return nil
            }
            return item.id.eventID
        }
    }

    private static func isExpired(_ item: RoomTimelineItemProtocol, rule: NyutagAutoDeleteRule, now: Date) -> Bool {
        guard isMessage(item), let event = item as? EventBasedTimelineItemProtocol else { return false }
        return rule.isExpired(event.timestamp, now: now)
    }
}

/// Загрузка и смена таймера через ядро Нютага.
@MainActor
enum NyutagAutoDeleteService {
    static func load(roomID: String, clientProxy: ClientProxyProtocol) async -> NyutagAutoDeleteRule? {
        guard let accessToken = (clientProxy as? ClientProxy)?.nyutagAccessToken else { return nil }
        do {
            return try await NyutagInvitesService.shared.autoDeleteRule(roomID: roomID, accessToken: accessToken)
        } catch {
            MXLog.warning("Nyutag: failed loading auto-delete rule in \(roomID): \(error.errcode)")
            return nil
        }
    }

    /// `ttlSeconds` = 0 выключает таймер. Действует на сообщения, отправленные с этого момента.
    static func set(roomID: String, ttlSeconds: Int64, clientProxy: ClientProxyProtocol, now: Date = .now) async -> NyutagAutoDeleteRule? {
        guard let accessToken = (clientProxy as? ClientProxy)?.nyutagAccessToken else { return nil }
        let rule = NyutagAutoDeleteRule(ttlSeconds: ttlSeconds, sinceMs: ttlSeconds > 0 ? Int64(now.timeIntervalSince1970 * 1000) : 0)
        do {
            try await NyutagInvitesService.shared.setAutoDeleteRule(rule, roomID: roomID, accessToken: accessToken)
            return rule
        } catch {
            MXLog.error("Nyutag: failed saving auto-delete rule in \(roomID): \(error.errcode)")
            return nil
        }
    }
}
