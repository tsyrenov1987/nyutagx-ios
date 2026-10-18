//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Compound
import SentrySwiftUI
import SwiftUI

struct HomeScreen: View {
    @Environment(\.isInSidebar) private var isInSidebar
    
    @ObservedObject var context: HomeScreenViewModel.Context
    
    @State private var scrollViewAdapter = ScrollViewAdapter()
    /// Нютаг: пункт меню выполняется, когда меню уже закрыто — иначе следующий экран не откроется поверх.
    @State private var pendingDrawerAction: NyutagDrawerAction?
    
    @Namespace private var navigationTransitionNamespace
    private enum NavigationTransitionSourceID {
        case spaceFilters
    }
    
    var body: some View {
        HomeScreenContent(context: context, scrollViewAdapter: scrollViewAdapter)
            .alert(item: $context.alertInfo)
            .alert(item: $context.leaveRoomAlertItem,
                   actions: leaveRoomAlertActions,
                   message: leaveRoomAlertMessage)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(Compound.supportsGlass ? .inline : .automatic)
            .toolbar { toolbar }
            .toolbarRole(Compound.supportsGlass ? .editor : .automatic)
            .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
            .track(screen: .Home)
            .toolbarBloom(hasSearchBar: context.viewState.isRoomListSearchEnabled)
            .sentryTrace("\(Self.self)")
            .sheet(item: $context.spaceFiltersViewModel) { vm in
                ChatsSpaceFiltersScreen(context: vm.context)
                    .navigationTransition(.zoom(sourceID: NavigationTransitionSourceID.spaceFilters,
                                                in: navigationTransitionNamespace))
            }
            .sheet(item: $context.nyutagAnnouncement) { announcement in
                NyutagAnnouncementSheet(announcement: announcement, context: context)
            }
            .sheet(isPresented: $context.isPresentingNyutagDonate) {
                NyutagDonateSheet()
            }
            .fullScreenCover(isPresented: $context.isPresentingNyutagDrawer) {
                if let action = pendingDrawerAction {
                    pendingDrawerAction = nil
                    context.send(viewAction: .nyutagDrawer(action))
                }
            } content: {
                NyutagDrawer(context: context, pendingAction: $pendingDrawerAction)
                    .presentationBackground(.clear)
            }
            // Панель выезжает сама — системный подъём снизу ей не нужен.
            .transaction(value: context.isPresentingNyutagDrawer) { $0.disablesAnimations = true }
            .interactiveQuickLook(item: $context.mediaPreviewItem, allowEditing: false)
    }
    
    // MARK: - Private
    
    private var title: String {
        if let selectedSpace = context.viewState.selectedSpaceFilter {
            selectedSpace.room.name
        } else {
            L10n.screenRoomlistMainSpaceTitle
        }
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            settingsButton
                .buttonStyle(.borderless)
        }
        .backportSharedBackgroundVisibility(.hidden)
        
        // Нютаг: заголовок по центру и мельче, как в Telegram iOS.
        ToolbarItem(placement: .principal) {
            Text(title)
                .font(.compound.bodyLGSemibold)
                .foregroundStyle(.compound.textPrimary)
                .lineLimit(1)
        }
        
