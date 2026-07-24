import XCTest
@testable import HealthFit

final class PasswordPolicyTests: XCTestCase {
    func testRejectsShortPassword() {
        XCTAssertFalse(PasswordPolicy.isValid("Ab1!xyz"))
    }

    func testRejectsMissingUppercase() {
        XCTAssertFalse(PasswordPolicy.isValid("abcdefg1!"))
    }

    func testRejectsMissingLowercase() {
        XCTAssertFalse(PasswordPolicy.isValid("ABCDEFG1!"))
    }

    func testRejectsMissingNumber() {
        XCTAssertFalse(PasswordPolicy.isValid("Abcdefg!"))
    }

    func testRejectsMissingSpecialCharacter() {
        XCTAssertFalse(PasswordPolicy.isValid("Abcdefg1"))
    }

    func testAcceptsComplexPassword() {
        XCTAssertTrue(PasswordPolicy.isValid("Abcdefg1!"))
    }

    func testEvaluateTurnsRequirementsGreen() {
        let results = PasswordPolicy.evaluate("Abcdefg1!")
        XCTAssertTrue(results.allSatisfy(\.isSatisfied))
    }
}
