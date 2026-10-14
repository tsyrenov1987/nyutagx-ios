//
// Нютаг (форк Element X iOS) — регистрация по приглашению, по шагам.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

struct NyutagSignUpScreen: View {
    @Bindable var context: NyutagSignUpScreenViewModel.Context
    
    private enum Field: Hashable {
        case code, contact, verifyCode, phone, displayName, username, password, passwordRepeat
    }
    
    @FocusState private var focus: Field?
    
    private var state: NyutagSignUpScreenViewState {
        context.viewState
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                progress
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                
                header
                    .padding(.bottom, 32)
                
                Group {
                    switch state.step {
                    case .code: codeStep
                    case .contact: contactStep
                    case .phone: phoneStep
                    case .name: nameStep
                    case .password: passwordStep
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                .id(state.step)
                
                if let errorMessage = state.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.compound.bodySM)
                        .foregroundStyle(.compound.textCriticalPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                        .accessibilityIdentifier("nyutagSignUp-error")
                }
            }
            .readableFrame()
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) { continueButton }
        .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .onAppear { focusFirstField(of: state.step) }
        .onChange(of: state.step) { _, step in focusFirstField(of: step) }
        .onChange(of: context.code) { context.send(viewAction: .codeChanged) }
        .onChange(of: context.contact) { context.send(viewAction: .contactChanged) }
        .onChange(of: context.medium) { context.send(viewAction: .contactChanged) }
        .onChange(of: context.verifyCode) { context.send(viewAction: .verifyCodeChanged) }
        .onChange(of: context.phone) { context.send(viewAction: .phoneChanged) }
        .onChange(of: context.displayName) { context.send(viewAction: .inputChanged) }
        .onChange(of: context.username) { context.send(viewAction: .inputChanged) }
        .onChange(of: context.password) { context.send(viewAction: .inputChanged) }
    }
    
    // MARK: - Common
    
    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(Array(state.steps.enumerated()), id: \.offset) { index, _ in
                Capsule()
                    .fill(index < state.stepNumber ? Color(NyutagBrand.blue) : Color.compound.bgSubtleSecondary)
                    .frame(height: 4)
            }
        }
        .animation(.easeInOut, value: state.stepNumber)
        .accessibilityElement()
        .accessibilityLabel(NyutagL10n.signUpStep(state.stepNumber, of: state.steps.count))
    }
    
    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: heroSymbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color(NyutagBrand.blue))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 84, height: 84)
                .background(Color(NyutagBrand.blueSubtle), in: Circle())
                .padding(.bottom, 4)
                .accessibilityHidden(true)
            
            Text(title)
                .font(.compound.headingMDBold)
                .foregroundStyle(.compound.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            
            Text(subtitle)
                .font(.compound.bodyMD)
                .foregroundStyle(.compound.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var heroSymbol: String {
        switch state.step {
        case .code: "envelope.open.fill"
        case .contact: context.medium == .phone ? "iphone.gen3" : "at"
        case .phone: "iphone.gen3"
        case .name: "person.fill"
        case .password: "lock.fill"
        }
    }
    
    private var title: String {
        switch state.step {
        case .code: NyutagL10n.signUpCodeTitle
        case .contact:
            if state.canSkipContact {
                NyutagL10n.signUpContactTitleOptional
            } else if state.availableMedia.count > 1 {
                NyutagL10n.signUpContactTitle
            } else {
                // Один способ (сейчас только почта) — называем его, а не «Телефон или e-mail».
                context.medium == .phone ? NyutagL10n.contactPhone : NyutagL10n.contactEmail
            }
        case .phone: NyutagL10n.contactPhone
        case .name: NyutagL10n.signUpNameTitle
        case .password: NyutagL10n.signUpPasswordTitle
        }
    }
    
    private var subtitle: String {
        switch state.step {
        case .code: NyutagL10n.signUpCodeSubtitle
        case .contact: NyutagL10n.signUpContactSubtitle
        case .phone: NyutagL10n.signUpPhoneSubtitle
        case .name: NyutagL10n.signUpNameSubtitle
        case .password: NyutagL10n.signUpPasswordSubtitle
        }
    }
    
    private var continueButton: some View {
        Button { context.send(viewAction: .next) } label: {
            ZStack {
                Text(continueTitle).opacity(state.isBusy ? 0 : 1)
                if state.isBusy {
                    ProgressView().tint(.compound.textOnSolidPrimary)
                }
            }
        }
        .buttonStyle(.compound(.primary))
        .disabled(!state.canContinue)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .readableFrame()
        .background(Color.compound.bgCanvasDefault.opacity(0.94).ignoresSafeArea())
        .accessibilityIdentifier("nyutagSignUp-continue")
    }
    
    private var continueTitle: String {
        switch state.step {
        case .contact where state.verification == nil: NyutagL10n.contactSendCode
        case .password: NyutagL10n.signUpSubmit
        default: L10n.actionContinue
        }
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button { context.send(viewAction: .back) } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
            }
            .accessibilityLabel(L10n.actionBack)
        }
        ToolbarItem(placement: .principal) {
            Text(NyutagL10n.signUpStep(state.stepNumber, of: state.steps.count))
                .font(.compound.bodySMSemibold)
                .foregroundStyle(.compound.textSecondary)
        }
        if state.step == .contact, state.canSkipContact {
            ToolbarItem(placement: .primaryAction) {
                Button(L10n.actionSkip) { context.send(viewAction: .skipContact) }
            }
        }
    }
    
    private func focusFirstField(of step: NyutagSignUpStep) {
        let field: Field = switch step {
        case .code: .code
        case .contact: state.verification == nil ? .contact : .verifyCode
        case .phone: .phone
        case .name: .displayName
        case .password: .password
        }
        // Поле появляется с анимацией перехода — фокус после неё, иначе клавиатура мигает.
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            focus = field
        }
    }
    
    // MARK: - Code
    
    /// Формат `XXXX-XXXX` применяется прямо при вводе: правка текста через модель на каждый символ теряет быстрый ввод.
    private var codeBinding: Binding<String> {
        Binding { context.code } set: { context.code = NyutagInviteCode.format($0) }
    }
    
    private var verifyCodeBinding: Binding<String> {
        Binding { context.verifyCode } set: { context.verifyCode = String($0.filter(\.isNumber).prefix(NyutagSignUpScreenViewState.verifyCodeLength)) }
    }
    
    private var codeStep: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                TextField(text: codeBinding) {
                    Text(verbatim: "XXXX-XXXX").foregroundStyle(.compound.textSecondary.opacity(0.5))
                }
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .textContentType(.oneTimeCode)
                .submitLabel(.continue)
                .focused($focus, equals: .code)
                .onSubmit { context.send(viewAction: .next) }
                .accessibilityLabel(NyutagL10n.signUpCodeLabel)
                .accessibilityIdentifier("nyutagSignUp-code")
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
            .background(Color.compound.bgSubtleSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .trailing) { codeStatus.padding(.trailing, 16) }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(state.errorMessage != nil ? Color.compound.borderCriticalPrimary : .clear, lineWidth: 1.5)
            }
            
            if let inviter = state.inviter, state.isCodeValid {
                Label(NyutagL10n.signUpInvitedBy(inviter.nyutagLocalpart), systemImage: "checkmark.seal.fill")
                    .font(.compound.bodyMDSemibold)
                    .foregroundStyle(.compound.textSuccessPrimary)
                    .transition(.opacity)
            } else if context.code.isEmpty {
                PasteButton(payloadType: String.self) { strings in
                    guard let text = strings.first else { return }
                    Task { @MainActor in context.code = NyutagInviteCode.format(text) }
                }
                .buttonBorderShape(.capsule)
                .labelStyle(.titleAndIcon)
                .tint(Color(NyutagBrand.blue))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.isCodeValid)
    }
    
    @ViewBuilder
    private var codeStatus: some View {
        if state.isBusy {
            ProgressView()
        } else if state.isCodeValid {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.compound.iconSuccessPrimary)
        }
    }
    
    // MARK: - Contact
    
    private var contactStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            if state.availableMedia.count > 1 {
                Picker(selection: $context.medium) {
                    Text(NyutagL10n.contactPhone).tag(NyutagContactMedium.phone)
                    Text(NyutagL10n.contactEmail).tag(NyutagContactMedium.email)
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .disabled(state.verification != nil)
            }
            
            TextField(text: $context.contact) {
                Text(context.medium == .phone ? NyutagL10n.contactPhoneHint : NyutagL10n.contactEmailHint)
                    .foregroundStyle(.compound.textSecondary)
            }
            .textFieldStyle(.compound(labelText: context.medium == .phone ? NyutagL10n.contactPhone : NyutagL10n.contactEmail))
            .keyboardType(context.medium == .phone ? .phonePad : .emailAddress)
            .textContentType(context.medium == .phone ? .telephoneNumber : .emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focus, equals: .contact)
            .onSubmit { context.send(viewAction: .next) }
            
            if state.verification != nil {
                VStack(alignment: .leading, spacing: 12) {
                    TextField(text: verifyCodeBinding) {
                        Text(verbatim: "000000").foregroundStyle(.compound.textSecondary.opacity(0.5))
                    }
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .kerning(8)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focus, equals: .verifyCode)
                    .frame(height: 64)
                    .background(Color.compound.bgSubtleSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityLabel(context.medium == .phone ? NyutagL10n.contactCodeSMS : NyutagL10n.contactCodeEmail)
                    
                    Text(context.medium == .phone ? NyutagL10n.contactCodeSMS : NyutagL10n.contactCodeEmail)
                        .font(.compound.bodySM)
                        .foregroundStyle(.compound.textSecondary)
                    
                    if state.resendIn > 0 {
                        Text(NyutagL10n.contactResendIn(state.resendIn))
                            .font(.compound.bodySM)
                            .foregroundStyle(.compound.textSecondary)
                            .monospacedDigit()
                    } else {
                        Button(NyutagL10n.contactResend) { context.send(viewAction: .resendCode) }
                            .font(.compound.bodyMDSemibold)
                            .tint(Color(NyutagBrand.blue))
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear { focus = .verifyCode }
            }
        }
        .animation(.easeInOut, value: state.verification)
    }
    
    // MARK: - Phone
    
    private var phoneStep: some View {
        TextField(text: $context.phone) {
            Text(NyutagL10n.contactPhoneHint)
                .foregroundStyle(.compound.textSecondary)
        }
        .textFieldStyle(.compound(labelText: NyutagL10n.contactPhone))
        .keyboardType(.phonePad)
        .textContentType(.telephoneNumber)
        .autocorrectionDisabled()
        .focused($focus, equals: .phone)
        .onSubmit { context.send(viewAction: .next) }
        .accessibilityIdentifier("nyutagSignUp-phone")
    }
    
    // MARK: - Name
    
    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(text: $context.displayName) {
                Text(NyutagL10n.signUpNameLabel).foregroundStyle(.compound.textSecondary)
            }
            .textFieldStyle(.compound())
            .textContentType(.name)
            .textInputAutocapitalization(.words)
            .submitLabel(.continue)
            .focused($focus, equals: .displayName)
            .onSubmit { context.send(viewAction: .next) }
            .accessibilityIdentifier("nyutagSignUp-name")
            
            if context.isEditingUsername {
                TextField(text: $context.username) {
                    Text(NyutagL10n.signUpUsernameHint).foregroundStyle(.compound.textSecondary)
                }
                .textFieldStyle(.compound(labelText: NyutagL10n.signUpUsernameLabel, footerText: "@\(state.username):\(NyutagTunnel.serverName)"))
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .focused($focus, equals: .username)
                .onSubmit { context.send(viewAction: .next) }
                .padding(.top, 8)
                .onAppear { focus = .username }
            } else if !state.username.isEmpty {
                HStack(spacing: 8) {
                    Text(NyutagL10n.signUpUsernameFooter("@\(state.username)"))
                        .font(.compound.bodySM)
                        .foregroundStyle(.compound.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    Button(NyutagL10n.signUpUsernameEdit) { context.send(viewAction: .editUsername) }
                        .font(.compound.bodySMSemibold)
                        .tint(Color(NyutagBrand.blue))
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Password
    
    private var passwordStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Ник рядом с паролем — так менеджер паролей сохранит пару целиком.
            TextField(text: .constant(state.username)) { EmptyView() }
                .textContentType(.username)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
            
            SecureField(text: $context.password) {
                Text(NyutagL10n.signUpPasswordLabel).foregroundStyle(.compound.textSecondary)
            }
            .textFieldStyle(.compound(.plain(.secure(hideLabel: L10n.a11yHidePassword, showLabel: L10n.a11yShowPassword))))
            .textContentType(.newPassword)
            .submitLabel(.next)
            .focused($focus, equals: .password)
            .onSubmit { focus = .passwordRepeat }
            .accessibilityIdentifier("nyutagSignUp-password")
            
            SecureField(text: $context.passwordRepeat) {
                Text(NyutagL10n.signUpPasswordRepeat).foregroundStyle(.compound.textSecondary)
            }
            .textFieldStyle(.compound(.plain(.secure(hideLabel: L10n.a11yHidePassword, showLabel: L10n.a11yShowPassword)),
                                      footerText: state.showsPasswordMismatch ? NyutagL10n.signUpPasswordMismatch : nil,
                                      state: state.showsPasswordMismatch ? .error : .default))
            .textContentType(.newPassword)
            .submitLabel(.done)
            .focused($focus, equals: .passwordRepeat)
            .onSubmit { context.send(viewAction: .next) }
            .accessibilityIdentifier("nyutagSignUp-passwordRepeat")
        }
    }
}

private extension String {
    /// `@ivan:nyutag.chat` → `@ivan`.
    var nyutagLocalpart: String {
        split(separator: ":").first.map(String.init) ?? self
    }
}