        ToolbarItem(placement: .primaryAction) {
            if #available(iOS 26, *) {
                newRoomButton
            } else {
                newRoomButton
                    .buttonStyle(.compound(.super, size: .toolbarIcon))
            }
        }
        
        if context.viewState.shouldShowSpaceFilters {
            if #available(iOS 26, *) {
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
            
            ToolbarItem(placement: .primaryAction) {
                SpaceFiltersButton(selected: context.viewState.selectedSpaceFilter != nil) {
                    context.send(viewAction: .spaceFilters)
                }
                .matchedTransitionSource(id: NavigationTransitionSourceID.spaceFilters,
                                         in: navigationTransitionNamespace)
            }
        }
    }
    
    private var settingsButton: some View {
        Button {
            context.isPresentingNyutagDrawer = true
        } label: {
            AvatarSettingsButtonLabel(userProfile: context.viewState.userProfile,
                                      mediaProvider: context.mediaProvider)
        }
        .accessibilityLabel(NyutagL10n.drawerOpen)
        .accessibilityIdentifier(A11yIdentifiers.homeScreen.userAvatar)
    }
    
    @ViewBuilder
    private var newRoomButton: some View {
        switch context.viewState.roomListMode {
        case .empty, .rooms:
            Button {
                context.send(viewAction: .startChat)
            } label: {
                CompoundIcon(\.plus)
            }
            .accessibilityLabel(L10n.actionStartChat)
            .accessibilityIdentifier(A11yIdentifiers.homeScreen.startChat)
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func leaveRoomAlertActions(_ item: LeaveRoomAlertItem) -> some View {
        Button(item.cancelTitle, role: .cancel) { }
        Button(item.confirmationTitle, role: .destructive) {
            context.send(viewAction: .confirmLeaveRoom(roomIdentifier: item.roomID))
        }
    }
    
    private func leaveRoomAlertMessage(_ item: LeaveRoomAlertItem) -> some View {
        Text(item.subtitle)
    }
    
    private struct SpaceFiltersButton: View {
        @Environment(\.isInSidebar) private var isInSidebar
        
        var selected = false
        var action: () -> Void
        
        /// Design prefers the custom style over the system's styling of a Toggle within a toolbar,
        /// however Glass isn't supported for toolbar buttons in the sidebar on iPadOS 26 (likely due
        /// to glass on glass being discouraged by Apple), so we need to handle our styling accordingly.
        var shouldUseGlassButtonStyle: Bool {
            !isInSidebar
        }
        
        var body: some View {
            if #available(iOS 26, *), shouldUseGlassButtonStyle {
                if selected {
                    content
                        .backportButtonStyleGlassProminent()
                        .tint(.compound.bgActionPrimaryRest)
                } else {
                    content
                }
            } else {
                if selected {
                    content
                        .buttonStyle(.compound(.primary, size: .toolbarIcon))
                } else {
                    content
                        .buttonStyle(.compound(.tertiary, size: .toolbarIcon))
                }
            }
        }
        
        private var content: some View {
            Button {
                action()
            } label: {
                CompoundIcon(\.filter)
            }
            .accessibilityLabel(L10n.screenRoomlistYourSpaces)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier(A11yIdentifiers.homeScreen.spaceFilters)
        }
    }
}

// MARK: - Нютаг: боковое меню

/// Боковое меню как в Telegram Android: шапка с аватаром и пункты; тап мимо панели закрывает.
private struct NyutagDrawer: View {
    @ObservedObject var context: HomeScreenViewModel.Context
    @Binding var pendingAction: NyutagDrawerAction?
    @State private var isShown = false
    
    private let panelWidth: CGFloat = 300
    
