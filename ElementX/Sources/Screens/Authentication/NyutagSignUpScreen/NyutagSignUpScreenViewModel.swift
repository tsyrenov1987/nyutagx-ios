//
// Нютаг (форк Element X iOS) — регистрация в одну форму: имя и ник, телефон, почта, пароль (и код приглашения,
// если он нужен); затем код из письма, если сервер требует подтверждённую почту; затем обычный вход паролем.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import SwiftUI

typealias NyutagSignUpScreenViewModelType = StateStoreViewModelV2<NyutagSignUpScreenViewState, NyutagSignUpScreenViewAction>

class NyutagSignUpScreenViewModel: NyutagSignUpScreenViewModelType {
    private let authenticationService: AuthenticationServiceProtocol
    private let serverNameOrBaseURL: String
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let invites: NyutagInvitesService

    private let actionsSubject: PassthroughSubject<NyutagSignUpScreenViewModelAction, Never> = .init()
    var actions: AnyPublisher<NyutagSignUpScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    @CancellableTask private var resendTimerTask: Task<Void, Never>?
    @CancellableTask private var checkTask: Task<Void, Never>?

    init(authenticationService: AuthenticationServiceProtocol,
         serverNameOrBaseURL: String,
         userIndicatorController: UserIndicatorControllerProtocol,
         initialCode: String = "",
         invites: NyutagInvitesService = .shared) {
        self.authenticationService = authenticationService
        self.serverNameOrBaseURL = serverNameOrBaseURL
        self.userIndicatorController = userIndicatorController
        self.invites = invites
        var initialState = NyutagSignUpScreenViewState()
        initialState.bindings.code = NyutagInviteCode.format(initialCode)
        initialState.hasInitialCode = !initialState.bindings.code.isEmpty
        super.init(initialViewState: initialState)

        Task { await loadConfiguration() }
        // Код пришёл из ссылки-приглашения — проверяем сразу, как при вводе вручную.
        if state.bindings.code.count == NyutagSignUpScreenViewState.codeLength {
            checkTask = Task { await checkCode() }
        }
    }

    override func process(viewAction: NyutagSignUpScreenViewAction) {
        switch viewAction {
        case .back:
            goBack()
        case .next:
            next()
        case .resendCode:
            guard state.step == .verify, state.resendIn == 0, !state.isBusy else { return }
            state.bindings.verifyCode = ""
            checkTask = Task {
                state.isBusy = true
                defer { state.isBusy = false }
                _ = await sendVerification()
            }
        case .editUsername:
            state.bindings.username = state.username
            state.bindings.isEditingUsername = true
            clearError()
        case .codeChanged:
            state.isCodeValid = false
            state.inviter = nil
            clearError()
            // Как в Telegram: код проверяется сам, как только введён целиком.
            if state.bindings.code.count == NyutagSignUpScreenViewState.codeLength {
                checkTask = Task { await checkCode() }
            }
        case .contactChanged:
            state.verification = nil
            state.isContactVerified = false
            state.bindings.verifyCode = ""
            clearError()
        case .verifyCodeChanged:
            clearError()
            if state.bindings.verifyCode.count == NyutagSignUpScreenViewState.verifyCodeLength, !state.isBusy {
                checkTask = Task { await checkVerification() }
            }
        case .phoneChanged:
            state.checkedPhone = nil
            clearError()
        case .inputChanged:
            clearError()
        }
    }

    // MARK: - Steps

    private func goBack() {
        guard state.step == .verify else {
            actionsSubject.send(.cancel)
            return
        }
        checkTask = nil
        state.isBusy = false
        clearError()
        withAnimation { state.step = .form }
    }

    private func next() {
        guard state.canContinue else { return }
        switch state.step {
        case .form:
            checkTask = Task { await submitForm() }
        case .verify:
            checkTask = Task { await checkVerification() }
        }
    }

    private func clearError() {
        state.errorMessage = nil
        state.errorField = nil
    }

    private func fail(_ field: NyutagSignUpField, _ errcode: String) {
        state.errorMessage = NyutagL10n.inviteError(errcode)
        state.errorField = field
    }

    private func loadConfiguration() async {
        guard state.configuration == nil, let configuration = try? await invites.signUpConfiguration() else { return }
        state.configuration = configuration
    }

    /// Кнопка «Создать аккаунт»: проверки по очереди, затем код из письма (если нужен) или сразу регистрация.
    private func submitForm() async {
        state.isBusy = true
        clearError()
        defer { state.isBusy = false }
        guard await checkForm() else { return }
        let needsContact = state.contactMedium != nil && !state.bindings.contact.trimmingCharacters(in: .whitespaces).isEmpty && !state.isContactVerified
        if needsContact {
            if await sendVerification() {
                withAnimation { state.step = .verify }
            }
            return
        }
        await createAccount()
    }

