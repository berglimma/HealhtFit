import XCTest
@testable import HealthFit

final class CourtesyVoucherTests: XCTestCase {
    func testNormalizeStripsSpacesAndLowercase() {
        XCTAssertEqual(CourtesyVoucher.normalize(" hf-basic-ab2def "), "HF-BASIC-AB2DEF")
    }

    func testValidFormatAcceptsKnownPrefixes() {
        XCTAssertTrue(CourtesyVoucher.isValidFormat("HF-BASIC-AB2DEF"))
        XCTAssertTrue(CourtesyVoucher.isValidFormat("HF-FIT-K7NPQR"))
        XCTAssertTrue(CourtesyVoucher.isValidFormat("hf-ai-234567"))
        XCTAssertTrue(CourtesyVoucher.isValidFormat("HF-COMPLETE-ABCDEF"))
    }

    func testValidFormatRejectsAmbiguousLettersAndWrongLength() {
        XCTAssertFalse(CourtesyVoucher.isValidFormat("HF-BASIC-ABCDE"))
        XCTAssertFalse(CourtesyVoucher.isValidFormat("HF-BASIC-ABCDEFG"))
        XCTAssertFalse(CourtesyVoucher.isValidFormat("HF-BASIC-AB0DEF"))
        XCTAssertFalse(CourtesyVoucher.isValidFormat("HF-BASIC-ABIDEF"))
        XCTAssertFalse(CourtesyVoucher.isValidFormat("HF-PRO-ABCDEF"))
        XCTAssertFalse(CourtesyVoucher.isValidFormat(""))
    }

    func testPlanFromCode() {
        XCTAssertEqual(CourtesyVoucher.plan(fromNormalizedCode: "HF-BASIC-AB2DEF"), .basic)
        XCTAssertEqual(CourtesyVoucher.plan(fromNormalizedCode: "HF-FIT-K7NPQR"), .fit)
        XCTAssertEqual(CourtesyVoucher.plan(fromNormalizedCode: "HF-AI-234567"), .ai)
        XCTAssertEqual(CourtesyVoucher.plan(fromNormalizedCode: "HF-COMPLETE-ABCDEF"), .complete)
        XCTAssertNil(CourtesyVoucher.plan(fromNormalizedCode: "HF-FREE-ABCDEF"))
    }

    func testGrantExpires() {
        let expired = CourtesyGrant(
            plan: .complete,
            expiresAt: Date().addingTimeInterval(-60),
            code: "HF-COMPLETE-ABCDEF",
            durationDays: 30
        )
        let active = CourtesyGrant(
            plan: .fit,
            expiresAt: Date().addingTimeInterval(86_400),
            code: "HF-FIT-ABCDEF",
            durationDays: 30
        )
        XCTAssertFalse(expired.isActive)
        XCTAssertTrue(active.isActive)
        XCTAssertEqual(PlanTier.highest(of: [.free, active.plan]), .fit)
    }
}
