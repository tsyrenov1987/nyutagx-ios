//
// Нютаг (форк Element X iOS) — «Пригласить друга».
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import SwiftUI
import UIKit

/// Одноразовый код от сервиса ядра и системное «Поделиться» с готовым текстом — как приглашение в WhatsApp/Telegram.
@MainActor
enum NyutagInviteFriend {
    static func share(clientProxy: ClientProxyProtocol, userIndicatorController: UserIndicatorControllerProtocol) async {
        let indicatorID = "NyutagInviteFriend-Loading"
        userIndicatorController.submitIndicator(UserIndicator(id: indicatorID, type: .modal, title: NyutagL10n.inviteCreating, persistent: true))
        
        guard let accessToken = (clientProxy as? ClientProxy)?.nyutagAccessToken else {
            userIndicatorController.retractIndicatorWithId(indicatorID)
            userIndicatorController.submitIndicator(UserIndicator(title: NyutagL10n.inviteFailed, icon: \.errorSolid))
            return
        }
        
        do throws(NyutagInviteError) {
            let invite = try await NyutagInvitesService.shared.createInvite(accessToken: accessToken)
            userIndicatorController.retractIndicatorWithId(indicatorID)
            present(text: NyutagL10n.inviteShareText(appName: InfoPlistReader.main.bundleDisplayName, code: invite.code, link: invite.link))
        } catch {
            userIndicatorController.retractIndicatorWithId(indicatorID)
            let message = switch error.errcode {
            case "NYUTAG_INVITE_LIMIT", "M_LIMIT_EXCEEDED": NyutagL10n.inviteLimit
            case NyutagInviteError.network: NyutagL10n.inviteNetwork
            default: NyutagL10n.inviteFailed
            }
            userIndicatorController.submitIndicator(UserIndicator(title: message, icon: \.errorSolid))
        }
    }
    
    private static func present(text: String) {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        guard var presenter = window?.rootViewController else { return }
        while let presented = presenter.presentedViewController, !presented.isBeingDismissed {
            presenter = presented
        }
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let popover = activity.popoverPresentationController, let window {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(activity, animated: true)
    }
}

/// «Избранное» как в Telegram: личная комната, где участник только вы. Создаётся при первом открытии,
/// дальше открывается та же (id в account data).
@MainActor
enum NyutagSavedMessages {
    static func roomID(clientProxy: ClientProxyProtocol, userIndicatorController: UserIndicatorControllerProtocol) async -> String? {
        guard let proxy = clientProxy as? ClientProxy else { return nil }
        
        if let roomID = await proxy.nyutagSavedMessagesRoomID(),
           case .joined = await clientProxy.roomForIdentifier(roomID) {
            return roomID
        }
        
        let indicatorID = "NyutagSavedMessages-Creating"
        userIndicatorController.submitIndicator(UserIndicator(id: indicatorID, type: .modal, title: L10n.commonLoading, persistent: true))
        defer { userIndicatorController.retractIndicatorWithId(indicatorID) }
        
        let avatarURL = await proxy.nyutagUploadSavedMessagesAvatar()
        switch await clientProxy.createRoom(name: NyutagL10n.savedMessages,
                                            topic: NyutagL10n.savedMessagesTopic,
                                            accessType: .private,
                                            isSpace: false,
                                            userIDs: [],
                                            avatarURL: avatarURL.flatMap(URL.init(string:)),
                                            aliasLocalPart: nil) {
        case .success(let roomID):
            _ = await proxy.nyutagSetSavedMessagesRoomID(roomID)
            return roomID
        case .failure:
            userIndicatorController.submitIndicator(UserIndicator(title: L10n.errorUnknown, icon: \.errorSolid))
            return nil
        }
    }
    
    /// Имя комнаты задаётся при создании и остаётся на том языке, на каком её создали: стандартное имя
    /// на другом языке меняем на текущий перевод, своё имя пользователя не трогаем.
    static func localizeName(_ summaries: [RoomSummary], clientProxy: ClientProxyProtocol) {
        let localizedName = NyutagL10n.savedMessages
        let candidates = Set(summaries.filter { defaultNames.contains($0.name) && $0.name != localizedName }.map(\.id))
        guard !isLocalizingName, !candidates.isSubset(of: localizeNameAttempts), let proxy = clientProxy as? ClientProxy else { return }
        isLocalizingName = true
        Task {
            defer { isLocalizingName = false }
            guard let roomID = await proxy.nyutagSavedMessagesRoomID() else { return }
            // Одна попытка за запуск; чужие комнаты с таким же именем дальше не проверяем.
            localizeNameAttempts.formUnion(candidates)
            guard candidates.contains(roomID), case let .joined(roomProxy) = await clientProxy.roomForIdentifier(roomID) else { return }
            if case .failure(let error) = await roomProxy.setName(localizedName) {
                MXLog.error("Nyutag: failed renaming saved messages \(roomID): \(error)")
            }
        }
    }
    
    /// Стандартные имена на языках Нютага (`nyutag_saved_messages`).
    private static let defaultNames: Set<String> = ["Saved messages", "Избранное", "Хадагалһан"]
    private static var localizeNameAttempts = Set<String>()
    private static var isLocalizingName = false
}

// MARK: - Поиск по чату

/// Поиск сообщений внутри одного чата: тот же локальный индекс SDK, что у общего поиска (шифрованные чаты тоже),
/// но в выдаче только эта комната. Индекс общий на все чаты, поэтому страницы дочитываются, пока не наберётся экран.
@MainActor
final class NyutagRoomSearchModel: ObservableObject {
    struct Item: Identifiable {
        let message: SearchScreenMessage
        let senderID: String
        let senderAvatarURL: URL?
        
