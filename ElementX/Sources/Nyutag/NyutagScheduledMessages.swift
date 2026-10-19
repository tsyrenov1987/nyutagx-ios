//
// Нютаг (форк Element X iOS) — отложенные сообщения, как в Telegram.
// Сервер Matrix отложенную отправку не умеет, поэтому очередь хранится на телефоне (формат как на Android),
// а отправляет её `NyutagScheduledSender`, пока приложение открыто или iOS разбудила его в фоне (background app refresh);
// не разбудила — через 2 минуты после срока местное напоминание открыть Нютаг (`NyutagScheduledReminders`).
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import SwiftUI
import UserNotifications

nonisolated struct NyutagScheduledMessage: Codable, Equatable, Identifiable {
    /// Упоминание всего чата в `mentions`.
    static let roomMention = "@room"

    let id: String
    let sessionId: String
    let roomId: String
    let body: String
    var html: String?
    /// ID упомянутых пользователей и `roomMention`.
    var mentions: [String] = []
    var sendAtMs: Int64

    init(id: String = UUID().uuidString, sessionID: String, roomID: String, body: String, html: String?, intentionalMentions: IntentionalMentions, sendAt: Date) {
        self.id = id
        sessionId = sessionID
        roomId = roomID
        self.body = body
        self.html = html
        mentions = intentionalMentions.userIDs.sorted() + (intentionalMentions.atRoom ? [Self.roomMention] : [])
        sendAtMs = Int64(sendAt.timeIntervalSince1970 * 1000)
    }

    /// Android не пишет пустые поля, поэтому необязательные ключи читаются с запасом.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        roomId = try container.decode(String.self, forKey: .roomId)
        body = try container.decode(String.self, forKey: .body)
        html = try container.decodeIfPresent(String.self, forKey: .html)
        mentions = try container.decodeIfPresent([String].self, forKey: .mentions) ?? []
        sendAtMs = try container.decode(Int64.self, forKey: .sendAtMs)
    }

    var sendAt: Date {
        Date(timeIntervalSince1970: Double(sendAtMs) / 1000)
    }

    var intentionalMentions: IntentionalMentions {
        .init(userIDs: Set(mentions.filter { $0 != Self.roomMention }), atRoom: mentions.contains(Self.roomMention))
    }

    func isIn(sessionID: String, roomID: String) -> Bool {
        sessionId == sessionID && roomId == roomID
    }

    static func encode(_ messages: [NyutagScheduledMessage]) -> Data? {
        try? JSONEncoder().encode(messages)
    }

    /// Битые данные очередь не роняют — просто пусто.
    static func decode(_ data: Data?) -> [NyutagScheduledMessage] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([NyutagScheduledMessage].self, from: data)) ?? []
    }
}

/// Очередь в UserDefaults, общая для всех чатов и аккаунтов на телефоне.
final class NyutagScheduledMessages {
    static let shared = NyutagScheduledMessages()

    private static let key = "nyutag_scheduled_messages"

    private let defaults: UserDefaults
    private let subject: CurrentValueSubject<[NyutagScheduledMessage], Never>

    var all: [NyutagScheduledMessage] {
        subject.value
    }

    var changes: AnyPublisher<[NyutagScheduledMessage], Never> {
        subject.eraseToAnyPublisher()
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        subject = .init(NyutagScheduledMessage.decode(defaults.data(forKey: Self.key)))
    }

