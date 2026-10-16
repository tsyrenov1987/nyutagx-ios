//
// Нютаг (форк Element X iOS) — «Забыли пароль?»: код на почту аккаунта, новый пароль, вход.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

struct NyutagPasswordResetView: View {
    private enum Field { case email, code, password }

    /// Почта и новый пароль — экран входа подставляет их и входит сам.
    let onReset: (_ email: String, _ password: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: Field?

    @State private var email: String
    @State private var verification: NyutagVerification?
    @State private var code = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var resendIn = 0
    @State private var resendTask: Task<Void, Never>?

    private static let codeLength = 6
    private static let minPasswordLength = 8

    init(email: String, onReset: @escaping (_ email: String, _ password: String) -> Void) {
        _email = State(initialValue: email)
        self.onReset = onReset
    }

    var body: some View {
        ElementNavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if verification == nil {
                        emailStep
                    } else {
                        codeStep
                    }
                }
                .readableFrame()
                .padding(16)
            }
            .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
            .navigationTitle(NyutagL10n.passwordResetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.actionCancel) { dismiss() }
                }
            }
        }
        .onAppear { focus = .email }
        .onDisappear { resendTask?.cancel() }
    }

    // MARK: - Steps

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            TextField(text: $email) {
                Text(NyutagL10n.contactEmailHint).foregroundStyle(.compound.textSecondary)
            }
            .textFieldStyle(.compound(labelText: NyutagL10n.contactEmail,
                                      footerText: errorMessage ?? NyutagL10n.passwordResetSubtitle,
                                      state: errorMessage == nil ? .default : .error))
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.send)
            .focused($focus, equals: .email)
            .onSubmit(sendCode)
            .onChange(of: email) { errorMessage = nil }
            .accessibilityIdentifier("nyutagPasswordReset-email")

            Button(action: sendCode) {
                Text(isBusy ? NyutagL10n.contactSending : NyutagL10n.contactSendCode)
            }
            .buttonStyle(.compound(.primary))
            .disabled(trimmedEmail.isEmpty || isBusy)
            .accessibilityIdentifier("nyutagPasswordReset-sendCode")
        }
    }

    private var codeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(NyutagL10n.signUpVerifySubtitle(trimmedEmail))
                .font(.compound.bodyMD)
                .foregroundStyle(.compound.textSecondary)

            TextField(text: codeBinding) {
                Text(verbatim: "000000").foregroundStyle(.compound.textSecondary.opacity(0.5))
            }
            .font(.system(size: 28, weight: .semibold, design: .monospaced))
            .kerning(8)
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($focus, equals: .code)
            .frame(height: 64)
            .background(Color.compound.bgSubtleSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(errorMessage != nil ? Color.compound.borderCriticalPrimary : .clear, lineWidth: 1.5)
            }
            .accessibilityLabel(NyutagL10n.contactCodeEmail)
            .accessibilityIdentifier("nyutagPasswordReset-code")

            VStack(spacing: 0) {
                // Почта рядом с новым паролем — так менеджер паролей обновит сохранённую пару.
                TextField(text: .constant(trimmedEmail)) { EmptyView() }
                    .textContentType(.username)
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .accessibilityHidden(true)

                SecureField(text: $password) {
                    Text(NyutagL10n.passwordResetNew).foregroundStyle(.compound.textSecondary)
                }
                .textFieldStyle(.compound(.plain(.secure(hideLabel: L10n.a11yHidePassword, showLabel: L10n.a11yShowPassword))))
                .textContentType(.newPassword)
                .submitLabel(.done)
                .focused($focus, equals: .password)
                .onSubmit(reset)
                .accessibilityIdentifier("nyutagPasswordReset-password")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textCriticalPrimary)
                    .accessibilityIdentifier("nyutagPasswordReset-error")
            }

            Button(action: reset) {
                Text(NyutagL10n.passwordResetSubmit)
            }
            .buttonStyle(.compound(.primary))
            .disabled(!canReset)
            .accessibilityIdentifier("nyutagPasswordReset-submit")

            HStack(spacing: 0) {
                Spacer()
                if resendIn > 0 {
                    Text(NyutagL10n.contactResendIn(resendIn))
                        .font(.compound.bodySM)
                        .foregroundStyle(.compound.textSecondary)
                        .monospacedDigit()
                } else {
                    Button(NyutagL10n.contactResend, action: sendCode)
                        .font(.compound.bodyMDSemibold)
                        .tint(Color(NyutagBrand.blue))
                        .disabled(isBusy)
                }
                Spacer()
            }
        }
    }

    // MARK: - Actions

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var codeBinding: Binding<String> {
        Binding { code } set: {
            code = String($0.filter(\.isNumber).prefix(Self.codeLength))
            errorMessage = nil
            if code.count == Self.codeLength, password.isEmpty { focus = .password }
        }
    }

    private var canReset: Bool {
        !isBusy && code.count == Self.codeLength && password.count >= Self.minPasswordLength
    }

    private func sendCode() {
        guard !trimmedEmail.isEmpty, !isBusy else { return }
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            do throws(NyutagInviteError) {
                let verification = try await NyutagInvitesService.shared.startPasswordReset(address: trimmedEmail)
                self.verification = verification
                code = ""
                focus = .code
                startResendTimer(verification.resendAfter)
            } catch {
                errorMessage = NyutagL10n.inviteError(error.errcode)
            }
        }
    }

    private func reset() {
        guard canReset, let verification else { return }
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            do throws(NyutagInviteError) {
                _ = try await NyutagInvitesService.shared.resetPassword(sid: verification.sid, token: code, password: password)
                let email = trimmedEmail
                let password = password
                dismiss()
                onReset(email, password)
            } catch {
                errorMessage = NyutagL10n.inviteError(error.errcode)
                if error.errcode == NyutagInviteError.verifyWrong { focus = .code }
            }
        }
    }

    private func startResendTimer(_ seconds: Int) {
        resendTask?.cancel()
        resendIn = seconds
        resendTask = Task {
            while resendIn > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                resendIn -= 1
            }
        }
    }
}
