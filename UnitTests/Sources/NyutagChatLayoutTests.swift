//
// Нютаг (форк Element X iOS) — тесты закреплённых чатов, папок и года по восточному календарю.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

@testable import ElementX
import Foundation
import Testing

struct NyutagChatLayoutTests {
    @Test
    func newPinGoesOnTopAndLimitIsFive() {
        var layout = NyutagChatLayout()
        for index in 1...6 {
            layout = layout.withPinned("!r\(index):x", pinned: true)
        }
        
        #expect(layout.pins == ["!r5:x", "!r4:x", "!r3:x", "!r2:x", "!r1:x"])
        #expect(!layout.canPinMore)
        #expect(layout.withPinned("!r3:x", pinned: false).pins == ["!r5:x", "!r4:x", "!r2:x", "!r1:x"])
    }
    
    @Test
    func parsesAndroidJSONAndDropsBrokenEntries() {
        let json = #"{"pins":["!a:x","!a:x","!b:x"],"folders":[{"id":"f1","name":"Род","rooms":["!a:x"]},{"id":"f1","name":"Дубль"},{"id":"","name":"Без id"},{"id":"f2","name":" "}]}"#
        
        let layout = NyutagChatLayout.fromJSON(json)
        
        #expect(layout.pins == ["!a:x", "!b:x"])
        #expect(layout.folders == [NyutagChatFolder(id: "f1", name: "Род", rooms: ["!a:x"])])
        #expect(NyutagChatLayout.fromJSON("not json") == NyutagChatLayout())
    }
    
    @Test
    func encodingOmitsEmptyFieldsAndRoundTrips() throws {
        #expect(NyutagChatLayout().json == "{}")
        
        let layout = NyutagChatLayout()
            .withNewFolder(id: "f1", name: "  Работа ", roomID: "!a:x")
            .withNewFolder(id: "f2", name: "Пустая", roomID: nil)
            .withPinned("!a:x", pinned: true)
        
        #expect(layout.folders.map(\.name) == ["Работа", "Пустая"])
        #expect(try #require(layout.json).contains(#"{"id":"f2","name":"Пустая"}"#))
        #expect(NyutagChatLayout.fromJSON(layout.json) == layout)
    }
    
    @Test
    func folderEditing() {
        let layout = NyutagChatLayout(folders: [NyutagChatFolder(id: "f1", name: "Род")])
            .withRoom("!a:x", inFolder: "f1", isIn: true)
            .withRoom("!a:x", inFolder: "f1", isIn: true)
            .withRoom("!b:x", inFolder: "f1", isIn: true)
            .withRoom("!a:x", inFolder: "f1", isIn: false)
            .withRenamedFolder(id: "f1", name: "Хори")
        
        #expect(layout.folders == [NyutagChatFolder(id: "f1", name: "Хори", rooms: ["!b:x"])])
        #expect(layout.withRenamedFolder(id: "f1", name: "  ").folders.first?.name == "Хори")
        #expect(layout.withoutFolder(id: "f1").folders.isEmpty)
    }
    
    @Test
    func eastYearMatchesAndroid() {
        #expect(NyutagEastYear(year: 1984).key == "wood-rat")
        #expect(NyutagEastYear(year: 2026).key == "fire-horse")
        #expect(NyutagEastYear(year: 1990).key == "metal-horse")
        #expect(NyutagEastYear(year: 1920).key == "metal-monkey")
        #expect(NyutagEastYear(key: "fire-horse") == NyutagEastYear(year: 2026))
        #expect(NyutagEastYear(key: "fire") == nil)
    }
    
    @Test
    func profileInfoNormalization() {
        let info = NyutagProfileInfo(about: String(repeating: "а", count: 600), toonto: " Хори ", ug: "Хуасай", eastYear: "bogus")
        
        let normalized = info.normalized
        
        #expect(normalized.about.count == NyutagProfileInfo.maxAbout)
        #expect(normalized.toonto == "Хори")
        #expect(normalized.eastYear.isEmpty)
        #expect(NyutagProfileInfo(fields: normalized.fields) == normalized)
    }
}