    /// Очередь чата, ближайшие первыми.
    func messages(sessionID: String, roomID: String) -> AnyPublisher<[NyutagScheduledMessage], Never> {
        subject
            .map { $0.filter { $0.isIn(sessionID: sessionID, roomID: roomID) }.sorted { $0.sendAtMs < $1.sendAtMs } }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    func due(sessionID: String, now: Date) -> [NyutagScheduledMessage] {
        let nowMs = Int64(now.timeIntervalSince1970 * 1000)
        return all.filter { $0.sessionId == sessionID && $0.sendAtMs <= nowMs }.sorted { $0.sendAtMs < $1.sendAtMs }
    }

    func schedule(_ message: NyutagScheduledMessage) {
        update { $0.filter { $0.id != message.id } + [message] }
    }

    func sendNow(id: String, now: Date = .now) {
        update { messages in
            messages.map { message in
                guard message.id == id else { return message }
                var updated = message
                updated.sendAtMs = min(message.sendAtMs, Int64(now.timeIntervalSince1970 * 1000))
                return updated
            }
        }
    }

    func delete(id: String) {
        update { $0.filter { $0.id != id } }
    }

    private func update(_ transform: ([NyutagScheduledMessage]) -> [NyutagScheduledMessage]) {
        let updated = transform(subject.value)
        defaults.set(NyutagScheduledMessage.encode(updated), forKey: Self.key)
        subject.send(updated)
    }
}

extension Notification.Name {
    /// iOS разбудила приложение в фоне и сервисы клиента запущены — пора отправить наступившее.
    static let nyutagScheduledSendDue = Notification.Name("NyutagScheduledSendDue")
}

/// Отправляет наступившие сообщения своей сессии: раз в 15 секунд, при возврате в приложение, при фоновом
/// пробуждении и по «Отправить сейчас».
final class NyutagScheduledSender {
    private let clientProxy: ClientProxyProtocol
    private let store: NyutagScheduledMessages
    private var sendingIDs = Set<String>()
    private var timerTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(clientProxy: ClientProxyProtocol, store: NyutagScheduledMessages = .shared, notificationCenter: NotificationCenter = .default) {
        self.clientProxy = clientProxy
        self.store = store

        store.changes
            .sink { [weak self] _ in Task { await self?.sendDue() } }
            .store(in: &cancellables)
        notificationCenter.publisher(for: UIApplication.didBecomeActiveNotification)
            .merge(with: notificationCenter.publisher(for: .nyutagScheduledSendDue))
            .sink { [weak self] _ in Task { await self?.sendDue() } }
            .store(in: &cancellables)
        timerTask = Task { [weak self] in
            // Сон без ссылки на себя: сессия закрылась — цикл завершается.
            while await self?.sendDue() != nil {
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    isolated deinit {
        timerTask?.cancel()
    }

    func sendDue(now: Date = .now) async {
        for message in store.due(sessionID: clientProxy.userID, now: now) where !sendingIDs.contains(message.id) {
            sendingIDs.insert(message.id)
            await send(message)
            sendingIDs.remove(message.id)
        }
    }

    private func send(_ message: NyutagScheduledMessage) async {
        switch await clientProxy.roomForIdentifier(message.roomId) {
        case .joined(let roomProxy):
            switch await roomProxy.timeline.sendMessage(message.body,
                                                        html: message.html,
                                                        inReplyToEventID: nil,
                                                        intentionalMentions: message.intentionalMentions) {
            case .success:
                // Дальше сообщение в очереди отправки SDK, она переживает перезапуск.
                store.delete(id: message.id)
            case .failure(let error):
                MXLog.warning("Nyutag scheduled: send failed in \(message.roomId): \(error)")
            }
        case .none:
            // Список чатов ещё не загрузился — попробуем в следующий раз.
            break
        default:
            MXLog.warning("Nyutag scheduled: room \(message.roomId) is not joined, dropping")
            store.delete(id: message.id)
        }
    }
}

/// Местные напоминания: по одному на сообщение, через 2 минуты после срока. Ушло сообщение или удалено — напоминание снимается.
final class NyutagScheduledReminders {
    static let identifierPrefix = "nyutag-scheduled-"
    static let delay: TimeInterval = 120

    private let center: UNUserNotificationCenter
    private var cancellable: AnyCancellable?

    init(store: NyutagScheduledMessages = .shared, center: UNUserNotificationCenter = .current()) {
        self.center = center
        cancellable = store.changes
            .removeDuplicates()
            .sink { [weak self] messages in Task { await self?.sync(messages) } }
    }

    static func identifier(_ message: NyutagScheduledMessage) -> String {
        identifierPrefix + message.id
    }

    static func request(for message: NyutagScheduledMessage, now: Date = .now) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = NyutagL10n.scheduleReminderTitle
        content.body = NyutagL10n.scheduleReminderBody(String(message.body.prefix(80)))
        content.sound = .default
        // Нажатие открывает чат, как обычное уведомление.
        content.receiverID = message.sessionId
        content.roomID = message.roomId
        let fireIn = max(message.sendAt.addingTimeInterval(delay).timeIntervalSince(now), 1)
        return UNNotificationRequest(identifier: identifier(message), content: content,
                                     trigger: UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false))
    }

    private func sync(_ messages: [NyutagScheduledMessage]) async {
        let wanted = Set(messages.map(Self.identifier))
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
        let delivered = await center.deliveredNotifications().map(\.request.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { !wanted.contains($0) })
        center.removeDeliveredNotifications(withIdentifiers: delivered.filter { !wanted.contains($0) })
        for message in messages where !pending.contains(Self.identifier(message)) && !delivered.contains(Self.identifier(message)) {
            do {
                try await center.add(Self.request(for: message))
            } catch {
                MXLog.warning("Nyutag scheduled: reminder not added: \(error)")
            }
        }
    }
}
