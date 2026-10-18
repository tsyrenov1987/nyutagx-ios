//
// Нютаг (форк Element X iOS) — тесты вкладки «Контакты».
//
// SPDX-License-Identifier: AGPL-3.0-only
//

@testable import ElementX
import Foundation
import Testing

struct NyutagContactsScreenViewModelTests {
    @Test
    func othersExcludeNyutagUsersByLastTenDigits() {
        let book = [NyutagContact(name: "Цырен", phone: "+7 (914) 123-45-67"),
                    NyutagContact(name: "алтан", phone: "8 914 765 43 21"),
                    NyutagContact(name: "Баир", phone: "89140000000")]
        let matched = [NyutagMatchedContact(name: "Цырен", phone: "79141234567", userID: "@tsyren:nyutag.chat", displayName: nil, avatarURL: nil)]
        
        let others = NyutagContactsScreenViewModel.others(book: book, matched: matched)
        
        #expect(others.map(\.name) == ["алтан", "Баир"])
    }
    
    @Test
    func othersWithoutMatchesKeepWholeBook() {
        let book = [NyutagContact(name: "Б", phone: "1"), NyutagContact(name: "А", phone: "2")]
        
        #expect(NyutagContactsScreenViewModel.others(book: book, matched: []).map(\.name) == ["А", "Б"])
    }
}
