//
// Нютаг (форк Element X iOS) — приглашения, вход по телефону или почте.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import Network
import Synchronization

/// Сервис `/_nyutag/v1/` живёт на ядре рядом с Tuwunel. Ходим к нему тем же туннелем «Кильватер» и с тем же CA, что и SDK.
nonisolated final class NyutagInvitesService: NSObject, URLSessionDelegate, Sendable {
    static let shared = NyutagInvitesService()
    
    func signUpConfiguration() async throws(NyutagInviteError) -> NyutagSignUpConfiguration {
        let json = try await request("GET", "/_nyutag/v1/config")
        return NyutagSignUpConfiguration(requiresInvite: json["require_invite"] as? Bool ?? true,
                                         requiresContact: json["require_contact"] as? Bool ?? false,
                                         isEmailAvailable: json["email"] as? Bool ?? false,
                                         isPhoneAvailable: json["msisdn"] as? Bool ?? false)
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
    
    /// Регистрирует аккаунт и возвращает его Matrix ID; войти нужно обычным паролем.
    func register(code: String, username: String, password: String, sid: String?) async throws(NyutagInviteError) -> String {
        var body = ["code": code, "username": username, "password": password]
        body["sid"] = sid
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
    
    // MARK: - Transport
    
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

struct NyutagInvite: Equatable, Sendable {
    /// Код вида `XXXX-XXXX`.
    let code: String
    let expiresAt: Date?
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
