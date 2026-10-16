//
// Нютаг (форк Element X iOS) — приглашения, вход по телефону или почте.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Contacts
import Foundation
import Network
import Synchronization

/// Сервис `/_nyutag/v1/` живёт на ядре рядом с Tuwunel. Ходим к нему тем же туннелем «Кильватер» и с тем же CA, что и SDK.
nonisolated final class NyutagInvitesService: NSObject, URLSessionDelegate, Sendable {
    static let shared = NyutagInvitesService()
    
    /// Обращения разработчика ко всем пользователям (`/_nyutag/v1/announce`): текст на языке приложения, кнопки — ссылка или донат.
    func announcements() async throws(NyutagInviteError) -> [NyutagAnnouncement] {
        let json = try await request("GET", "/_nyutag/v1/announce")
        let language = NyutagLanguage.current == .system
            ? String((Locale.preferredLanguages.first ?? "ru").prefix(2))
            : NyutagLanguage.current.rawValue
        return (json["announcements"] as? [[String: Any]] ?? []).compactMap { NyutagAnnouncement(json: $0, language: language) }
    }
    
    func signUpConfiguration() async throws(NyutagInviteError) -> NyutagSignUpConfiguration {
        let json = try await request("GET", "/_nyutag/v1/config")
        return NyutagSignUpConfiguration(requiresInvite: json["require_invite"] as? Bool ?? true,
                                         requiresContact: json["require_contact"] as? Bool ?? false,
                                         isEmailAvailable: json["email"] as? Bool ?? false,
                                         isPhoneAvailable: json["msisdn"] as? Bool ?? false,
                                         requiresEmail: json["require_email"] as? Bool ?? false,
                                         requiresPhone: json["require_phone"] as? Bool ?? false,
                                         isPhoneUnverified: json["phone_unverified"] as? Bool ?? false)
    }
    
    /// Проверяет код приглашения на первом шаге регистрации; возвращает Matrix ID пригласившего.
    func checkInvite(code: String) async throws(NyutagInviteError) -> String? {
        let json = try await request("POST", "/_nyutag/v1/invites/check", body: ["code": code])
        guard json["valid"] as? Bool == true else { throw .init(errcode: "NYUTAG_CLIENT_ERROR") }
        return json["inviter"] as? String
    }
    
    /// Свободен ли ник: `M_USER_IN_USE` / `M_INVALID_USERNAME` приходят ошибкой.
    func checkUsername(_ username: String) async throws(NyutagInviteError) {
        var components = URLComponents()
        components.path = "/_matrix/client/v3/register/available"
        components.queryItems = [URLQueryItem(name: "username", value: username)]
        guard let path = components.string else { throw .init(errcode: "M_INVALID_USERNAME") }
        let json = try await request("GET", path)
        guard json["available"] as? Bool == true else { throw .init(errcode: "M_USER_IN_USE") }
    }
    
    /// Шлёт шестизначный код на телефон или почту. Код приглашения нужен серверу, чтобы не слать SMS чужим.
    func startVerification(medium: NyutagContactMedium, address: String, inviteCode: String) async throws(NyutagInviteError) -> NyutagVerification {
        let json = try await request("POST", "/_nyutag/v1/verify/start", body: ["medium": medium.rawValue, "address": address, "code": inviteCode])
        guard let sid = json["sid"] as? String else { throw .init(errcode: "NYUTAG_CLIENT_ERROR") }
        return NyutagVerification(sid: sid, resendAfter: json["resend_after_s"] as? Int ?? 60)
    }
    
    func checkVerification(sid: String, token: String) async throws(NyutagInviteError) {
        let json = try await request("POST", "/_nyutag/v1/verify/check", body: ["sid": sid, "token": token])
        guard json["verified"] as? Bool == true else { throw .init(errcode: NyutagInviteError.verifyWrong) }
    }
    
    /// Шаг «Телефон»: номер годен и ещё не занят; возвращает его в виде `+79…`. Нужен годный код приглашения.
    func checkPhone(_ phone: String, inviteCode: String) async throws(NyutagInviteError) -> String {
        let json = try await request("POST", "/_nyutag/v1/phone/check", body: ["phone": phone, "code": inviteCode])
        guard let normalized = json["phone"] as? String else { throw .init(errcode: "NYUTAG_CLIENT_ERROR") }
        return normalized
    }
    
    /// Регистрирует аккаунт и возвращает его Matrix ID; войти нужно обычным паролем.
    /// `phone` — номер без подтверждения (пока у сервера нет SMS): по нему человека найдут друзья.
    func register(code: String, username: String, password: String, sid: String?, phone: String? = nil) async throws(NyutagInviteError) -> String {
        var body = ["code": code, "username": username, "password": password]
        body["sid"] = sid
        body["phone"] = phone
        let json = try await request("POST", "/_nyutag/v1/register", body: body)
        guard let userID = json["user_id"] as? String else { throw .init(errcode: "NYUTAG_CLIENT_ERROR") }
        MXLog.info("Nyutag: registered \(userID) by invite")
        return userID
    }
    
    /// Вход по телефону или почте: Matrix ID аккаунта, если пароль верный.
    func resolveLogin(identifier: String, password: String) async throws(NyutagInviteError) -> String {
        let json = try await request("POST", "/_nyutag/v1/resolve", body: ["identifier": identifier, "password": password])
        guard let userID = json["user_id"] as? String else { throw .init(errcode: "NYUTAG_CLIENT_ERROR") }
        return userID
    }
    
    /// Выпускает одноразовый код от имени участника; код живёт 7 дней.
    func createInvite(accessToken: String) async throws(NyutagInviteError) -> NyutagInvite {
        let json = try await request("POST", "/_nyutag/v1/invites", bearer: accessToken)
        guard let code = json["code"] as? String else { throw .init(errcode: "NYUTAG_CLIENT_ERROR") }
        let expiresAt = (json["expires_at"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
        return NyutagInvite(code: code, expiresAt: expiresAt)
    }
    
    /// Ищет участников по номерам телефонов: номер (как передан) → Matrix ID. Ненайденных в ответе нет.
    func lookupPhones(_ phones: [String], accessToken: String) async throws(NyutagInviteError) -> [String: String] {
        let json = try await request("POST", "/_nyutag/v1/lookup", body: ["phones": phones], bearer: accessToken)
        let matches = json["matches"] as? [[String: Any]] ?? []
        return Dictionary(matches.compactMap { match in
            guard let phone = match["phone"] as? String, let userID = match["user_id"] as? String else { return nil }
            return (phone, userID)
        }, uniquingKeysWith: { first, _ in first })
    }
    
    /// Есть ли номер участника среди номеров записной книжки (сервер отвечает только да/нет, номера не хранит).
    func isInContacts(userID: String, phones: [String], accessToken: String) async throws(NyutagInviteError) -> Bool {
        try await request("POST", "/_nyutag/v1/contact-check", body: ["user_id": userID, "phones": phones], bearer: accessToken)["in_contacts"] as? Bool ?? false
    }
    
    /// Указан ли у участника свой номер телефона.
    func hasPhone(accessToken: String) async throws(NyutagInviteError) -> Bool {
        try await request("GET", "/_nyutag/v1/me", bearer: accessToken)["phone"] as? Bool ?? false
    }
    
    /// Указывает или меняет свой номер телефона.
    /// Нютаг: Tuwunel не знает правила `.m.rule.rtc_notification` (MSC4075) — событие «звонок» от Element Call
    /// не превращается в пуш, и собеседник не слышит входящий. Ставим правило в аккаунт сами.
    func ensureCallPushRules(accessToken: String) async throws(NyutagInviteError) {
        let rules = [("nyutag.rtc_notification", "org.matrix.msc4075.rtc.notification"),
                     ("nyutag.call_notify", "org.matrix.msc4075.call.notify"),
                     ("nyutag.ring", Self.ringEventType)]
        for (ruleID, eventType) in rules {
            let body: [String: Any] = ["conditions": [["kind": "event_match", "key": "type", "pattern": eventType]],
                                       "actions": ["notify", ["set_tweak": "sound", "value": "default"]]]
            _ = try await request("PUT", "/_matrix/client/v3/pushrules/global/override/\(ruleID)", body: body, bearer: accessToken)
        }
    }
    
    // MARK: Звонок
    
    /// Незашифрованный сигнал «звоню»: шлюз Sygnal делает из него VoIP-пуш (расширение уведомлений без туннеля
    /// не может расшифровать `rtc.notification`). Содержимое — только то, что сервер и так видит по `call.member`.
    static let ringEventType = "chat.nyutag.ring"
    static let ringLifetimeMs = 90_000
    
    /// Перед стартом звонка: снимает зависшие участия своих устройств (ушедшее приложение их не чистит, и следующий
    /// звонок без них не звонит) и, если в комнате никто не разговаривает, кладёт сигнал «звоню».
    func prepareCallStart(roomID: String, ownUserID: String, isVoiceCall: Bool, accessToken: String) async {
        let encodedRoomID = roomID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? roomID
        var othersInCall = false
        do {
            let events = try await requestArray("GET", "/_matrix/client/v3/rooms/\(encodedRoomID)/state", bearer: accessToken)
            let now = Date().timeIntervalSince1970 * 1000
            for event in events where event["type"] as? String == "org.matrix.msc3401.call.member" {
                guard let content = event["content"] as? [String: Any], !content.isEmpty,
                      let stateKey = event["state_key"] as? String else { continue }
                let sentAt = (event["origin_server_ts"] as? Double) ?? now
                let expires = (content["expires"] as? Double) ?? 0
                let alive = sentAt + expires > now
                if event["sender"] as? String == ownUserID {
                    let encodedKey = stateKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? stateKey
                    _ = try? await request("PUT", "/_matrix/client/v3/rooms/\(encodedRoomID)/state/org.matrix.msc3401.call.member/\(encodedKey)",
                                           body: [:], bearer: accessToken)
                    MXLog.info("Nyutag call: cleared own stale call membership \(stateKey)")
                } else if alive {
                    othersInCall = true
                }
            }
        } catch {
            MXLog.warning("Nyutag call: state check failed \(error.errcode)")
        }
        guard !othersInCall else {
            MXLog.info("Nyutag call: joining an existing call, no ring")
            return
        }
        let body: [String: Any] = ["sender_ts": Int(Date().timeIntervalSince1970 * 1000),
                                   "lifetime": Self.ringLifetimeMs,
                                   "m.call.intent": isVoiceCall ? "audio" : "video"]
        let txnID = "nyutag-ring-\(UUID().uuidString)"
        do {
            _ = try await request("PUT", "/_matrix/client/v3/rooms/\(encodedRoomID)/send/\(Self.ringEventType)/\(txnID)", body: body, bearer: accessToken)
            MXLog.info("Nyutag call: ring sent to \(roomID)")
        } catch {
            MXLog.warning("Nyutag call: ring failed \(error.errcode)")
        }
    }
    
    func setPhone(_ phone: String, accessToken: String) async throws(NyutagInviteError) {
        _ = try await request("POST", "/_nyutag/v1/me/phone", body: ["phone": phone], bearer: accessToken)
    }
    
    /// Каталог сообществ, как поиск сообществ во «ВКонтакте»: все пространства сервера, опубликованные в каталоге.
    func communities(searchTerm: String, since: String?, accessToken: String) async throws(NyutagInviteError) -> NyutagCommunityPage {
        var filter: [String: Any] = ["room_types": ["m.space"]]
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        if !term.isEmpty {
            filter["generic_search_term"] = term
        }
        var body: [String: Any] = ["limit": 50, "filter": filter]
        if let since {
            body["since"] = since
        }
        let json = try await request("POST", "/_matrix/client/v3/publicRooms", body: body, bearer: accessToken)
        let chunk = json["chunk"] as? [[String: Any]] ?? []
        return NyutagCommunityPage(communities: chunk.compactMap(NyutagCommunity.init(json:)), nextBatch: json["next_batch"] as? String)
    }
    
    /// «В сети» / «был(а) …» собеседника: SDK умеет только отправлять своё присутствие, читаем чужое сами.
    func presence(userID: String, accessToken: String) async throws(NyutagInviteError) -> NyutagPresence {
        let path = "/_matrix/client/v3/presence/\(userID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(.init(charactersIn: "/"))) ?? userID)/status"
        return NyutagPresence(json: try await request("GET", path, bearer: accessToken))
    }
    
    // MARK: - Transport
    
    /// То же, что `request`, но для ответов-массивов (например, `/state`).
    private func requestArray(_ method: String, _ path: String, bearer: String? = nil) async throws(NyutagInviteError) -> [[String: Any]] {
        guard let endpoint = NyutagTunnel.endpoint,
              let url = URL(string: NyutagTunnel.homeserverURL + path) else {
            throw .init(errcode: NyutagInviteError.network)
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        if let bearer {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session(for: endpoint).data(for: request)
        } catch {
            throw .init(errcode: NyutagInviteError.network)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200, let array = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            throw .init(errcode: "HTTP_\(status)")
        }
        return array
    }
    
    private func request(_ method: String, _ path: String, body: [String: Any]? = nil, bearer: String? = nil) async throws(NyutagInviteError) -> [String: Any] {
        guard let endpoint = NyutagTunnel.endpoint,
              let url = URL(string: NyutagTunnel.homeserverURL + path) else {
            throw .init(errcode: NyutagInviteError.network)
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        if let bearer {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session(for: endpoint).data(for: request)
        } catch {
            MXLog.warning("Nyutag invites: network error \((error as NSError).code)")
            throw .init(errcode: NyutagInviteError.network)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard status == 200 else {
            let errcode = json["errcode"] as? String ?? "HTTP_\(status)"
            MXLog.warning("Nyutag invites: \(errcode)")
            throw .init(errcode: errcode)
        }
        return json
    }
    
    /// Сессия через SOCKS туннеля; учётка SOCKS одна на процесс, поэтому сессию можно переиспользовать.
    private func session(for endpoint: NyutagTunnel.Endpoint) -> URLSession {
        sessionCache.withLock { cache in
            if let cached = cache, cached.port == endpoint.port { return cached.session }
            let configuration = URLSessionConfiguration.ephemeral
            // swiftlint:disable:next force_unwrapping
            let proxy = ProxyConfiguration(socksv5Proxy: .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: UInt16(endpoint.port))!))
            proxy.applyCredential(username: endpoint.user, password: endpoint.password)
            configuration.proxyConfigurations = [proxy]
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            cache = (endpoint.port, session)
            return session
        }
    }
    
    private let sessionCache = Mutex<(port: Int, session: URLSession)?>(nil)
    
    // MARK: - URLSessionDelegate
    
    /// Доверяем только нашему CA и только для хоста ядра.
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        NyutagTrust.evaluate(challenge)
    }
}

/// Проверка TLS ядра: единственный якорь — наш CA.
nonisolated enum NyutagTrust {
    static func evaluate(_ challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }
        guard challenge.protectionSpace.host == NyutagTunnel.homeserverHost else {
            return (.performDefaultHandling, nil)
        }
        SecTrustSetAnchorCertificates(trust, [NyutagTunnel.caCertificate] as CFArray)
        SecTrustSetAnchorCertificatesOnly(trust, true)
        guard SecTrustEvaluateWithError(trust, nil) else {
            MXLog.error("Nyutag: core TLS certificate is not issued by the Nyutag CA")
            return (.cancelAuthenticationChallenge, nil)
        }
        return (.useCredential, URLCredential(trust: trust))
    }
}

enum NyutagContactMedium: String, Sendable {
    case phone = "msisdn"
    case email
}

struct NyutagSignUpConfiguration: Equatable, Sendable {
    let requiresInvite: Bool
    /// Телефон или почта обязательны (сервер включает это, когда настроен хотя бы один канал).
    let requiresContact: Bool
    let isEmailAvailable: Bool
    let isPhoneAvailable: Bool
    /// Почта обязательна (с кодом из письма).
    var requiresEmail = false
    /// Телефон обязателен.
    var requiresPhone = false
    /// Телефон пока без подтверждения: у сервера нет SMS, номер вводится на своём шаге.
    var isPhoneUnverified = false
}

struct NyutagVerification: Equatable, Sendable {
    let sid: String
    let resendAfter: Int
}

/// Сообщество из каталога сервера.
nonisolated struct NyutagCommunity: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let topic: String?
    let alias: String?
    let avatarURL: URL?
    let membersCount: Int
    /// Открытое — вступление сразу; иначе закрытое (по заявке или по приглашению).
    let isOpen: Bool
    
    init?(json: [String: Any]) {
        guard let id = json["room_id"] as? String else { return nil }
        self.id = id
        alias = json["canonical_alias"] as? String
        name = (json["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? alias ?? id
        topic = json["topic"] as? String
        avatarURL = (json["avatar_url"] as? String).flatMap(URL.init(string:))
        membersCount = json["num_joined_members"] as? Int ?? 0
        isOpen = (json["join_rule"] as? String ?? "public") == "public"
    }
}

nonisolated struct NyutagCommunityPage: Sendable {
    let communities: [NyutagCommunity]
    let nextBatch: String?
}

/// Заявки в закрытые сообщества, поданные с этого устройства: приглашение после одобрения принимается само, как во ВКонтакте.
enum NyutagKnockedRooms {
    private static let key = "nyutagKnockedRoomIDs"
    
    static var all: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }
    
    static func insert(_ roomID: String) {
        UserDefaults.standard.set(Array(all.union([roomID])), forKey: key)
    }
    
    static func remove(_ roomID: String) {
        UserDefaults.standard.set(Array(all.subtracting([roomID])), forKey: key)
    }
}

/// Номера из записной книжки (после разрешения на контакты) — для надписи «Вне контактов».
enum NyutagAddressBook {
    /// Столько же принимает сервер в одной проверке.
    nonisolated static let maxPhones = 5000
    
    nonisolated static func phones() -> [String] {
        var phones = Set<String>()
        let request = CNContactFetchRequest(keysToFetch: [CNContactPhoneNumbersKey as CNKeyDescriptor])
        try? CNContactStore().enumerateContacts(with: request) { contact, stop in
            for number in contact.phoneNumbers {
                phones.insert(number.value.stringValue)
            }
            if phones.count >= maxPhones {
                stop.pointee = true
            }
        }
        return Array(phones.prefix(maxPhones))
    }
    
    /// Записи книжки с именами (один номер — одна запись): для списка «Контакты в Нютаге».
    nonisolated static func contacts() -> [NyutagContact] {
        var seen = Set<String>()
        var contacts = [NyutagContact]()
        let keys = [CNContactPhoneNumbersKey, CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault
        try? CNContactStore().enumerateContacts(with: request) { contact, stop in
            let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            for number in contact.phoneNumbers {
                let phone = number.value.stringValue
                // Один и тот же номер, записанный по-разному (+7… и 8…), — одна запись.
                guard seen.insert(String(phone.filter(\.isNumber).suffix(10))).inserted else { continue }
                contacts.append(NyutagContact(name: name.isEmpty ? (contact.organizationName.isEmpty ? phone : contact.organizationName) : name, phone: phone))
            }
            if contacts.count >= maxPhones {
                stop.pointee = true
            }
        }
        return contacts
    }
}

/// Запись телефонной книги: имя, как записано у человека, и номер.
nonisolated struct NyutagContact: Hashable {
    let name: String
    let phone: String
}

/// Контакт из книжки, найденный в Нютаге: имя — как записано у человека, профиль — с сервера.
nonisolated struct NyutagMatchedContact: Hashable, Codable, Identifiable {
    let name: String
    let phone: String
    let userID: String
    let displayName: String?
    let avatarURL: URL?
    
    var id: String { userID }
    
    /// Профиль для строки списка: имя из книжки, аватар из Нютага.
    var profile: UserProfile { UserProfile(userID: userID, displayName: name, avatarURL: avatarURL) }
}

/// Сверка записной книжки с сервером: номера уходят пачками, сервер отвечает только совпадениями и номера не хранит.
/// Итог запоминается на устройстве, чтобы список показывался сразу, а сверка шла не чаще раза в час.
enum NyutagContactsSync {
    /// Столько номеров сервер принимает в одном запросе поиска.
    private static let batch = 500
    private static let interval: TimeInterval = 60 * 60
    
    private static func key(_ userID: String) -> String { "nyutagMatchedContacts." + userID }
    
    static func cached(userID: String) -> [NyutagMatchedContact]? {
        guard let data = UserDefaults.standard.data(forKey: key(userID)) else { return nil }
        return try? JSONDecoder().decode([NyutagMatchedContact].self, from: data)
    }
    
    /// Без `force` — только если прошлая сверка старше часа (тогда отдаёт `cached`).
    static func sync(clientProxy: ClientProxyProtocol, force: Bool) async throws(NyutagInviteError) -> [NyutagMatchedContact] {
        let userID = clientProxy.userID
        let syncedAt = UserDefaults.standard.double(forKey: key(userID) + ".at")
        if !force, Date().timeIntervalSince1970 - syncedAt < interval, let cached = cached(userID: userID) {
            return cached
        }
        guard let accessToken = (clientProxy as? ClientProxy)?.nyutagAccessToken else { throw .init(errcode: "NYUTAG_CLIENT_ERROR") }
        let contacts = await Task.detached { NyutagAddressBook.contacts() }.value
        let byPhone = Dictionary(contacts.map { ($0.phone, $0) }, uniquingKeysWith: { first, _ in first })
        let previous = Dictionary((cached(userID: userID) ?? []).map { ($0.userID, $0) }, uniquingKeysWith: { first, _ in first })
        var matched = [NyutagMatchedContact]()
        var seen = Set<String>()
        for start in stride(from: 0, to: contacts.count, by: batch) {
            let phones = contacts[start..<min(start + batch, contacts.count)].map(\.phone)
            let matches = try await NyutagInvitesService.shared.lookupPhones(phones, accessToken: accessToken)
            for (phone, matchedUserID) in matches {
                guard let contact = byPhone[phone], seen.insert(matchedUserID).inserted else { continue }
                // Профиль (аватар, имя в Нютаге) — с сервера; не вышло — берём прошлый.
                let profile = try? await clientProxy.profile(for: matchedUserID).get()
                matched.append(NyutagMatchedContact(name: contact.name,
                                                    phone: phone,
                                                    userID: matchedUserID,
                                                    displayName: profile?.displayName ?? previous[matchedUserID]?.displayName,
                                                    avatarURL: profile?.avatarURL ?? previous[matchedUserID]?.avatarURL))
            }
        }
        matched.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if let data = try? JSONEncoder().encode(matched) {
            UserDefaults.standard.set(data, forKey: key(userID))
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key(userID) + ".at")
        }
        return matched
    }
}

/// Личные чаты, принятые сами (написал незнакомый), где мы ещё не ответили: пока чат здесь, в нём надпись «Вне контактов».
/// Хранится только на этом устройстве.
enum NyutagUnansweredChats {
    private static let key = "nyutagUnansweredChatIDs"
    
    static var all: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }
    
    static func insert(_ roomID: String) {
        UserDefaults.standard.set(Array(all.union([roomID])), forKey: key)
    }
    
    static func remove(_ roomID: String) {
        UserDefaults.standard.set(Array(all.subtracting([roomID])), forKey: key)
    }
}

