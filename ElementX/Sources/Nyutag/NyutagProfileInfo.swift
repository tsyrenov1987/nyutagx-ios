//
// Нютаг (форк Element X iOS) — «о себе» в профиле: тоонто нютаг, уг гарбал, год по восточному календарю.
// Поля профиля MSC4133 на Tuwunel, ключи и формат года общие с Android.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

nonisolated struct NyutagProfileInfo: Equatable {
    static let keyAbout = "chat.nyutag.about"
    static let keyToonto = "chat.nyutag.toonto"
    static let keyUg = "chat.nyutag.ug"
    static let keyEastYear = "chat.nyutag.east_year"
    static let maxAbout = 500
    static let maxShort = 100

    var about = ""
    var toonto = ""
    var ug = ""
    /// `<стихия>-<животное>`, например `fire-horse`.
    var eastYear = ""

    var isEmpty: Bool {
        about.isEmpty && toonto.isEmpty && ug.isEmpty && eastYear.isEmpty
    }

    /// Без пробелов по краям, с ограничением длины; неизвестный год отбрасывается.
    var normalized: NyutagProfileInfo {
        NyutagProfileInfo(about: String(about.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxAbout)),
                          toonto: String(toonto.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxShort)),
                          ug: String(ug.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxShort)),
                          eastYear: NyutagEastYear(key: eastYear)?.key ?? "")
    }

    var fields: [String: String] {
        [Self.keyAbout: about, Self.keyToonto: toonto, Self.keyUg: ug, Self.keyEastYear: eastYear]
    }

    init(about: String = "", toonto: String = "", ug: String = "", eastYear: String = "") {
        self.about = about
        self.toonto = toonto
        self.ug = ug
        self.eastYear = eastYear
    }

    init(fields: [String: String]) {
        self.init(about: fields[Self.keyAbout] ?? "",
                  toonto: fields[Self.keyToonto] ?? "",
                  ug: fields[Self.keyUg] ?? "",
                  eastYear: fields[Self.keyEastYear] ?? "")
    }
}

/// Год 60-летнего цикла: стихия (у бурят — цвет) и животное. 1984 — Деревянная Крыса.
nonisolated struct NyutagEastYear: Equatable {
    enum Element: String, CaseIterable {
        case wood, fire, earth, metal, water
    }

    enum Animal: String, CaseIterable {
        case rat, ox, tiger, rabbit, dragon, snake, horse, sheep, monkey, rooster, dog, pig

        /// Род слова в русском — для согласования стихии («Огненная Лошадь», «Огненный Тигр»).
        var isFeminineInRussian: Bool {
            [.rat, .snake, .horse, .sheep, .monkey, .dog, .pig].contains(self)
        }
    }

    let element: Element
    let animal: Animal

    var key: String {
        "\(element.rawValue)-\(animal.rawValue)"
    }

    init(element: Element, animal: Animal) {
        self.element = element
        self.animal = animal
    }

    init?(key: String) {
        let parts = key.split(separator: "-", maxSplits: 1).map(String.init)
        guard parts.count == 2, let element = Element(rawValue: parts[0]), let animal = Animal(rawValue: parts[1]) else {
            return nil
        }
        self.init(element: element, animal: animal)
    }

    init(year: Int) {
        let shift = ((year - 4) % 60 + 60) % 60
        self.init(element: Element.allCases[(shift % 10) / 2], animal: Animal.allCases[shift % 12])
    }

    var localizedName: String {
        let elementIndex = Element.allCases.firstIndex(of: element) ?? 0
        let animalIndex = Animal.allCases.firstIndex(of: animal) ?? 0
        let elementName = animal.isFeminineInRussian
            ? NyutagL10n.eastYearElementFeminine(elementIndex)
            : NyutagL10n.eastYearElementMasculine(elementIndex)
        return NyutagL10n.eastYearFormat(elementName, NyutagL10n.eastYearAnimal(animalIndex))
    }
}

/// Блок «о себе» под аватаркой: подпись и значение, пустые поля не показываются.
struct NyutagProfileFieldsSection: View {
    let info: NyutagProfileInfo

    var body: some View {
        if !info.isEmpty {
            Section {
                row(NyutagL10n.profileAbout, info.about)
                row(NyutagL10n.profileToonto, info.toonto)
                row(NyutagL10n.profileUg, info.ug)
                row(NyutagL10n.profileEastYear, NyutagEastYear(key: info.eastYear)?.localizedName ?? "")
            }
        }
    }

