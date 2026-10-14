//
// Нютаг (форк Element X iOS) — поиск человека по номеру телефона: нашёлся — пишем ему,
// нет — приглашаем ссылкой (SMS, любой мессенджер) или QR-кодом.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Contacts
import ContactsUI
import CoreImage.CIFilterBuiltins
import MessageUI
import SwiftUI

@MainActor
final class NyutagFindByPhoneModel: ObservableObject, Identifiable {
    enum Search: Equatable {
        case idle
        case searching
        case found(UserProfile)
        case notFound
        case failed(String)
    }
    
    @Published var phone = "" {
        didSet {
            guard phone != oldValue else { return }
            search = .idle
            invite = invitesByPhone[Self.key(phone)]
            inviteError = nil
        }
    }
    
    @Published private(set) var search: Search = .idle
    @Published private(set) var invite: NyutagInvite?
    @Published private(set) var isCreatingInvite = false
    @Published private(set) var inviteError: String?
    /// Указан ли свой номер; nil — ещё не знаем.
    @Published private(set) var hasOwnPhone: Bool?
    @Published var ownPhone = ""
    @Published private(set) var isSavingOwnPhone = false
    @Published private(set) var ownPhoneError: String?
    
    let mediaProvider: MediaProviderProtocol
    private let clientProxy: ClientProxyProtocol
    private let invites: NyutagInvitesService
    /// Код одноразовый: один на номер, повторный поиск того же номера его не тратит.
    private var invitesByPhone: [String: NyutagInvite] = [:]
    private var searchTask: Task<Void, Never>?
    
    init(clientProxy: ClientProxyProtocol, mediaProvider: MediaProviderProtocol, invites: NyutagInvitesService = .shared) {
        self.clientProxy = clientProxy
        self.mediaProvider = mediaProvider
        self.invites = invites
        Task { await loadOwnPhone() }
    }
    
    var canSearch: Bool {
        phone.count(where: \.isNumber) >= Self.minPhoneDigits && search != .searching
    }
    
    var canSaveOwnPhone: Bool {
        ownPhone.count(where: \.isNumber) >= Self.minPhoneDigits && !isSavingOwnPhone
    }
    
    private var accessToken: String? {
        (clientProxy as? ClientProxy)?.nyutagAccessToken
    }
    
    func runSearch() {
        guard canSearch, let accessToken else { return }
        let query = phone.trimmingCharacters(in: .whitespaces)
        searchTask?.cancel()
        search = .searching
        searchTask = Task {
            do throws(NyutagInviteError) {
                let matches = try await invites.lookupPhones([query], accessToken: accessToken)
                guard !Task.isCancelled, phone.trimmingCharacters(in: .whitespaces) == query else { return }
                if let userID = matches.values.first {
                    let profile = (try? await clientProxy.profile(for: userID).get()) ?? UserProfile(userID: userID)
                    search = .found(profile)
                } else {
                    search = .notFound
                }
            } catch {
                guard !Task.isCancelled else { return }
                search = .failed(NyutagL10n.byPhoneError(error.errcode))
            }
        }
    }
    
    func pickedPhone(_ number: String) {
        phone = number
        runSearch()
    }
    
    func createInvite() {
        guard !isCreatingInvite, let accessToken else { return }
        let key = Self.key(phone)
        isCreatingInvite = true
        inviteError = nil
        Task {
            defer { isCreatingInvite = false }
            do throws(NyutagInviteError) {
                let invite = try await invites.createInvite(accessToken: accessToken)
                invitesByPhone[key] = invite
                if Self.key(phone) == key {
                    self.invite = invite
                }
            } catch {
                inviteError = NyutagL10n.byPhoneError(error.errcode)
            }
        }
    }
    
    func saveOwnPhone() {
        guard canSaveOwnPhone, let accessToken else { return }
        isSavingOwnPhone = true
        ownPhoneError = nil
        Task {
            defer { isSavingOwnPhone = false }
            do throws(NyutagInviteError) {
                try await invites.setPhone(ownPhone.trimmingCharacters(in: .whitespaces), accessToken: accessToken)
                hasOwnPhone = true
            } catch {
                ownPhoneError = NyutagL10n.byPhoneError(error.errcode)
            }
        }
    }
    
    private func loadOwnPhone() async {
        guard let accessToken else { return }
        hasOwnPhone = try? await invites.hasPhone(accessToken: accessToken)
    }
    
