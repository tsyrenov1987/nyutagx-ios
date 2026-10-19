//
// Нютаг (форк Element X iOS) — тесты отложенных сообщений.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

@testable import ElementX
import Foundation
import Testing
import UserNotifications
import WysiwygComposer

struct NyutagScheduledMessagesTests {
    private let store = NyutagScheduledMessages(defaults: UserDefaults(suiteName: UUID().uuidString) ?? .standard)
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    @Test
    func decodesAndroidJSONWithoutOptionalFields() throws {
        let json = #"[{"id":"a","sessionId":"@me:x","roomId":"!r:x","body":"Привет","sendAtMs":1700000000123},"#
            + #"{"id":"b","sessionId":"@me:x","roomId":"!r:x","body":"Всем","html":"<b>Всем</b>","mentions":["@alice:x","@room"],"sendAtMs":5}]"#
        let messages = NyutagScheduledMessage.decode(Data(json.utf8))

        #expect(messages.map(\.id) == ["a", "b"])
        #expect(messages[0].html == nil)
        #expect(messages[0].mentions.isEmpty)
        #expect(messages[0].sendAtMs == 1_700_000_000_123)
        #expect(messages[1].intentionalMentions == IntentionalMentions(userIDs: ["@alice:x"], atRoom: true))
        #expect(NyutagScheduledMessage.decode(Data("not json".utf8)).isEmpty)
        #expect(NyutagScheduledMessage.decode(NyutagScheduledMessage.encode(messages)) == messages)
    }

    @Test
    func storeKeepsQueuePerSessionAndRoomAndSurvivesReload() throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let store = NyutagScheduledMessages(defaults: defaults)
        let later = makeMessage(id: "later", sendAt: now.addingTimeInterval(120))
        let soon = makeMessage(id: "soon", sendAt: now.addingTimeInterval(60))
        let otherRoom = makeMessage(id: "other", roomID: "!other:x", sendAt: now.addingTimeInterval(30))
        let otherSession = makeMessage(id: "alien", sessionID: "@bob:x", sendAt: now.addingTimeInterval(-30))
        [later, soon, otherRoom, otherSession].forEach(store.schedule)

        var roomQueue: [NyutagScheduledMessage] = []
        let cancellable = store.messages(sessionID: "@me:x", roomID: "!r:x").sink { roomQueue = $0 }
        #expect(roomQueue.map(\.id) == ["soon", "later"])
        #expect(store.due(sessionID: "@me:x", now: now.addingTimeInterval(90)).map(\.id) == ["other", "soon"])