struct NyutagInvite: Equatable, Sendable {
    /// Код вида `XXXX-XXXX`.
    let code: String
    let expiresAt: Date?
    
    /// Ссылка-приглашение: страница на nyutag.chat с кодом и QR; код в `#` не уходит на сервер сайта.
    var link: String {
        "https://nyutag.chat/i/#\(code)"
    }
    
    /// Код из ссылки-приглашения (`https://nyutag.chat/i/#КОД` или `nyutag://invite/КОД`); nil — ссылка не наша.
    static func code(fromLink url: URL) -> String? {
        let raw: String?
        if url.scheme == "nyutag", url.host == "invite" {
            raw = url.pathComponents.dropFirst().first
        } else if url.scheme == "https", url.host == "nyutag.chat", url.path.hasPrefix("/i") {
            raw = url.fragment
        } else {
            raw = nil
        }
        guard let raw, raw.wholeMatch(of: /[0-9A-Za-z]{4}-?[0-9A-Za-z]{4}/) != nil else { return nil }
        return raw.uppercased()
    }
}

/// Отказ сервиса приглашений; `errcode` — машинный код: `NYUTAG_CODE_USED`, `M_USER_IN_USE` и т.п.
struct NyutagInviteError: Error, Equatable, Sendable {
    let errcode: String
    