    var body: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(isShown ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture { close(then: nil) }
                .accessibilityHidden(true)
            
            panel
                .frame(width: panelWidth)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
                .offset(x: isShown ? 0 : -panelWidth)
                .gesture(DragGesture().onEnded { value in
                    if value.translation.width < -60 { close(then: nil) }
                })
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) { isShown = true }
        }
    }
    
    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 0) {
                    row(NyutagL10n.drawerMyProfile, icon: \.userProfile, action: .myProfile)
                    row(NyutagL10n.drawerNewGroup, icon: \.group, action: .newGroup)
                    row(NyutagL10n.drawerContacts, icon: \.user, action: .contacts)
                    row(NyutagL10n.drawerSavedMessages, icon: \.favourite, action: .savedMessages)
                    row(NyutagL10n.drawerSettings, icon: \.settings, action: .settings)
                    row(NyutagL10n.drawerInvite, icon: \.userAdd, action: .invite)
                }
                .padding(.top, 8)
            }
        }
    }
    
    private var header: some View {
        let profile = context.viewState.userProfile
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                close(then: .ownAvatar)
            } label: {
                LoadableAvatarImage(url: profile.avatarURL,
                                    name: profile.displayName,
                                    contentID: profile.id,
                                    avatarSize: .user(on: .settings),
                                    mediaProvider: context.mediaProvider)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NyutagL10n.drawerMyProfile)
            
            VStack(alignment: .leading, spacing: 2) {
                if let name = profile.displayName, !name.isEmpty {
                    Text(name)
                        .font(.compound.bodyLGSemibold)
                        .foregroundStyle(.compound.textPrimary)
                }
                Text(profile.id)
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textSecondary)
            }
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background(Color.compound.bgSubtleSecondary.ignoresSafeArea(edges: .top))
    }
    
    private func row(_ title: String, icon: KeyPath<CompoundIcons, Image>, action: NyutagDrawerAction) -> some View {
        Button {
            close(then: action)
        } label: {
            HStack(spacing: 20) {
                CompoundIcon(icon)
                    .foregroundStyle(.compound.iconSecondary)
                Text(title)
                    .font(.compound.bodyLG)
                    .foregroundStyle(.compound.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    /// Сначала панель уезжает, потом закрывается окно и выполняется пункт.
    private func close(then action: NyutagDrawerAction?) {
        withAnimation(.easeIn(duration: 0.2)) {
            isShown = false
        } completion: {
            pendingAction = action
            context.isPresentingNyutagDrawer = false
        }
    }
}

// MARK: - Нютаг: обращение разработчика

/// Окно с обращением ко всем пользователям: заголовок, текст и кнопки приходят с ядра (`announce.json`).
private struct NyutagAnnouncementSheet: View {
    let announcement: NyutagAnnouncement
    @ObservedObject var context: HomeScreenViewModel.Context
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(announcement.title)
                        .font(.compound.headingLGBold)
                        .foregroundColor(.compound.textPrimary)
                    Text(announcement.body)
                        .font(.compound.bodyLG)
                        .foregroundColor(.compound.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 32)
            }
            VStack(spacing: 12) {
                ForEach(announcement.actions) { action in
                    Button(action.label) { context.send(viewAction: .nyutagAnnouncementAction(action)) }
                        .buttonStyle(.compound(.primary))
                }
                Button(announcement.dismissLabel ?? L10n.actionNotNow) { context.send(viewAction: .nyutagAnnouncementDismiss) }
                    .buttonStyle(.compound(.tertiary))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
    }
}

// MARK: - Нютаг: поддержка проекта

/// Просьба о донате: кто мы, на что идут деньги, три суммы из App Store. Показывается из обращения и из настроек.
struct NyutagDonateSheet: View {
    @StateObject private var store = NyutagDonationStore()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(NyutagL10n.donateTitle)
                        .font(.compound.headingLGBold)
                        .foregroundColor(.compound.textPrimary)
                    Text(store.didThank ? NyutagL10n.donateThanks : NyutagL10n.donateBody)
                        .font(.compound.bodyLG)
                        .foregroundColor(.compound.textPrimary)
                    if let errorMessage = store.errorMessage, !store.didThank {
                        Text(errorMessage)
                            .font(.compound.bodyMD)
                            .foregroundColor(.compound.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 32)
            }
            VStack(spacing: 12) {
                if store.isLoading {
                    ProgressView()
                        .padding(.vertical, 8)
                } else if !store.didThank {
                    ForEach(store.products, id: \.id) { product in
                        Button("\(product.displayName) · \(product.displayPrice)") {
                            Task { await store.purchase(product) }
                        }
                        .buttonStyle(.compound(.primary))
                        .disabled(store.isPurchasing)
                    }
                }
                Button(store.didThank ? L10n.actionClose : L10n.actionNotNow) { dismiss() }
                    .buttonStyle(.compound(.tertiary))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await store.load() }
    }
}

// MARK: - Previews

struct HomeScreen_Previews: PreviewProvider, TestablePreview {
    static let loadingViewModel = viewModel(.skeletons)
    static let emptyViewModel = viewModel(.empty)
    static let loadedViewModel = viewModel(.rooms)
    
    static var previews: some View {
        ElementNavigationStack {
            HomeScreen(context: loadingViewModel.context)
        }
        .snapshotPreferences(expect: loadingViewModel.context.$viewState.map { state in
            state.roomListMode == .skeletons
        })
        .previewDisplayName("Loading")
        
        ElementNavigationStack {
            HomeScreen(context: emptyViewModel.context)
        }
        .snapshotPreferences(expect: emptyViewModel.context.$viewState.map { state in
            state.roomListMode == .empty
        })
        .previewDisplayName("Empty")
        
        ElementNavigationStack {
            HomeScreen(context: loadedViewModel.context)
        }
        .snapshotPreferences(expect: loadedViewModel.context.$viewState.map { state in
            state.roomListMode == .rooms
        })
        .previewDisplayName("Loaded")
    }
    
    static func viewModel(_ mode: HomeScreenRoomListMode) -> HomeScreenViewModel {
        let userID = "@alice:example.com"
        
        let roomSummaryProviderState: RoomSummaryProviderMockConfigurationState = switch mode {
        case .skeletons:
            .loading
        case .empty:
            .loaded([])
        case .rooms:
            .loaded(.mockRooms)
        }
        
        let clientProxy = ClientProxyMock(.init(userID: userID,
                                                roomSummaryProvider: RoomSummaryProviderMock(.init(state: roomSummaryProviderState))))
        
        let userSession = UserSessionMock(.init(clientProxy: clientProxy))
        
        return HomeScreenViewModel(userSession: userSession,
                                   selectedRoomPublisher: CurrentValueSubject<String?, Never>(nil).asCurrentValuePublisher(),
                                   appSettings: .volatile(),
                                   analyticsService: AnalyticsServiceMock(.init()),
                                   bugReportService: BugReportServiceMock(.init()),
                                   notificationManager: NotificationManagerMock(),
                                   userIndicatorController: UserIndicatorControllerMock())
    }
}