    private static func key(_ phone: String) -> String {
        phone.filter(\.isNumber)
    }
    
    static let minPhoneDigits = 10
}

struct NyutagFindByPhoneView: View {
    @ObservedObject var model: NyutagFindByPhoneModel
    /// Написать найденному человеку: экран закрывается, дальше обычный «Начать чат».
    let onWrite: (UserProfile) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isPhoneFocused: Bool
    @State private var smsInvite: NyutagInvite?
    
    var body: some View {
        ElementNavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(NyutagL10n.byPhoneSubtitle)
                        .font(.compound.bodyMD)
                        .foregroundStyle(.compound.textSecondary)
                    
                    HStack(spacing: 8) {
                        TextField(text: $model.phone) {
                            Text(verbatim: "+7 900 000-00-00").foregroundStyle(.compound.textSecondary)
                        }
                        .textFieldStyle(.compound(labelText: NyutagL10n.byPhoneLabel))
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .focused($isPhoneFocused)
                        .accessibilityIdentifier("nyutagByPhone-phone")
                        
                        Button {
                            NyutagContactPicker.pickPhone { model.pickedPhone($0) }
                        } label: {
                            Image(systemName: "person.crop.circle")
                                .font(.title2)
                                .foregroundStyle(Color(NyutagBrand.blue))
                        }
                        .accessibilityLabel(NyutagL10n.byPhonePickContact)
                        .padding(.top, 20)
                    }
                    
                    if case .failed(let message) = model.search {
                        Label(message, systemImage: "exclamationmark.circle.fill")
                            .font(.compound.bodySM)
                            .foregroundStyle(.compound.textCriticalPrimary)
                    }
                    
                    Button {
                        isPhoneFocused = false
                        model.runSearch()
                    } label: {
                        ZStack {
                            Text(NyutagL10n.byPhoneSearch).opacity(model.search == .searching ? 0 : 1)
                            if model.search == .searching {
                                ProgressView().tint(.compound.textOnSolidPrimary)
                            }
                        }
                    }
                    .buttonStyle(.compound(.primary))
                    .disabled(!model.canSearch)
                    
                    switch model.search {
                    case .found(let user):
                        found(user)
                    case .notFound:
                        notFound
                    default:
                        EmptyView()
                    }
                    
                    if model.hasOwnPhone == false {
                        ownPhoneCard
                            .padding(.top, 16)
                    }
                }
                .padding(16)
                .readableFrame()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
            .navigationTitle(NyutagL10n.byPhoneTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.actionCancel) { dismiss() }
                }
            }
            .sheet(item: $smsInvite) { invite in
                NyutagMessageComposer(recipient: model.phone, body: NyutagL10n.byPhoneInviteText(code: invite.code, link: invite.link))
                    .ignoresSafeArea()
            }
        }
        .onAppear { isPhoneFocused = true }
    }
    
    private func found(_ user: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NyutagL10n.byPhoneFound)
                .font(.compound.bodyMDSemibold)
                .foregroundStyle(.compound.textSuccessPrimary)
            HStack(spacing: 12) {
                LoadableAvatarImage(url: user.avatarURL,
                                    name: user.displayName,
                                    contentID: user.id,
                                    avatarSize: .user(on: .startChat),
                                    mediaProvider: model.mediaProvider)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName ?? user.id)
                        .font(.compound.bodyLGSemibold)
                        .foregroundStyle(.compound.textPrimary)
                    Text(user.id)
                        .font(.compound.bodySM)
                        .foregroundStyle(.compound.textSecondary)
                }
            }
            Button {
                onWrite(user)
            } label: {
                Label(NyutagL10n.byPhoneWrite, systemImage: "bubble.left.fill")
            }
            .buttonStyle(.compound(.primary))
            .accessibilityIdentifier("nyutagByPhone-write")
        }
        .padding(.top, 8)
    }
    
    private var notFound: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NyutagL10n.byPhoneNotFoundTitle)
                .font(.compound.headingSMSemibold)
                .foregroundStyle(.compound.textPrimary)
            Text(NyutagL10n.byPhoneNotFoundSubtitle)
                .font(.compound.bodyMD)
                .foregroundStyle(.compound.textSecondary)
            if let invite = model.invite {
                inviteCard(invite)
            } else {
                if let error = model.inviteError {
                    Text(error)
                        .font(.compound.bodySM)
                        .foregroundStyle(.compound.textCriticalPrimary)
                }
                Button {
                    model.createInvite()
                } label: {
                    ZStack {
                        Label(NyutagL10n.byPhoneInvite, systemImage: "person.badge.plus").opacity(model.isCreatingInvite ? 0 : 1)
                        if model.isCreatingInvite {
                            ProgressView().tint(.compound.textOnSolidPrimary)
                        }
                    }
                }
                .buttonStyle(.compound(.primary))
                .accessibilityIdentifier("nyutagByPhone-invite")
            }
        }
        .padding(.top, 8)
    }
    
    private func inviteCard(_ invite: NyutagInvite) -> some View {
        let text = NyutagL10n.byPhoneInviteText(code: invite.code, link: invite.link)
        return VStack(spacing: 12) {
            // QR — на белом при любой теме: тёмный фон сканеры читают хуже.
            NyutagQRCode(text: invite.link)
                .frame(width: 200, height: 200)
                .padding(12)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("nyutagByPhone-qr")
            Text(NyutagL10n.byPhoneQRHint)
                .font(.compound.bodySM)
                .foregroundStyle(.compound.textSecondary)
                .multilineTextAlignment(.center)
            Text(NyutagL10n.byPhoneCode(invite.code))
                .font(.compound.bodyLGSemibold)
                .foregroundStyle(.compound.textPrimary)
            HStack(spacing: 8) {
                if MFMessageComposeViewController.canSendText() {
                    Button(NyutagL10n.byPhoneSMS) { smsInvite = invite }
                        .buttonStyle(.compound(.secondary))
                }
                ShareLink(item: text) {
                    Label(NyutagL10n.byPhoneShare, systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.compound(.primary))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.compound.bgSubtleSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var ownPhoneCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NyutagL10n.byPhoneOwnTitle)
                .font(.compound.bodyLGSemibold)
                .foregroundStyle(.compound.textPrimary)
            Text(NyutagL10n.byPhoneOwnSubtitle)
                .font(.compound.bodyMD)
                .foregroundStyle(.compound.textSecondary)
            TextField(text: $model.ownPhone) {
                Text(verbatim: "+7 900 000-00-00").foregroundStyle(.compound.textSecondary)
            }
            .textFieldStyle(.compound(labelText: NyutagL10n.byPhoneOwnLabel))
            .keyboardType(.phonePad)
            .textContentType(.telephoneNumber)
            if let error = model.ownPhoneError {
                Text(error)
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textCriticalPrimary)
            }
            Button(L10n.actionSave) { model.saveOwnPhone() }
                .buttonStyle(.compound(.secondary))
                .disabled(!model.canSaveOwnPhone)
        }
        .padding(16)
        .background(Color.compound.bgSubtleSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension NyutagInvite: Identifiable {
    var id: String { code }
}

/// QR-код ссылки (CoreImage), без сглаживания — чёткие квадраты при любом размере.
struct NyutagQRCode: View {
    let text: String
    
    var body: some View {
        if let image = Self.image(for: text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        }
    }
    
    static func image(for text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// Готовое SMS с приглашением на выбранный номер.
private struct NyutagMessageComposer: UIViewControllerRepresentable {
    let recipient: String
    let body: String
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = [recipient.filter { $0.isNumber || $0 == "+" }]
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true)
        }
    }
}

/// Выбор номера в телефонной книге: системное окно отдаёт один номер, доступ ко всем контактам не нужен.
@MainActor
enum NyutagContactPicker {
    private static var delegate: Delegate?
    
    static func pickPhone(_ completion: @escaping (String) -> Void) {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        guard var presenter = window?.rootViewController else { return }
        while let presented = presenter.presentedViewController, !presented.isBeingDismissed {
            presenter = presented
        }
        let picker = CNContactPickerViewController()
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        picker.predicateForSelectionOfProperty = NSPredicate(format: "key == 'phoneNumbers'")
        let delegate = Delegate(completion: completion)
        Self.delegate = delegate
        picker.delegate = delegate
        presenter.present(picker, animated: true)
    }
    
    private final class Delegate: NSObject, CNContactPickerDelegate {
        let completion: (String) -> Void
        
        init(completion: @escaping (String) -> Void) {
            self.completion = completion
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            if let number = (contactProperty.value as? CNPhoneNumber)?.stringValue {
                completion(number)
            }
            NyutagContactPicker.delegate = nil
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            NyutagContactPicker.delegate = nil
        }
    }
}