    static let network = "NYUTAG_NETWORK"
    static let verifyWrong = "NYUTAG_VERIFY_WRONG"
}

private nonisolated enum NyutagTranslit {
    // Та же таблица, что в Android (NyutagTranslit.kt): одно название — один адрес на обеих платформах.
    static let table: [Character: String] = [
        "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e", "ж": "zh",
        "з": "z", "и": "i", "й": "y", "к": "k", "л": "l", "м": "m", "н": "n", "о": "o",
        "п": "p", "р": "r", "с": "s", "т": "t", "у": "u", "ф": "f", "х": "kh", "ц": "ts",
        "ч": "ch", "ш": "sh", "щ": "shch", "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu",
        "я": "ya", "ө": "o", "ү": "u", "һ": "h"
    ]
}

extension String {
    /// Кириллица (с бурятскими ө, ү, һ) латиницей — для адреса группы/сообщества:
    /// SDK выбрасывает не-латинские буквы, и адрес из русского или бурятского названия выходит пустым.
    var nyutagLatinized: String {
        lowercased().map { NyutagTranslit.table[$0] ?? String($0) }.joined()
    }
    
    /// Похоже ли введённое на телефон или почту, а не на имя пользователя.
    var looksLikeNyutagContact: Bool {
        let value = trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("@") || value.contains(":") { return false }
        if value.contains("@") { return true }
        return value.count(where: \.isNumber) >= 10 && value.allSatisfy { $0.isNumber || "+-() ".contains($0) }
    }
}