    /// Код приглашения, ник, телефон — по очереди; первая ошибка останавливает и подсвечивает своё поле.
    private func checkForm() async -> Bool {
        if state.configuration == nil {
            await loadConfiguration()
            guard state.configuration != nil else {
                fail(.password, NyutagInviteError.network)
                return false
            }
        }
        if state.showsCode, !state.isCodeValid {
            do throws(NyutagInviteError) {
                state.inviter = try await invites.checkInvite(code: state.bindings.code)
                state.isCodeValid = true
            } catch {
                fail(.code, error.errcode)
                return false
            }
        }
        let username = state.username
        if state.checkedUsername != username {
            do throws(NyutagInviteError) {
                try await invites.checkUsername(username)
                state.checkedUsername = username
            } catch {
                fail(state.bindings.isEditingUsername ? .username : .name, error.errcode)
                if !state.bindings.isEditingUsername, error.errcode != NyutagInviteError.network {
                    // Ник из имени занят или не подходит — даём поправить его самому.
                    state.bindings.username = username
                    state.bindings.isEditingUsername = true
                    state.errorField = .username
                }
                return false
            }
        }
        if state.showsPhone, state.checkedPhone == nil {
            do throws(NyutagInviteError) {
                state.checkedPhone = try await invites.checkPhone(state.bindings.phone.trimmingCharacters(in: .whitespaces),
                                                                 inviteCode: state.bindings.code)
            } catch {
                fail(.phone, error.errcode)
                return false
            }
        }
        return true
    }

    private func checkCode() async {
        let code = state.bindings.code
        state.isBusy = true
        defer { state.isBusy = false }
        do throws(NyutagInviteError) {
            let inviter = try await invites.checkInvite(code: code)
            guard !Task.isCancelled, state.bindings.code == code else { return }
            state.inviter = inviter
            state.isCodeValid = true
        } catch {
            guard !Task.isCancelled, state.bindings.code == code else { return }
            fail(.code, error.errcode)
        }
    }

    private func sendVerification() async -> Bool {
        guard let medium = state.contactMedium else { return false }
        do throws(NyutagInviteError) {
            let verification = try await invites.startVerification(medium: medium,
                                                                   address: state.bindings.contact.trimmingCharacters(in: .whitespaces),
                                                                   inviteCode: state.bindings.code)
            state.verification = verification
            startResendTimer(seconds: verification.resendAfter)
            return true
        } catch {
            fail(.contact, error.errcode)
            return false
        }
    }

    private func checkVerification() async {
        guard let verification = state.verification else { return }
        state.isBusy = true
        clearError()
        defer { state.isBusy = false }
        do throws(NyutagInviteError) {
            try await invites.checkVerification(sid: verification.sid, token: state.bindings.verifyCode)
            state.isContactVerified = true
            await createAccount()
        } catch {
            fail(.verifyCode, error.errcode)
        }
    }

    private func startResendTimer(seconds: Int) {
        state.resendIn = seconds
        resendTimerTask = Task { [weak self] in
            while let self, state.resendIn > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                state.resendIn -= 1
            }
        }
    }

    private func createAccount() async {
        let username = state.username
        let password = state.bindings.password
        userIndicatorController.submitIndicator(UserIndicator(id: Self.loadingIndicatorID, type: .modal, title: NyutagL10n.signUpCreating, persistent: true))
        defer { userIndicatorController.retractIndicatorWithId(Self.loadingIndicatorID) }

        if state.registeredUserID == nil {
            do throws(NyutagInviteError) {
                state.registeredUserID = try await invites.register(code: state.bindings.code,
                                                                    username: username,
                                                                    password: password,
                                                                    sid: state.isContactVerified ? state.verification?.sid : nil,
                                                                    phone: state.showsPhone ? state.checkedPhone : nil)
            } catch {
                fail(Self.registerErrorField(error.errcode, step: state.step), error.errcode)
                return
            }
        }

        // Аккаунт создан: дальше обычный вход тем же паролем, как с экрана «Войти».
        guard case .success = await authenticationService.configure(for: serverNameOrBaseURL, flow: .login),
              case .success(let userSession) = await authenticationService.login(username: username,
                                                                                password: password,
                                                                                initialDeviceName: UIDevice.current.initialDeviceName,
                                                                                deviceID: nil) else {
            MXLog.warning("Nyutag: sign-in after registration failed")
            state.errorMessage = NyutagL10n.signUpLoginAfterRegisterFailed
            state.errorField = state.step == .verify ? .verifyCode : .password
            return
        }

        let displayName = state.bindings.displayName.trimmingCharacters(in: .whitespaces)
        if case .failure(let error) = await userSession.clientProxy.setUserDisplayName(displayName) {
            MXLog.warning("Nyutag: display name not set after registration: \(error)")
        }
        actionsSubject.send(.signedIn(userSession))
    }

    /// Под каким полем показать отказ сервера при регистрации.
    private static func registerErrorField(_ errcode: String, step: NyutagSignUpStep) -> NyutagSignUpField {
        switch errcode {
        case "NYUTAG_UNKNOWN_CODE", "NYUTAG_CODE_USED", "NYUTAG_CODE_EXPIRED", "NYUTAG_BAD_CODE": .code
        case "M_USER_IN_USE", "M_INVALID_USERNAME": .username
        case "M_WEAK_PASSWORD": .password
        case "NYUTAG_CONTACT_IN_USE", "NYUTAG_BAD_CONTACT": .contact
        default: step == .verify ? .verifyCode : .password
        }
    }

    private static let loadingIndicatorID = "\(NyutagSignUpScreenViewModel.self)-Loading"
}
