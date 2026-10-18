//
// Нютаг (форк Element X iOS) — закреплённые чаты (не более 5) и папки чатов, как в Telegram.
// Хранится в account data `chat.nyutag.chat_layout`, общий формат с Android:
// {"pins":["!room:server", …], "folders":[{"id":"…","name":"…","rooms":["!room:server", …]}]}
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

nonisolated struct NyutagChatFolder: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var rooms: [String] = []

    private enum CodingKeys: String, CodingKey {
        case id, name, rooms
    }

    init(id: String, name: String, rooms: [String] = []) {
        self.id = id
        self.name = name
        self.rooms = rooms
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        rooms = try container.decodeIfPresent([String].self, forKey: .rooms) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        if !rooms.isEmpty {
            try container.encode(rooms, forKey: .rooms)
        }
    }
}

nonisolated struct NyutagChatLayout: Codable, Equatable {
    static let eventType = "chat.nyutag.chat_layout"
    static let maxPins = 5

    var pins: [String] = []
    var folders: [NyutagChatFolder] = []

    private enum CodingKeys: String, CodingKey {
        case pins, folders
    }

    init(pins: [String] = [], folders: [NyutagChatFolder] = []) {
        self.pins = pins
        self.folders = folders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pins = try container.decodeIfPresent([String].self, forKey: .pins) ?? []
        folders = try container.decodeIfPresent([NyutagChatFolder].self, forKey: .folders) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !pins.isEmpty {
            try container.encode(pins, forKey: .pins)
        }
        if !folders.isEmpty {
            try container.encode(folders, forKey: .folders)
        }
    }

    /// Битые или чужие данные не роняют список чатов — просто пустая раскладка.
    static func fromJSON(_ json: String?) -> NyutagChatLayout {
        guard let json, let parsed = try? JSONDecoder().decode(NyutagChatLayout.self, from: Data(json.utf8)) else {
            return NyutagChatLayout()
        }
        var seenPins = Set<String>()
        var seenFolders = Set<String>()
        return NyutagChatLayout(pins: Array(parsed.pins.filter { seenPins.insert($0).inserted }.prefix(maxPins)),
                                folders: parsed.folders.filter {
                                    !$0.id.trimmingCharacters(in: .whitespaces).isEmpty
                                        && !$0.name.trimmingCharacters(in: .whitespaces).isEmpty
                                        && seenFolders.insert($0.id).inserted
                                })
    }

    var json: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func isPinned(_ roomID: String) -> Bool {
        pins.contains(roomID)
    }

    var canPinMore: Bool {
        pins.count < Self.maxPins
    }

    /// Новый закреп встаёт наверх, как в Telegram. Сверх лимита — без изменений.
    func withPinned(_ roomID: String, pinned: Bool) -> NyutagChatLayout {
        var copy = self
        if !pinned {
            copy.pins.removeAll { $0 == roomID }
        } else if !isPinned(roomID), canPinMore {
            copy.pins.insert(roomID, at: 0)
        }
        return copy
    }

    func withNewFolder(id: String, name: String, roomID: String?) -> NyutagChatLayout {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return self }
        var copy = self
        copy.folders.append(NyutagChatFolder(id: id, name: cleanName, rooms: roomID.map { [$0] } ?? []))
        return copy
    }

    func withRenamedFolder(id: String, name: String) -> NyutagChatLayout {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return self }
        var copy = self
        for index in copy.folders.indices where copy.folders[index].id == id {
            copy.folders[index].name = cleanName
        }
        return copy
    }

    func withoutFolder(id: String) -> NyutagChatLayout {
        var copy = self
        copy.folders.removeAll { $0.id == id }
        return copy
    }

    func withRoom(_ roomID: String, inFolder folderID: String, isIn: Bool) -> NyutagChatLayout {
        var copy = self
        for index in copy.folders.indices where copy.folders[index].id == folderID {
            if isIn, !copy.folders[index].rooms.contains(roomID) {
                copy.folders[index].rooms.append(roomID)
            } else if !isIn {
                copy.folders[index].rooms.removeAll { $0 == roomID }
            }
        }
        return copy
    }
}