// MARK: - Присутствие собеседника в шапке личного чата, как в Telegram

nonisolated struct NyutagPresence: Equatable {
    let isOnline: Bool
    /// Когда собеседник был активен в последний раз (если сервер это знает).
    let lastActiveDate: Date?
    
    init(isOnline: Bool, lastActiveDate: Date?) {
        self.isOnline = isOnline
        self.lastActiveDate = lastActiveDate
    }
    
    init(json: [String: Any], now: Date = .now) {
        let presence = json["presence"] as? String
        isOnline = presence == "online" && (json["currently_active"] as? Bool ?? false)
        lastActiveDate = (json["last_active_ago"] as? NSNumber).map { now.addingTimeInterval(-$0.doubleValue / 1000) }
    }
    
    /// Подпись под именем: «в сети», «был(а) 5 мин. назад», «был(а) в 14:05», «был(а) вчера в 09:30», «был(а) 03.10.26».
    func subtitle(now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) -> String {
        if isOnline {
            return NyutagL10n.presenceOnline
        }
        guard let lastActiveDate else {
            return NyutagL10n.presenceRecently
        }
        let seconds = max(0, now.timeIntervalSince(lastActiveDate))
        if seconds < 60 {
            return NyutagL10n.presenceJustNow
        }
        if seconds < 3600 {
            return NyutagL10n.presenceMinutesAgo(Int(seconds / 60))
        }
        let time = lastActiveDate.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar))
        if calendar.isDate(lastActiveDate, inSameDayAs: now) {
            return NyutagL10n.presenceTodayAt(time)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(lastActiveDate, inSameDayAs: yesterday) {
            return NyutagL10n.presenceYesterdayAt(time)
        }
        return NyutagL10n.presenceDate(lastActiveDate.formatted(Date.FormatStyle(date: .numeric, time: .omitted, locale: locale, calendar: calendar)))
    }
}