    @ViewBuilder
    private func row(_ title: String, _ value: String) -> some View {
        if !value.isEmpty {
            ListRow(kind: .custom {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.compound.bodySM)
                        .foregroundStyle(.compound.textSecondary)
                    Text(value)
                        .font(.compound.bodyLG)
                        .foregroundStyle(.compound.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ListRowPadding.horizontal)
                .padding(.vertical, ListRowPadding.vertical)
                .accessibilityElement(children: .combine)
            })
        }
    }
}

/// Редактор «о себе» на экране своего профиля; год выбирается по числу, хранится стихия-животное.
struct NyutagProfileFieldsEditor: View {
    @Binding var info: NyutagProfileInfo
    @State private var isPickingYear = false

    var body: some View {
        textSection(NyutagL10n.profileAbout, NyutagL10n.profileAboutPlaceholder, $info.about, axis: .vertical)
        textSection(NyutagL10n.profileToonto, NyutagL10n.profileToontoPlaceholder, $info.toonto, axis: .horizontal)
        textSection(NyutagL10n.profileUg, NyutagL10n.profileUgPlaceholder, $info.ug, axis: .horizontal)

        Section {
            ListRow(label: .plain(title: NyutagEastYear(key: info.eastYear)?.localizedName ?? NyutagL10n.profileEastYearNone),
                    kind: .navigationLink { isPickingYear = true })
        } header: {
            Text(NyutagL10n.profileEastYear)
                .compoundListSectionHeader()
        }
        .sheet(isPresented: $isPickingYear) {
            NyutagEastYearPicker(selectedKey: info.eastYear) { year in
                info.eastYear = year?.key ?? ""
                isPickingYear = false
            }
        }
    }

    private func textSection(_ title: String, _ placeholder: String, _ text: Binding<String>, axis: Axis) -> some View {
        Section {
            ListRow(label: .plain(title: placeholder), kind: .textField(text: text, axis: axis))
        } header: {
            Text(title)
                .compoundListSectionHeader()
        }
    }
}

private struct NyutagEastYearPicker: View {
    static let firstYear = 1920

    let selectedKey: String
    let onPick: (NyutagEastYear?) -> Void

    private var years: [Int] {
        Array((Self.firstYear...max(Self.firstYear, Calendar.current.component(.year, from: .now))).reversed())
    }

    var body: some View {
        ElementNavigationStack {
            Form {
                Section {
                    ListRow(label: .plain(title: NyutagL10n.profileEastYearNone),
                            kind: .selection(isSelected: selectedKey.isEmpty) { onPick(nil) })
                } footer: {
                    Text(NyutagL10n.profileEastYearHint)
                        .compoundListSectionFooter()
                }

                Section {
                    ForEach(years, id: \.self) { year in
                        let eastYear = NyutagEastYear(year: year)
                        ListRow(label: .plain(title: "\(year) — \(eastYear.localizedName)"),
                                kind: .selection(isSelected: false) { onPick(eastYear) })
                    }
                }
            }
            .compoundList()
            .navigationTitle(NyutagL10n.profileEastYearPick)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.actionCancel) { onPick(NyutagEastYear(key: selectedKey)) }
                }
            }
        }
    }
}

/// Загрузка и сохранение полей через ядро Нютага.
@MainActor
enum NyutagProfileFields {
    static func load(userID: String, clientProxy: ClientProxyProtocol) async -> NyutagProfileInfo? {
        guard let accessToken = (clientProxy as? ClientProxy)?.nyutagAccessToken else { return nil }
        do {
            return try await NyutagProfileInfo(fields: NyutagInvitesService.shared.profileFields(userID: userID, accessToken: accessToken))
        } catch {
            MXLog.warning("Nyutag: failed loading profile fields: \(error.errcode)")
            return nil
        }
    }

    /// Шлёт только изменившиеся поля.
    static func save(old: NyutagProfileInfo, new: NyutagProfileInfo, clientProxy: ClientProxyProtocol) async -> Bool {
        guard let accessToken = (clientProxy as? ClientProxy)?.nyutagAccessToken else { return false }
        let oldFields = old.normalized.fields
        for (key, value) in new.normalized.fields where oldFields[key] != value {
            do {
                try await NyutagInvitesService.shared.setProfileField(userID: clientProxy.userID, key: key, value: value, accessToken: accessToken)
            } catch {
                MXLog.error("Nyutag: failed saving profile field \(key): \(error.errcode)")
                return false
            }
        }
        return true
    }
}
