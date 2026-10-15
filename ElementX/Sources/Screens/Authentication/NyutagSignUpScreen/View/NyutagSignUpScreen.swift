//
// Нютаг (форк Element X iOS) — регистрация: одна форма (имя, телефон, почта, пароль; код приглашения, если нужен)
// и, если сервер требует подтверждённую почту, второй экран с кодом из письма.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

struct NyutagSignUpScreen: View {
    @Bindable var context: NyutagSignUpScreenViewModel.Context

    private enum Field: Hashable {
        case code, displayName, username, phone, contact, password, verifyCode
    }

    @FocusState private var focus: Field?

    private var state: NyutagSignUpScreenViewState {
        context.viewState
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
                    .padding(.bottom, 28)

                Group {
                    switch state.step {
                    case .form: form
                    case .verify: verifyStep
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                .id(state.step)
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
        .onChange(of: context.verifyCode) { context.send(viewAction: .verifyCodeChanged) }
        .onChange(of: context.phone) { context.send(viewAction: .phoneChanged) }
        .onChange(of: context.displayName) { context.send(viewAction: .inputChanged) }
        .onChange(of: context.username) { context.send(viewAction: .inputChanged) }
        .onChange(of: context.password) { context.send(viewAction: .inputChanged) }
    }

    // MARK: - Common

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: state.step == .form ? "person.fill" : "envelope.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color(NyutagBrand.blue))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 72, height: 72)
                .background(Color(NyutagBrand.blueSubtle), in: Circle())
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

    private var title: String {
        switch state.step {
        case .form: NyutagL10n.signUpTitle
        case .verify: state.contactMedium == .phone ? NyutagL10n.contactCodeSMS : NyutagL10n.contactCodeEmail
        }
    }

    private var subtitle: String {
        switch state.step {
        case .form: NyutagL10n.signUpFormSubtitle
        case .verify: NyutagL10n.signUpVerifySubtitle(context.contact.trimmingCharacters(in: .whitespaces))
        }
    }

    private var continueButton: some View {
        Button { context.send(viewAction: .next) } label: {
            ZStack {
                Text(state.step == .form ? NyutagL10n.signUpSubmit : L10n.actionContinue).opacity(state.isBusy ? 0 : 1)
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

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button { context.send(viewAction: .back) } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
            }
            .accessibilityLabel(L10n.actionBack)
        }
    }

    private func focusFirstField(of step: NyutagSignUpStep) {
        let field: Field = switch step {
        case .form: state.showsCode && context.code.isEmpty ? .code : .displayName
        case .verify: .verifyCode
        }
        // Поле появляется с анимацией перехода — фокус после неё, иначе клавиатура мигает.
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            focus = field
        }
    }

    private func fieldState(_ field: NyutagSignUpField) -> CompoundTextFieldStyle.State {
        state.error(for: field) == nil ? .default : .error
    }

    // MARK: - Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            if state.showsCode {
                codeField
            }

            nameField
            usernameLine

            if state.showsPhone {
                phoneField
            }

            if let medium = state.contactMedium {
                contactField(medium: medium)
            }

