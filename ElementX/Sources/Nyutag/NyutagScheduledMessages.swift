//
// Нютаг (форк Element X iOS) — отложенные сообщения, как в Telegram.
// Сервер Matrix отложенную отправку не умеет, поэтому очередь хранится на телефоне (формат как на Android),
// а отправляет её `NyutagScheduledSender`, пока приложение открыто; пропущенное время — при следующем открытии.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import SwiftUI

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

/// Отправляет наступившие сообщения своей сессии: раз в 15 секунд, при возврате в приложение и по «Отправить сейчас».
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
