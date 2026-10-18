//
// Нютаг (форк Element X iOS) — тесты автоудаления сообщений.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

@testable import ElementX
import Foundation
import Testing

struct NyutagAutoDeleteTests {
    private let since = Date(timeIntervalSince1970: 1_000_000)

    @Test
    func ruleParsesAndroidJSONAndClampsNegatives() {
        let rule = NyutagAutoDeleteRule(json: ["ttl": 86400, "since": 1_700_000_000_123 as Int64])
        #expect(rule.ttlSeconds == NyutagAutoDeleteRule.day)
        #expect(rule.sinceMs == 1_700_000_000_123)
        #expect(NyutagAutoDeleteRule(json: ["ttl": -5]).isEnabled == false)
        #expect(NyutagAutoDeleteRule(json: [:]) == NyutagAutoDeleteRule())
    }

    @Test
    func messagesBeforeTimerAreKeptAndAfterExpireOnTime() {
        let rule = makeRule()

        #expect(!rule.isExpired(since.addingTimeInterval(-10), now: since.addingTimeInterval(10 * 86400)))
        #expect(!rule.isExpired(since.addingTimeInterval(10), now: since.addingTimeInterval(86400)))
        #expect(rule.isExpired(since.addingTimeInterval(10), now: since.addingTimeInterval(86410)))
        // Время события на iOS округлено до секунды вниз — сообщение в ту же секунду, что и включение, тоже удаляется.
        #expect(rule.isExpired(since.addingTimeInterval(-0.5), now: since.addingTimeInterval(2 * 86400)))
        #expect(!NyutagAutoDeleteRule().isExpired(since, now: since.addingTimeInterval(100 * 86400)))
    }

    @Test
    func timelineHidesExpiredMessagesButKeepsStateEvents() {
        let old = makeText(at: since.addingTimeInterval(-60), outgoing: true)
        let expiredOwn = makeText(at: since.addingTimeInterval(60), outgoing: true)
        let expiredOther = makeText(at: since.addingTimeInterval(120), outgoing: false)
        let fresh = makeText(at: since.addingTimeInterval(86400), outgoing: true)
        let state = StateRoomTimelineItem(id: .randomEvent, body: "joined", timestamp: since.addingTimeInterval(60),
                                          isOutgoing: true, isEditable: false, canBeRepliedTo: false, sender: .init(id: "@me:x"))
        let items: [RoomTimelineItemProtocol] = [old, expiredOwn, expiredOther, state, fresh]
        let now = since.addingTimeInterval(86400 + 200)

        let visible = NyutagAutoDeleteTimeline.visibleItems(items, rule: makeRule(), now: now)

        #expect(visible.map(\.id) == [old.id, state.id, fresh.id])
        #expect(NyutagAutoDeleteTimeline.ownToRedact(items, rule: makeRule(), now: now) == [expiredOwn.id.eventID])
        #expect(NyutagAutoDeleteTimeline.visibleItems(items, rule: .init(), now: now).count == items.count)
        #expect(NyutagAutoDeleteTimeline.ownToRedact(items, rule: .init(), now: now).isEmpty)
    }

    // MARK: - Helpers

    private func makeRule() -> NyutagAutoDeleteRule {
        NyutagAutoDeleteRule(ttlSeconds: NyutagAutoDeleteRule.day, sinceMs: Int64(since.timeIntervalSince1970 * 1000))
    }

    private func makeText(at timestamp: Date, outgoing: Bool) -> TextRoomTimelineItem {
        TextRoomTimelineItem(id: .randomEvent,
                             timestamp: timestamp,
                             isOutgoing: outgoing,
                             isEditable: false,
                             canBeRepliedTo: true,
                             sender: .init(id: outgoing ? "@me:x" : "@alice:x"),
                             content: .init(body: "Привет"))
    }
}
