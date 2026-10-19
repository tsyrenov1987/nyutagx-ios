//
// Нютаг (форк Element X iOS) — отложенные сообщения в поле ввода: плашка «Отложенных: N», выбор времени и список.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

struct NyutagScheduledComposerModifier: ViewModifier {
    @ObservedObject var context: ComposerToolbarViewModel.Context

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top) {
                if !context.viewState.nyutagScheduled.isEmpty {
                    banner
                }
            }
            .sheet(isPresented: $context.nyutagSchedulePickerShown) {
                NyutagSchedulePickerSheet { date in
                    context.send(viewAction: .nyutagSchedule(date))
                }
            }
            .sheet(isPresented: $context.nyutagScheduledListShown) {
                NyutagScheduledListSheet(messages: context.viewState.nyutagScheduled) { id in
                    context.send(viewAction: .nyutagScheduledSendNow(id: id))
                } onDelete: { id in
                    context.send(viewAction: .nyutagScheduledDelete(id: id))
                }
            }
    }

    private var banner: some View {
        Button {
            context.nyutagScheduledListShown = true
        } label: {
            Label {
                Text(NyutagL10n.scheduleBanner(context.viewState.nyutagScheduled.count))
                    .font(.compound.bodySMSemibold)
                    .foregroundStyle(.compound.textActionAccent)
            } icon: {
                CompoundIcon(\.time, size: .xSmall, relativeTo: .compound.bodySMSemibold)
                    .foregroundStyle(.compound.iconAccentPrimary)
            }
            .padding(4)
        }
        .accessibilityIdentifier("nyutag-scheduled-banner")
    }
}

/// Меню долгого нажатия на «Отправить».
struct NyutagScheduleSendMenu: View {
    @ObservedObject var context: ComposerToolbarViewModel.Context

    var body: some View {
        if context.viewState.nyutagCanScheduleNow {
            Button {
                context.nyutagSchedulePickerShown = true
            } label: {
                Label(NyutagL10n.scheduleSend, icon: \.time)
            }
        }
    }
}

private struct NyutagSchedulePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSchedule: (Date) -> Void

    @State private var date = Date.now.addingTimeInterval(3600)

    private var isPast: Bool {
        date <= .now
    }

    var body: some View {
        ElementNavigationStack {
            Form {
                Section {
                    DatePicker(NyutagL10n.scheduleSend, selection: $date, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                } footer: {
                    Text(isPast ? NyutagL10n.scheduleErrorPast : NyutagL10n.scheduleHint)
                        .compoundListSectionFooter()
                        .foregroundStyle(isPast ? .compound.textCriticalPrimary : .compound.textSecondary)
                }
            }
            .compoundList()
            .navigationTitle(NyutagL10n.scheduleSend)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.actionCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.actionDone) {
                        onSchedule(date)
                        dismiss()
                    }
                    .disabled(isPast)
                    .accessibilityIdentifier("nyutag-schedule-confirm")
                }
            }
        }
    }
}

private struct NyutagScheduledListSheet: View {
    @Environment(\.dismiss) private var dismiss
    let messages: [NyutagScheduledMessage]
    let onSendNow: (String) -> Void
    let onDelete: (String) -> Void

    var body: some View {
        ElementNavigationStack {
            Form {
                Section {
                    ForEach(messages) { message in
                        row(message)
                    }
                } footer: {
                    Text(NyutagL10n.scheduleHint)
                        .compoundListSectionFooter()
                }
            }
            .compoundList()
            .navigationTitle(NyutagL10n.scheduleTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.actionDone) { dismiss() }
                }
            }
        }
        .onChange(of: messages.isEmpty) { _, isEmpty in
            if isEmpty { dismiss() }
        }
    }

    private func row(_ message: NyutagScheduledMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.body)
                .font(.compound.bodyLG)
                .foregroundStyle(.compound.textPrimary)
                .lineLimit(4)
            Text(NyutagL10n.scheduleAt(message.sendAt.formatted(date: .abbreviated, time: .shortened)))
                .font(.compound.bodySM)
                .foregroundStyle(.compound.textSecondary)
            HStack(spacing: 16) {
                Button(NyutagL10n.scheduleSendNow) { onSendNow(message.id) }
                    .buttonStyle(.compound(.secondary, size: .small))
                Button(role: .destructive) {
                    onDelete(message.id)
                } label: {
                    Label(L10n.actionDelete, icon: \.delete)
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.compound(.tertiary, size: .small))
            }
        }
        .padding(.vertical, 4)
    }
}