        var id: String { message.id }
        
        /// Текст без префикса «Имя: » — имя и так стоит заголовком строки.
        var body: AttributedString? {
            guard let preview = message.preview else { return nil }
            let prefix = message.senderName.count + 2
            guard preview.characters.count >= prefix else { return preview }
            return AttributedString(preview[preview.index(preview.startIndex, offsetByCharacters: prefix)...])
        }
    }
    
    @Published var query = ""
    @Published private(set) var items: [Item] = []
    @Published private(set) var isLoading = false
    @Published private(set) var searchedQuery = ""
    
    let mediaProvider: MediaProviderProtocol
    let onSelect: (String) -> Void
    
    private let roomID: String
    private let userID: String
    private let service: SearchServiceProxyProtocol
    private var endReached = false
    private var wanted = pageSize
    private var queryTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    private static let pageSize = 20
    
    init?(roomID: String, clientProxy: ClientProxy, mediaProvider: MediaProviderProtocol, onSelect: @escaping (String) -> Void) {
        guard let service = clientProxy.nyutagMakeSearchService() else { return nil }
        self.roomID = roomID
        userID = clientProxy.userID
        self.service = service
        self.mediaProvider = mediaProvider
        self.onSelect = onSelect
        
        service.resultsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in self?.update(with: results) }
            .store(in: &cancellables)
        
        service.paginationStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                isLoading = state == .loading
                if case .idle(let endReached) = state {
                    self.endReached = endReached
                    fillIfNeeded()
                }
            }
            .store(in: &cancellables)
        
        $query
            .removeDuplicates()
            .sink { [weak self] query in self?.search(query) }
            .store(in: &cancellables)
    }
    
    func loadMore() {
        wanted = items.count + Self.pageSize
        fillIfNeeded()
    }
    
    private func search(_ query: String) {
        queryTask?.cancel()
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchedQuery = ""
            items = []
            return
        }
        queryTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self, !Task.isCancelled else { return }
            searchedQuery = query
            endReached = false
            wanted = Self.pageSize
            isLoading = true
            if case .failure = await service.setQuery(query) {
                isLoading = false
            }
        }
    }
    
    private func update(with results: [SearchServiceResult]) {
        guard !searchedQuery.isEmpty else {
            items = []
            return
        }
        items = results
            .filter { $0.roomID == roomID }
            .map { result in
                Item(message: SearchScreenMessage(result, roomSummary: nil, isOutgoing: result.sender.id == userID),
                     senderID: result.sender.id,
                     senderAvatarURL: result.sender.avatarURL)
            }
        fillIfNeeded()
    }
    
    private func fillIfNeeded() {
        guard !searchedQuery.isEmpty, !isLoading, !endReached, items.count < wanted else { return }
        Task { await service.paginate() }
    }
}

final class NyutagRoomSearchCoordinator: CoordinatorProtocol {
    private let model: NyutagRoomSearchModel
    
    init(model: NyutagRoomSearchModel) {
        self.model = model
    }
    
    func toPresentable() -> AnyView {
        AnyView(NyutagRoomSearchScreen(model: model))
    }
}

private struct NyutagRoomSearchScreen: View {
    @ObservedObject var model: NyutagRoomSearchModel
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        List {
            if model.searchedQuery.isEmpty {
                Text(NyutagL10n.roomSearchNote)
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textSecondary)
                    .listRowSeparator(.hidden)
            } else if model.items.isEmpty, !model.isLoading {
                Text(NyutagL10n.roomSearchEmpty)
                    .font(.compound.bodyLG)
                    .foregroundStyle(.compound.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .listRowSeparator(.hidden)
            }
            
            ForEach(model.items) { item in
                NyutagRoomSearchCell(item: item, mediaProvider: model.mediaProvider) {
                    model.onSelect(item.id)
                }
                .onAppear {
                    if item.id == model.items.last?.id {
                        model.loadMore()
                    }
                }
            }
            
            if model.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
        .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: NyutagL10n.roomSearchHint)
        .searchFocused($isSearchFocused)
        .navigationTitle(NyutagL10n.roomSearch)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isSearchFocused = true }
    }
}

private struct NyutagRoomSearchCell: View {
    let item: NyutagRoomSearchModel.Item
    let mediaProvider: MediaProviderProtocol
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                LoadableAvatarImage(url: item.senderAvatarURL,
                                    name: item.message.senderName,
                                    contentID: item.senderID,
                                    avatarSize: .user(on: .startChat),
                                    mediaProvider: mediaProvider)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.message.senderName)
                            .font(.compound.bodyMDSemibold)
                            .foregroundStyle(.compound.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(item.message.timestamp.formattedMinimal())
                            .font(.compound.bodySM)
                            .foregroundStyle(.compound.textSecondary)
                    }
                    
                    if let media = item.message.mediaPreview {
                        Text(media.title)
                            .font(.compound.bodyMD)
                            .foregroundStyle(.compound.textSecondary)
                            .lineLimit(2)
                    } else if let body = item.body {
                        Text(body)
                            .font(.compound.bodyMD)
                            .foregroundStyle(.compound.textSecondary)
                            .lineLimit(3)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