// MARK: - Обращения разработчика

/// Одно обращение из `announce.json` на ядре. Тексты приходят уже на нужном языке (ru/bxr/en, запасной — ru, затем en).
nonisolated struct NyutagAnnouncement: Identifiable, Equatable, Sendable {
    struct Action: Identifiable, Equatable, Sendable {
        enum Kind: String { case url, donate }
        let id: String
        let kind: Kind
        let label: String
        let url: URL?
    }
    
    let id: String
    let title: String
    let body: String
    let actions: [Action]
    let dismissLabel: String?
    /// Через сколько дней показать снова после закрытия без действия; 0 — больше не показывать.
    let repeatDays: Int
    
    init?(json: [String: Any], language: String) {
        guard let id = json["id"] as? String, !id.isEmpty,
              let title = Self.localized(json["title"], language),
              let body = Self.localized(json["body"], language) else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let now = Date()
        if let from = (json["from"] as? String).flatMap(formatter.date(from:)), now < from { return nil }
        if let until = (json["until"] as? String).flatMap(formatter.date(from:)), now > until { return nil }
        self.id = id
        self.title = title
        self.body = body
        actions = (json["actions"] as? [[String: Any]] ?? []).enumerated().compactMap { index, item in
            guard let kind = (item["type"] as? String).flatMap(Action.Kind.init(rawValue:)),
                  let label = Self.localized(item["label"], language) else { return nil }
            return Action(id: "\(id)-\(index)", kind: kind, label: label, url: (item["url"] as? String).flatMap(URL.init(string:)))
        }
        dismissLabel = Self.localized(json["dismiss"], language)
        repeatDays = json["repeat_days"] as? Int ?? 0
    }
    
    private static func localized(_ value: Any?, _ language: String) -> String? {
        if let text = value as? String { return text.isEmpty ? nil : text }
        guard let table = value as? [String: Any] else { return nil }
        for key in [language, "ru", "en"] {
            if let text = table[key] as? String, !text.isEmpty { return text }
        }
        return table.values.compactMap { $0 as? String }.first { !$0.isEmpty }
    }
}

