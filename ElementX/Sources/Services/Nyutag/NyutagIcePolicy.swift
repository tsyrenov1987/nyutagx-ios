//
// Нютаг — ICE-политика звонка: если UDP до SFU не ходит (зона белых списков), WebView сразу идёт через TURN,
// а не ждёт ~16 с провала прямых кандидатов. Зеркало Android `NyutagIcePolicy.kt`.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import Network

enum NyutagIcePolicy {
    /// coturn на nyutag-rtc: отвечает на STUN Binding по UDP. Нет ответа дважды = UDP до SFU мёртв.
    private static let stunHost = "2.31.27.66"
    private static let stunPort: UInt16 = 3478
    private static let attempts = 2
    private static let timeout: TimeInterval = 1.5
    private static let ttl: TimeInterval = 60

    private static var lastResult: (udpOK: Bool, at: Date)?

    /// `true` — UDP до SFU жив. Свежий результат (моложе TTL) переиспользуется.
    static func udpReachable() async -> Bool {
        if let last = lastResult, Date().timeIntervalSince(last.at) < ttl { return last.udpOK }
        let started = Date()
        var ok = false
        for _ in 0..<attempts where !ok {
            ok = await stunBinding()
        }
        lastResult = (ok, Date())
        MXLog.info("Nyutag ICE: UDP to SFU \(ok ? "alive" : "DEAD") in \(Int(Date().timeIntervalSince(started) * 1000)) ms")
        return ok
    }

    private static func stunBinding() async -> Bool {
        let transactionId = (0..<12).map { _ in UInt8.random(in: 0...255) }
        // Binding Request (тип 0x0001, длина 0), magic cookie, transaction id.
        let request: [UInt8] = [0x00, 0x01, 0x00, 0x00, 0x21, 0x12, 0xA4, 0x42] + transactionId

        let connection = NWConnection(host: NWEndpoint.Host(stunHost), port: NWEndpoint.Port(rawValue: stunPort)!, using: .udp)
        let payload = Data(request)
        let replies = AsyncStream<Bool> { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: payload, completion: .contentProcessed { error in
                        if error != nil { continuation.yield(false) }
                    })
                    connection.receiveMessage { data, _, _, _ in
                        guard let data, data.count >= 20 else { continuation.yield(false); return }
                        continuation.yield(Array(data[8..<20]) == transactionId)
                    }
                case .failed, .cancelled:
                    continuation.yield(false)
                default:
                    break
                }
            }
            connection.start(queue: DispatchQueue(label: "nyutag.ice.probe"))
        }
        let result = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await reply in replies { return reply }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
        connection.cancel()
        return result
    }

    /// Скрипт для WKUserScript (atDocumentStart): все RTCPeerConnection только через TURN.
    static let relayScript = """
    (function () {
      if (window.__nyutagIce) return;
      window.__nyutagIce = true;
      var Orig = window.RTCPeerConnection;
      if (!Orig) return;
      function patch(cfg) {
        var c = Object.assign({}, cfg || {});
        c.iceTransportPolicy = 'relay';
        console.log('nyutag: ICE policy relay (UDP to SFU is dead)');
        return c;
      }
      class Patched extends Orig {
        constructor(cfg, constraints) { super(patch(cfg), constraints); }
        setConfiguration(cfg) { return super.setConfiguration(patch(cfg)); }
      }
      window.RTCPeerConnection = Patched;
      window.webkitRTCPeerConnection = Patched;
    })();
    """
}