        store.sendNow(id: "later", now: now)
        #expect(store.due(sessionID: "@me:x", now: now).map(\.id) == ["later"])
        store.delete(id: "soon")
        #expect(roomQueue.map(\.id) == ["later"])
        #expect(NyutagScheduledMessages(defaults: defaults).all.map(\.id).sorted() == ["alien", "later", "other"])
        cancellable.cancel()
    }

    @Test
    func senderSendsOnlyDueMessagesOfItsSessionAndDropsThemFromQueue() async {
        // Время в будущем: таймер отправителя живёт по настоящим часам и эти сообщения не трогает.
        let future = Date.now.addingTimeInterval(3600)
        let roomProxy = JoinedRoomProxyMock(.init(id: "!r:x"))
        let clientProxy = ClientProxyMock(.init(userID: "@me:x"))
        clientProxy.roomForIdentifierClosure = { _ in .joined(roomProxy) }
        store.schedule(makeMessage(id: "due", sendAt: future, mentions: .init(userIDs: ["@alice:x"], atRoom: false)))
        store.schedule(makeMessage(id: "notYet", sendAt: future.addingTimeInterval(3600)))
        store.schedule(makeMessage(id: "alien", sessionID: "@bob:x", sendAt: future))
        let sender = NyutagScheduledSender(clientProxy: clientProxy, store: store)

        await sender.sendDue(now: future.addingTimeInterval(1))

        let timeline = roomProxy.timeline as? TimelineProxyMock
        #expect(timeline?.sendMessageHtmlInReplyToEventIDIntentionalMentionsCallsCount == 1)
        #expect(timeline?.sendMessageHtmlInReplyToEventIDIntentionalMentionsReceivedArguments?.message == "Привет")
        #expect(timeline?.sendMessageHtmlInReplyToEventIDIntentionalMentionsReceivedArguments?.intentionalMentions.userIDs == ["@alice:x"])
        #expect(store.all.map(\.id).sorted() == ["alien", "notYet"])
    }

    @Test
    func senderDropsMessagesForLeftRoomsAndKeepsThemWhileRoomsAreLoading() async {
        let future = Date.now.addingTimeInterval(3600)
        let clientProxy = ClientProxyMock(.init(userID: "@me:x"))
        clientProxy.roomForIdentifierClosure = { _ in nil }
        store.schedule(makeMessage(id: "due", sendAt: future))
        let sender = NyutagScheduledSender(clientProxy: clientProxy, store: store)

        await sender.sendDue(now: future)
        #expect(store.all.map(\.id) == ["due"])

        clientProxy.roomForIdentifierClosure = { _ in .left }
        await sender.sendDue(now: future)
        #expect(store.all.isEmpty)
    }

    @Test
    func composerSchedulesOnlyNormalMessagesInMainTimeline() async {
        let viewModel = makeComposer(canSchedule: true)
        viewModel.context.plainComposerText = .init(string: "Привет")
        #expect(viewModel.context.viewState.nyutagCanScheduleNow)

        viewModel.process(viewAction: .nyutagSchedule(.now.addingTimeInterval(-60)))
        #expect(store.all.isEmpty)

        let sendAt = Date.now.addingTimeInterval(3600)
        viewModel.process(viewAction: .nyutagSchedule(sendAt))
        #expect(store.all.map(\.body) == ["Привет"])
        #expect(store.all.first?.roomId == "!r:x")
        #expect(viewModel.context.plainComposerText.string.isEmpty)
        #expect(viewModel.context.viewState.nyutagScheduled.count == 1)

        viewModel.context.plainComposerText = .init(string: "Ответ")
        viewModel.process(timelineAction: .setMode(mode: .reply(eventID: "$e", replyDetails: .loading(eventID: "$e"), isThread: false)))
        #expect(!viewModel.context.viewState.nyutagCanScheduleNow)

        let threadComposer = makeComposer(canSchedule: false)
        threadComposer.context.plainComposerText = .init(string: "В ветке")
        threadComposer.process(viewAction: .nyutagSchedule(sendAt))
        #expect(store.all.count == 1)
    }

    @Test
    func reminderFiresTwoMinutesAfterDueTimeAndOpensTheRoom() throws {
        let message = makeMessage(id: "m", sendAt: now.addingTimeInterval(600))
        let request = NyutagScheduledReminders.request(for: message, now: now)
        let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)

        #expect(request.identifier == "nyutag-scheduled-m")
        #expect(trigger.timeInterval == 600 + NyutagScheduledReminders.delay)
        #expect(request.content.roomID == "!r:x")
        #expect(request.content.receiverID == "@me:x")
        #expect(request.content.body.contains("Привет"))

        // Срок давно прошёл (приложение долго не открывали) — напоминание сразу.
        let late = NyutagScheduledReminders.request(for: message, now: now.addingTimeInterval(3600))
        #expect((late.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval == 1)
    }

    @Test
    func backgroundWakeSendsDueMessages() async throws {
        let roomProxy = JoinedRoomProxyMock(.init(id: "!r:x"))
        let clientProxy = ClientProxyMock(.init(userID: "@me:x"))
        clientProxy.roomForIdentifierClosure = { _ in .joined(roomProxy) }
        let notificationCenter = NotificationCenter()
        let sender = NyutagScheduledSender(clientProxy: clientProxy, store: store, notificationCenter: notificationCenter)
        // Срок наступит через 2 с — первый проход таймера и подписки на очередь его ещё не видят.
        store.schedule(makeMessage(id: "due", sendAt: .now.addingTimeInterval(2)))
        try await Task.sleep(for: .seconds(2.5))

        notificationCenter.post(name: .nyutagScheduledSendDue, object: nil)
        for _ in 0..<50 where !store.all.isEmpty {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(store.all.isEmpty)
        withExtendedLifetime(sender) { }
    }

    // MARK: - Helpers

    private func makeMessage(id: String, sessionID: String = "@me:x", roomID: String = "!r:x", sendAt: Date, mentions: IntentionalMentions = .empty) -> NyutagScheduledMessage {
        NyutagScheduledMessage(id: id, sessionID: sessionID, roomID: roomID, body: "Привет", html: nil, intentionalMentions: mentions, sendAt: sendAt)
    }

    private func makeComposer(canSchedule: Bool) -> ComposerToolbarViewModel {
        let viewModel = ComposerToolbarViewModel(roomProxy: JoinedRoomProxyMock(.init(id: "!r:x")),
                                                 wysiwygViewModel: WysiwygComposerViewModel(),
                                                 completionSuggestionService: CompletionSuggestionServiceMock(configuration: .init()),
                                                 mediaProvider: MediaProviderMock(.init()),
                                                 mentionDisplayHelper: ComposerMentionDisplayHelper.mock,
                                                 appSettings: AppSettings.volatile(),
                                                 analyticsService: AnalyticsServiceMock(.init()),
                                                 composerDraftService: ComposerDraftServiceMock(.init()),
                                                 nyutagCanSchedule: canSchedule,
                                                 nyutagScheduledStore: store)
        viewModel.context.composerFormattingEnabled = false
        return viewModel
    }
}