/// Что уже показано: закрытое по кнопке действия или «закрыть» не показываем больше, «позже» — через `repeatDays`.
nonisolated enum NyutagAnnouncementStore {
    private static let seenKey = "nyutag.announcements.seen"
    private static let laterKey = "nyutag.announcements.later"
    
    static func shouldShow(_ announcement: NyutagAnnouncement) -> Bool {
        let defaults = UserDefaults.standard
        if (defaults.stringArray(forKey: seenKey) ?? []).contains(announcement.id) { return false }
        if let shownAt = (defaults.dictionary(forKey: laterKey) as? [String: Double])?[announcement.id] {
            guard announcement.repeatDays > 0 else { return false }
            return Date().timeIntervalSince1970 - shownAt >= Double(announcement.repeatDays) * 86_400
        }
        return true
    }
    
    static func dismiss(_ announcement: NyutagAnnouncement, later: Bool) {
        let defaults = UserDefaults.standard
        if later, announcement.repeatDays > 0 {
            var table = defaults.dictionary(forKey: laterKey) as? [String: Double] ?? [:]
            table[announcement.id] = Date().timeIntervalSince1970
            defaults.set(table, forKey: laterKey)
        } else {
            var seen = defaults.stringArray(forKey: seenKey) ?? []
            seen.append(announcement.id)
            defaults.set(seen, forKey: seenKey)
        }
    }
}
