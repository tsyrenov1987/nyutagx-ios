//
// Нютаг (форк Element X iOS) — тесты исчезающего фото.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

@testable import ElementX
import Foundation
import Testing

struct NyutagViewOnceTests {
    @Test
    func readsMarkFromOriginalEventJSON() {
        #expect(NyutagViewOnce.isMarked(originalJSON: #"{"type":"m.room.message","content":{"msgtype":"m.image","chat.nyutag.view_once":true}}"#))
        #expect(!NyutagViewOnce.isMarked(originalJSON: #"{"content":{"msgtype":"m.image","chat.nyutag.view_once":false}}"#))
        #expect(!NyutagViewOnce.isMarked(originalJSON: #"{"content":{"msgtype":"m.image"}}"#))
        #expect(!NyutagViewOnce.isMarked(originalJSON: "не json"))
        #expect(!NyutagViewOnce.isMarked(originalJSON: nil))
    }
    
    @Test
    func extraContentMatchesAndroidFormat() throws {
        let data = try #require(NyutagViewOnce.extraContentJSON.data(using: .utf8))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json[NyutagViewOnce.key] as? Bool == true)
    }
    
    @Test
    func viewOncePhotoCannotBeForwardedOrSelected() {
        #expect(makeImageItem(viewOnce: false).isForwardable)
        
        let item = makeImageItem(viewOnce: true)
        
        #expect(item.isNyutagViewOnce)
        #expect(!item.isForwardable)
        #expect(!item.isBulkSelectable)
    }

    @Test
    func openedMarkSurvivesAppRestart() throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let opened = TimelineItemIdentifier.randomEvent
        NyutagViewOnceOpened.markOpened(opened, defaults: defaults)

        // Новый запуск: та же картинка пришла с другим unique ID, но с тем же event ID.
        let afterRestart = TimelineItemIdentifier.event(uniqueID: .init(UUID().uuidString), eventOrTransactionID: .eventID(try #require(opened.eventID)))
        #expect(NyutagViewOnceOpened.wasOpened(afterRestart, defaults: defaults))
        #expect(!NyutagViewOnceOpened.wasOpened(.randomEvent, defaults: defaults))
    }

    // MARK: - Helpers
    
    private func makeImageItem(viewOnce: Bool) -> ImageRoomTimelineItem {
        var content = ImageRoomTimelineItemContent(filename: "image.jpg", imageInfo: .mockImage, thumbnailInfo: .mockThumbnail, contentType: .jpeg)
        content.nyutagViewOnce = viewOnce
        return ImageRoomTimelineItem(id: .randomEvent,
                              timestamp: .mock,
                              isOutgoing: false,
                              isEditable: false,
                              canBeRepliedTo: true,
                              sender: .init(id: "@alice:x"),
                              content: content)
    }
}
