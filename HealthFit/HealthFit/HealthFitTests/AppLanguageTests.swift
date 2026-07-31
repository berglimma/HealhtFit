import XCTest
@testable import HealthFit

@MainActor
final class AppLanguageTests: XCTestCase {
    private let suiteName = "healthfit.applanguage.tests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testSupportedLanguagesIncludePortugueseEnglishSpanishFrench() {
        let codes = AppLanguage.allCases.map(\.rawValue)
        XCTAssertEqual(codes, ["pt-BR", "en", "es", "fr"])
    }

    func testDefaultIsPortugueseWhenUnset() {
        let store = AppLanguageStore(userDefaults: defaults)
        XCTAssertEqual(store.language, .portuguese)
        XCTAssertEqual(defaults.string(forKey: AppLanguage.storageKey), "pt-BR")
    }

    func testPersistsSelectionAcrossStoreInstances() {
        let first = AppLanguageStore(userDefaults: defaults)
        first.language = .english

        let second = AppLanguageStore(userDefaults: defaults)
        XCTAssertEqual(second.language, .english)
        XCTAssertEqual(defaults.string(forKey: AppLanguage.storageKey), "en")
    }

    func testInvalidStoredCodeFallsBackToPortuguese() {
        defaults.set("xx-INVALID", forKey: AppLanguage.storageKey)
        let store = AppLanguageStore(userDefaults: defaults)
        XCTAssertEqual(store.language, .portuguese)
        XCTAssertEqual(defaults.string(forKey: AppLanguage.storageKey), "pt-BR")
    }

    func testResolvedHelper() {
        XCTAssertEqual(AppLanguage.resolved(fromStoredCode: nil), .portuguese)
        XCTAssertEqual(AppLanguage.resolved(fromStoredCode: "es"), .spanish)
        XCTAssertEqual(AppLanguage.resolved(fromStoredCode: "bogus"), .portuguese)
    }

    func testLanguageKeySurvivesUserDataCleaner() {
        // Preferência de dispositivo deve sobreviver limpeza de dados de conta.
        UserDefaults.standard.set("en", forKey: AppLanguage.storageKey)
        UserDataCleaner.clearAllLocalData(uid: "test-uid", email: "test@example.com")
        XCTAssertEqual(UserDefaults.standard.string(forKey: AppLanguage.storageKey), "en")
        UserDefaults.standard.removeObject(forKey: AppLanguage.storageKey)
    }
}
