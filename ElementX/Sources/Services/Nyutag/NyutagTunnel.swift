//
// Нютаг (форк Element X iOS) — транспорт «Кильватер» под Rust SDK.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import FarvaterCore
import Foundation
import Network
import Synchronization

/// farvater-core (Go) держит SOCKS5 на 127.0.0.1 с одноразовым логином и паролем и везёт каждый поток в kilvaterd на входе,
/// оттуда по stream-релею и WireGuard в ядро. SDK ходит только через этот SOCKS (`socks5h`: имя ядра разрешает вход,
/// публичного DNS у него нет) и доверяет только нашему CA.
nonisolated enum NyutagTunnel {
    static let serverName = "nyutag.chat"
    static let homeserverURL = "https://core.nyutag.chat:6167"
    static let homeserverHost = "core.nyutag.chat"
    static let homeserverPort = 6167

    // swiftlint:disable:next line_length
    /// Nyutag Private CA 1 (P-256, до 2036-10-08), DER. Публичная часть, секрета нет.
    static let caDER = Data(base64Encoded: "MIIBwjCCAWmgAwIBAgIUdESbmTDNd3kdFjE1CO728DfK9mIwCgYIKoZIzj0EAwIwLzEcMBoGA1UEAwwTTnl1dGFnIFByaXZhdGUgQ0EgMTEPMA0GA1UECgwGTnl1dGFnMB4XDTI2MTAxMTAyMTExMFoXDTM2MTAwODAyMTExMFowLzEcMBoGA1UEAwwTTnl1dGFnIFByaXZhdGUgQ0EgMTEPMA0GA1UECgwGTnl1dGFnMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAETor1VmEXfZjHEwb3tN4+7DyeMoYzla+26gWWrryNsukaQWJDKCQIZ9Xss7w9JdT6MgbzeHTOhpp7BS9JUhup9aNjMGEwHQYDVR0OBBYEFD8k/5gpRZdzsql1EE4ibo6gzi+wMB8GA1UdIwQYMBaAFD8k/5gpRZdzsql1EE4ibo6gzi+wMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMCA0cAMEQCIA/jaEWYsLV9gIlj3x3eylQl9rhllpbGYntQlUGl9q3LAiA3lLol4Znkn0ZgIpEIFGu+D+0Mt/kAVjPkv7TN6GASeQ==")! // swiftlint:disable:this force_unwrapping

    /// Наш CA как `SecCertificate` — якорь для URLSession и WKWebView.
    static let caCertificate = SecCertificateCreateWithData(nil, caDER as CFData)! // swiftlint:disable:this force_unwrapping

    /// Путь: kilvaterd de3:8080 с ключом Нютага (свой, не ключ флота Farvater).
    private static let catalogue = "kilvater://REDACTED-OLD-NYUTAG-KEY@188.245.11.63:8080?sni=kv.assetnorth.org&fp=chrome&path=%2Fconnect#de3-kilvater-8080"

    private static let state = Mutex(State())

    private struct State {
        var port = 0
        var network = "cell"
        var monitor: NWPathMonitor?
    }

    /// Адрес и учётка SOCKS на loopback.
    struct Endpoint: Equatable {
        let port: Int
        let user: String
        let password: String
    }
    
    /// Адрес и учётка поднятого SOCKS; `nil`, если ядро не поднялось (тогда SDK упрётся в закрытый порт входа).
    static var endpoint: Endpoint? {
        guard let port = ensureRunning() else { return nil }
        return Endpoint(port: port, user: MobileSocksUser(), password: MobileSocksPass())
    }

    /// URL SOCKS-прокси для reqwest: `socks5h://user:pass@127.0.0.1:port`.
    static func proxyURL() -> String? {
        guard let endpoint else { return nil }
        return "socks5h://\(endpoint.user):\(endpoint.password)@127.0.0.1:\(endpoint.port)"
    }

    /// Поднимает ядро один раз на процесс и возвращает порт SOCKS.
    private static func ensureRunning() -> Int? {
        state.withLock { state in
            if MobileRunning(), state.port != 0 { return state.port }
            startMonitorIfNeeded(&state)
            MobileSetMemoryFile(memoryFileURL.path(percentEncoded: false))
            guard let port = start(network: state.network) else { return nil }
            state.port = port
            MXLog.info("Nyutag tunnel listening on 127.0.0.1:\(port)")
            return port
        }
    }

    /// Случайный порт на loopback; повтор, если порт занят.
    private static func start(network: String) -> Int? {
        for _ in 0..<5 {
            let port = Int.random(in: 20000..<60000)
            var error: NSError?
            if MobileStart(catalogue, port, network, &error) { return port }
            guard let error, error.localizedDescription.contains("address already in use") else {
                MXLog.error("Nyutag tunnel failed to start: \(error?.localizedDescription ?? "unknown")")
                return nil
            }
        }
        MXLog.error("Nyutag tunnel failed to start: no free port")
        return nil
    }

    /// Сообщает ядру о смене сети (Wi-Fi ↔ сотовая), без перезапуска туннеля — как в Farvater.
    private static func startMonitorIfNeeded(_ state: inout State) {
        guard state.monitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            let network = Self.network(of: path)
            let changed = Self.state.withLock { state in
                defer { state.network = network }
                return state.network != network
            }
            if changed, MobileRunning() { MobileSetNetwork(network) }
        }
        monitor.start(queue: DispatchQueue(label: "chat.nyutag.tunnel.path"))
        state.network = network(of: monitor.currentPath)
        state.monitor = monitor
    }

    private static func network(of path: NWPath) -> String {
        if path.usesInterfaceType(.wifi) { return "wifi" }
        if path.usesInterfaceType(.wiredEthernet) { return "wired" }
        return "cell"
    }

    /// Что ядро выучило про сети; хранится в Application Support и не попадает в бэкап.
    private static var memoryFileURL: URL {
        var directory = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directory.setResourceValues(values)
        return directory.appending(path: "nyutag-core-memory.json")
    }
}