            passwordField
        }
    }

    private var nameField: some View {
        TextField(text: $context.displayName) {
            Text(NyutagL10n.signUpNameLabel).foregroundStyle(.compound.textSecondary)
        }
        .textFieldStyle(.compound(labelText: NyutagL10n.signUpNameLabel,
                                  footerText: state.error(for: .name) ?? NyutagL10n.signUpNameSubtitle,
                                  state: fieldState(.name)))
        .textContentType(.name)
        .textInputAutocapitalization(.words)
        .submitLabel(.next)
        .focused($focus, equals: .displayName)
        .onSubmit { focus = context.isEditingUsername ? .username : afterName }
        .accessibilityIdentifier("nyutagSignUp-name")
    }

    private var afterName: Field {
        if state.showsPhone { return .phone }
        return state.contactMedium != nil ? .contact : .password
    }

    /// Ник для входа: строкой под именем, по кнопке — отдельное поле.
    @ViewBuilder
    private var usernameLine: some View {
        if context.isEditingUsername {
            TextField(text: $context.username) {
                Text(NyutagL10n.signUpUsernameHint).foregroundStyle(.compound.textSecondary)
            }
            .textFieldStyle(.compound(labelText: NyutagL10n.signUpUsernameLabel,
                                      footerText: state.error(for: .username) ?? "@\(state.username):\(NyutagTunnel.serverName)",
                                      state: fieldState(.username)))
            .textContentType(.username)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .submitLabel(.next)
            .focused($focus, equals: .username)
            .onSubmit { focus = afterName }
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
            .padding(.top, -8)
        }
    }

    private var phoneField: some View {
        TextField(text: $context.phone) {
            Text(NyutagL10n.contactPhoneHint).foregroundStyle(.compound.textSecondary)
        }
        .textFieldStyle(.compound(labelText: NyutagL10n.contactPhone,
                                  footerText: state.error(for: .phone) ?? NyutagL10n.signUpPhoneSubtitle,
                                  state: fieldState(.phone)))
        .keyboardType(.phonePad)
        .textContentType(.telephoneNumber)
        .autocorrectionDisabled()
        .focused($focus, equals: .phone)
        .accessibilityIdentifier("nyutagSignUp-phone")
    }

    private func contactField(medium: NyutagContactMedium) -> some View {
        let isPhone = medium == .phone
        let label = isPhone ? NyutagL10n.contactPhone : NyutagL10n.contactEmail
        return TextField(text: $context.contact) {
            Text(isPhone ? NyutagL10n.contactPhoneHint : NyutagL10n.contactEmailHint)
                .foregroundStyle(.compound.textSecondary)
        }
        .textFieldStyle(.compound(labelText: state.isContactOptional ? "\(label) \(NyutagL10n.signUpOptional)" : label,
                                  footerText: state.error(for: .contact) ?? NyutagL10n.signUpContactSubtitle,
                                  state: fieldState(.contact)))
        .keyboardType(isPhone ? .phonePad : .emailAddress)
        .textContentType(isPhone ? .telephoneNumber : .emailAddress)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.next)
        .focused($focus, equals: .contact)
        .onSubmit { focus = .password }
        .accessibilityIdentifier("nyutagSignUp-contact")
    }

    private var passwordField: some View {
        VStack(spacing: 0) {
            // Ник рядом с паролем — так менеджер паролей сохранит пару целиком.
            TextField(text: .constant(state.username)) { EmptyView() }
                .textContentType(.username)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)

            SecureField(text: $context.password) {
                Text(NyutagL10n.signUpPasswordLabel).foregroundStyle(.compound.textSecondary)
            }
            .textFieldStyle(.compound(.plain(.secure(hideLabel: L10n.a11yHidePassword, showLabel: L10n.a11yShowPassword)),
                                      footerText: state.error(for: .password) ?? NyutagL10n.signUpPasswordSubtitle,
                                      state: fieldState(.password)))
            .textContentType(.newPassword)
            .submitLabel(.done)
            .focused($focus, equals: .password)
            .onSubmit { context.send(viewAction: .next) }
            .accessibilityIdentifier("nyutagSignUp-password")
        }
    }

    // MARK: - Code

    /// Формат `XXXX-XXXX` применяется прямо при вводе: правка текста через модель на каждый символ теряет быстрый ввод.
    private var codeBinding: Binding<String> {
        Binding { context.code } set: { context.code = NyutagInviteCode.format($0) }
    }

    private var codeField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NyutagL10n.signUpCodeLabel)
                .font(.compound.bodySMSemibold)
                .foregroundStyle(.compound.textSecondary)

            HStack(spacing: 12) {
                TextField(text: codeBinding) {
                    Text(verbatim: "XXXX-XXXX").foregroundStyle(.compound.textSecondary.opacity(0.5))
                }
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .textContentType(.oneTimeCode)
                .submitLabel(.next)
                .focused($focus, equals: .code)
                .onSubmit { focus = .displayName }
                .accessibilityLabel(NyutagL10n.signUpCodeLabel)
                .accessibilityIdentifier("nyutagSignUp-code")
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Color.compound.bgSubtleSecondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .trailing) { codeStatus.padding(.trailing, 16) }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(state.error(for: .code) != nil ? Color.compound.borderCriticalPrimary : .clear, lineWidth: 1.5)
            }

            if let error = state.error(for: .code) {
                Text(error)
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textCriticalPrimary)
            } else if let inviter = state.inviter, state.isCodeValid {
                Label(NyutagL10n.signUpInvitedBy(inviter.nyutagLocalpart), systemImage: "checkmark.seal.fill")
                    .font(.compound.bodySMSemibold)
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
        if state.isBusy, !state.isCodeValid {
            ProgressView()
        } else if state.isCodeValid {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.compound.iconSuccessPrimary)
        }
    }

    // MARK: - Verify

    private var verifyCodeBinding: Binding<String> {
        Binding { context.verifyCode } set: { context.verifyCode = String($0.filter(\.isNumber).prefix(NyutagSignUpScreenViewState.verifyCodeLength)) }
    }

    private var verifyStep: some View {
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
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(state.error(for: .verifyCode) != nil ? Color.compound.borderCriticalPrimary : .clear, lineWidth: 1.5)
            }
            .accessibilityLabel(title)
            .accessibilityIdentifier("nyutagSignUp-verifyCode")

            if let error = state.error(for: .verifyCode) {
                Text(error)
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textCriticalPrimary)
                    .accessibilityIdentifier("nyutagSignUp-error")
            }

            HStack {
                Spacer()
                if state.resendIn > 0 {
                    Text(NyutagL10n.contactResendIn(state.resendIn))
                        .font(.compound.bodySM)
                        .foregroundStyle(.compound.textSecondary)
                        .monospacedDigit()
                } else {
                    Button(NyutagL10n.contactResend) { context.send(viewAction: .resendCode) }
                        .font(.compound.bodyMDSemibold)
                        .tint(Color(NyutagBrand.blue))
                        .disabled(state.isBusy)
                }
                Spacer()
            }
            .padding(.top, 4)
        }
    }
}

private extension String {
    /// `@ivan:nyutag.chat` → `@ivan`.
    var nyutagLocalpart: String {
        split(separator: ":").first.map(String.init) ?? self
    }
}
