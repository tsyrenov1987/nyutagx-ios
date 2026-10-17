//
// Нютаг — ключи шифрования под паролем аккаунта, чтобы переписка переживала переустановку, как в Telegram.
//
// Element X держит ключи комнат в бэкапе на сервере, а ключ от бэкапа и ключи личности — в хранилище секретов,
// запертом «ключом восстановления». Люди его не сохраняют и после переустановки остаются без переписки.
// Здесь хранилище запирается паролем аккаунта: при регистрации заводим его, при входе на новом устройстве открываем
// тем же паролем — человек просто входит и видит историю. Сервер и так получает пароль при входе, поэтому защита
// от перехвата и от утечки базы остаётся, а от самого сервера — нет; для закрытого ядра Нютага это осознанный выбор.
// Зеркало Android: NyutagPasswordRecovery.kt.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import Foundation

enum NyutagPasswordRecovery {
    /// Сколько ждём, пока SDK после первого синка поймёт, есть ли на сервере хранилище секретов.
    private static let settleTimeout: Duration = .seconds(30)

    /// Сколько ждём подтверждения устройства после открытия хранилища, чтобы экран «Подтвердите личность» не мигал.
    private static let verifiedTimeout: Duration = .seconds(10)

    /// Ожидание, пока человек откроет хранилище старым ключом восстановления, чтобы перезапереть его паролем.
    private static var pendingRelock: Task<Void, Never>?

    /// Сразу после входа паролем, пока сессия создана, а её экранов ещё нет. Пароль в лог не попадает.
    /// Хранилища нет — заводим его под паролем. Есть, но секретов на устройстве нет — открываем паролем.
    /// Пароль не подходит (сменён через «Забыли пароль?» или хранилище заперто старым ключом восстановления) — остаётся
    /// обычный путь Element X: другое устройство, ключ восстановления или сброс личности, см. `afterIdentityReset`.
    static func afterLogin(clientProxy: ClientProxyProtocol, password: String) async {
        let backup = clientProxy.secureBackupController
        guard let state = await settledState(of: backup) else {
            MXLog.warning("Nyutag recovery: state still unknown after \(settleTimeout)")
            return
        }

        switch state {
        case .enabled:
            MXLog.info("Nyutag recovery: already enabled on this device")
        case .incomplete:
            switch await backup.confirmRecoveryKey(password) {
            case .success:
                MXLog.info("Nyutag recovery: key store opened with the account password")
                await waitUntilVerified(clientProxy)
            case .failure(let error):
                MXLog.warning("Nyutag recovery: the account password does not open the key store (\(error))")
                relockWhenOpened(backup, password: password)
            }
        case .disabled:
            // Без подтверждённого устройства SDK завёл бы новую личность вместо той, что уже есть у аккаунта.
            guard clientProxy.verificationStatePublisher.value == .verified else {
                MXLog.warning("Nyutag recovery: device is not verified, leaving the key store to the usual flow")
                return
            }
            await enable(backup, password: password)
        case .unknown, .settingUp:
            break
        }
    }

    /// После сброса личности паролем хранилище пустое, а устройство подтверждено — заводим хранилище тем же паролем.
    static func afterIdentityReset(secureBackupController backup: SecureBackupControllerProtocol, password: String) async {
        // Хранилище заводим сами — перезапирать после открытия ключом уже нечего.
        pendingRelock?.cancel()
        pendingRelock = nil
        guard await settledState(of: backup) == .disabled else {
            MXLog.warning("Nyutag recovery: key store not empty after the identity reset, leaving it")
            return
        }
        await enable(backup, password: password)
    }

    // MARK: - Private

    private static func settledState(of backup: SecureBackupControllerProtocol) async -> SecureBackupRecoveryState? {
        await first(of: backup.recoveryState, timeout: settleTimeout) { state in
            state == .enabled || state == .disabled || state == .incomplete
        }
    }

    /// Пароль не подошёл: хранилище заперто старым ключом восстановления (аккаунт завели до перевода на пароль).
    /// Как только человек откроет его ключом, перезапираем паролем: в состоянии `.enabled` SDK при `enableRecovery`
    /// лишь ротирует ключ хранилища. Так старые аккаунты переезжают на пароль сами, по одному разу, без отдельного экрана.
    /// Ждём до конца сессии; новый вход или сброс личности отменяют ожидание.
    private static func relockWhenOpened(_ backup: SecureBackupControllerProtocol, password: String) {
        pendingRelock?.cancel()
        pendingRelock = Task {
            for await state in backup.recoveryState.values {
                guard case .enabled = state else { continue }
                MXLog.info("Nyutag recovery: key store opened with a recovery key, re-locking it under the account password")
                await enable(backup, password: password)
                return
            }
        }
    }

    private static func enable(_ backup: SecureBackupControllerProtocol, password: String) async {
        switch await backup.generateRecoveryKey(withPassphrase: password) {
        case .success:
            MXLog.info("Nyutag recovery: key store set up under the account password")
        case .failure(let error):
            MXLog.warning("Nyutag recovery: setting up the key store failed (\(error))")
        }
    }

    private static func waitUntilVerified(_ clientProxy: ClientProxyProtocol) async {
        // Сравнение по образцу: Equatable у SessionVerificationState привязан к главному актору, а условие вызывается вне его.
        let verified = await first(of: clientProxy.verificationStatePublisher, timeout: verifiedTimeout) { state in
            if case .verified = state { return true }
            return false
        }
        if verified == nil {
            MXLog.warning("Nyutag recovery: device still not verified after \(verifiedTimeout)")
        }
    }

    /// Первое значение издателя, подходящее под условие, или nil по истечении таймаута.
    private static func first<Output: Sendable>(of publisher: CurrentValuePublisher<Output, Never>,
                                                timeout: Duration,
                                                where predicate: @escaping @Sendable (Output) -> Bool) async -> Output? {
        await withTaskGroup(of: Output?.self) { group in
            group.addTask {
                for await value in publisher.values where predicate(value) {
                    return value
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }
}
