//
// Нютаг (форк Element X iOS) — регистрация по приглашению, по шагам.
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
        super.init(initialViewState: initialState)
        
        Task { await loadConfiguration() }
        // Код пришёл из ссылки-приглашения — проверяем сразу, как при вводе вручную.
        if state.bindings.code.count == NyutagSignUpScreenViewState.codeLength {
            checkTask = Task { await checkCode(advanceOnSuccess: false) }
        }
    }
    
    override func process(viewAction: NyutagSignUpScreenViewAction) {
        switch viewAction {
        case .back:
            goBack()
        case .next:
            next()
        case .skipContact:
            guard state.canSkipContact else { return }
            advance()
        case .resendCode:
            guard state.resendIn == 0, !state.isBusy else { return }
            state.bindings.verifyCode = ""
            checkTask = Task { await sendVerification() }
        case .editUsername:
            state.bindings.username = state.username
            state.bindings.isEditingUsername = true
            state.errorMessage = nil
        case .codeChanged:
            let formatted = state.bindings.code
            state.isCodeValid = false
            state.inviter = nil
            state.errorMessage = nil
            // Как в Telegram: код проверяется сам, как только введён целиком.
            if formatted.count == NyutagSignUpScreenViewState.codeLength {
                checkTask = Task { await checkCode(advanceOnSuccess: false) }
            }
        case .contactChanged:
            state.verification = nil
            state.isContactVerified = false
            state.bindings.verifyCode = ""
            state.errorMessage = nil
        case .verifyCodeChanged:
            let digits = state.bindings.verifyCode
            state.errorMessage = nil
            if digits.count == NyutagSignUpScreenViewState.verifyCodeLength, !state.isBusy {
                checkTask = Task { await checkVerification() }
            }
        case .phoneChanged:
            state.checkedPhone = nil
            state.errorMessage = nil
        case .inputChanged:
            state.errorMessage = nil
        }
    }
    
    // MARK: - Steps
    
    private func goBack() {
        guard let index = state.steps.firstIndex(of: state.step), index > 0 else {
            actionsSubject.send(.cancel)
            return
        }
        checkTask = nil
        state.isBusy = false
        state.errorMessage = nil
        withAnimation { state.step = state.steps[index - 1] }
    }
    
    private func advance() {
        guard let index = state.steps.firstIndex(of: state.step), index + 1 < state.steps.count else { return }
        state.errorMessage = nil
        withAnimation { state.step = state.steps[index + 1] }
    }
    
    private func next() {
        guard state.canContinue else { return }
        switch state.step {
        case .code:
            if state.isCodeValid {
                Task { await advanceFromCode() }
            } else {
                checkTask = Task { await checkCode(advanceOnSuccess: true) }
            }
        case .contact:
            if state.verification == nil {
                checkTask = Task { await sendVerification() }
            } else {
                checkTask = Task { await checkVerification() }
            }
        case .phone:
            if state.checkedPhone != nil {
                advance()
            } else {
                checkTask = Task { await checkPhone() }
            }
        case .name:
            checkTask = Task { await checkUsername() }
        case .password:
            Task { await createAccount() }
        }
    }
    
    private func loadConfiguration() async {
        guard state.configuration == nil, let configuration = try? await invites.signUpConfiguration() else { return }
        state.configuration = configuration
        let hasContact = configuration.isPhoneAvailable || configuration.isEmailAvailable
        // Телефон без SMS — свой шаг: номер вводится без кода, по нему человека находят друзья.
        let hasPhoneStep = configuration.requiresPhone && configuration.isPhoneUnverified
        state.steps = [.code, hasContact ? .contact : nil, hasPhoneStep ? .phone : nil, .name, .password].compactMap(\.self)
        if hasContact {
            state.bindings.medium = state.availableMedia.first ?? .email
        }
    }
    
    private func checkPhone() async {
        let phone = state.bindings.phone
        state.isBusy = true
        defer { state.isBusy = false }
        do throws(NyutagInviteError) {
            let normalized = try await invites.checkPhone(phone.trimmingCharacters(in: .whitespaces), inviteCode: state.bindings.code)
            guard !Task.isCancelled, state.bindings.phone == phone else { return }
            state.checkedPhone = normalized
            advance()
        } catch {
            guard !Task.isCancelled, state.bindings.phone == phone else { return }
            state.errorMessage = NyutagL10n.inviteError(error.errcode)
        }
    }
    
    private func checkCode(advanceOnSuccess: Bool) async {
        let code = state.bindings.code
        state.isBusy = true
        defer { state.isBusy = false }
        do throws(NyutagInviteError) {
            let inviter = try await invites.checkInvite(code: code)
            guard !Task.isCancelled, state.bindings.code == code else { return }
            state.inviter = inviter
            state.isCodeValid = true
            if advanceOnSuccess {
                await advanceFromCode()
            }
        } catch {
            guard !Task.isCancelled, state.bindings.code == code else { return }
            state.errorMessage = NyutagL10n.inviteError(error.errcode)
        }
    }
    
    /// Шаг «Контакт» появляется только по настройкам сервера — без них дальше не идём.
    private func advanceFromCode() async {
        if state.configuration == nil {
            state.isBusy = true
            await loadConfiguration()
            state.isBusy = false
            guard state.configuration != nil else {
                state.errorMessage = NyutagL10n.inviteError(NyutagInviteError.network)
                return
            }
        }
        advance()
    }
    
    private func sendVerification() async {
        state.isBusy = true
        defer { state.isBusy = false }
        do throws(NyutagInviteError) {
            let verification = try await invites.startVerification(medium: state.bindings.medium,
                                                                   address: state.bindings.contact.trimmingCharacters(in: .whitespaces),
                                                                   inviteCode: state.bindings.code)
            state.verification = verification
            startResendTimer(seconds: verification.resendAfter)
        } catch {
            state.errorMessage = NyutagL10n.inviteError(error.errcode)
        }
    }
    
    private func checkVerification() async {
        guard let verification = state.verification else { return }
        state.isBusy = true
        defer { state.isBusy = false }
        do throws(NyutagInviteError) {
            try await invites.checkVerification(sid: verification.sid, token: state.bindings.verifyCode)
            state.isContactVerified = true
            advance()
        } catch {
            state.errorMessage = NyutagL10n.inviteError(error.errcode)
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
    
    private func checkUsername() async {
        let username = state.username
        state.isBusy = true
        defer { state.isBusy = false }
        do throws(NyutagInviteError) {
            try await invites.checkUsername(username)
            guard state.username == username else { return }
            advance()
        } catch {
            guard state.username == username else { return }
            state.errorMessage = NyutagL10n.inviteError(error.errcode)
            if !state.bindings.isEditingUsername, error.errcode != NyutagInviteError.network {
                // Ник из имени занят или не подходит — даём поправить его самому.
                state.bindings.username = username
                state.bindings.isEditingUsername = true
            }
        }
    }
    
    private func createAccount() async {
        let username = state.username
        let password = state.bindings.password
        state.isBusy = true
        userIndicatorController.submitIndicator(UserIndicator(id: Self.loadingIndicatorID, type: .modal, title: NyutagL10n.signUpCreating, persistent: true))
        defer {
            state.isBusy = false
            userIndicatorController.retractIndicatorWithId(Self.loadingIndicatorID)
        }
        
        if state.registeredUserID == nil {
            do throws(NyutagInviteError) {
                state.registeredUserID = try await invites.register(code: state.bindings.code,
                                                                    username: username,
                                                                    password: password,
                                                                    sid: state.isContactVerified ? state.verification?.sid : nil,
                                                                    phone: state.steps.contains(.phone) ? state.checkedPhone : nil)
            } catch {
                state.errorMessage = NyutagL10n.inviteError(error.errcode)
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
            return
        }
        
        let displayName = state.bindings.displayName.trimmingCharacters(in: .whitespaces)
        if case .failure(let error) = await userSession.clientProxy.setUserDisplayName(displayName) {
            MXLog.warning("Nyutag: display name not set after registration: \(error)")
        }
        actionsSubject.send(.signedIn(userSession))
    }
    
    private static let loadingIndicatorID = "\(NyutagSignUpScreenViewModel.self)-Loading"
}
