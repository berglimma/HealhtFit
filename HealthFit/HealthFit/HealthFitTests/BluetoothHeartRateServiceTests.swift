import XCTest
@testable import HealthFit

final class BluetoothHeartRateServiceTests: XCTestCase {
    func testParseHeartRateUint8() {
        // Flags = 0 (UINT8), BPM = 72
        let data = Data([0x00, 72])
        XCTAssertEqual(BluetoothHeartRateService.parseHeartRate(from: data), 72)
    }

    func testParseHeartRateUint16() {
        // Flags bit0 = 1 → UINT16 little-endian 300
        let data = Data([0x01, 0x2C, 0x01])
        XCTAssertEqual(BluetoothHeartRateService.parseHeartRate(from: data), 300)
    }

    func testParseHeartRateEmptyData() {
        XCTAssertNil(BluetoothHeartRateService.parseHeartRate(from: Data()))
    }

    func testParseHeartRateIncompleteUint16() {
        XCTAssertNil(BluetoothHeartRateService.parseHeartRate(from: Data([0x01, 0x2C])))
    }

    func testHeartRateSourcePriorityLabels() {
        XCTAssertEqual(LiveHeartRateSource.appleWatch.displayName, "Apple Watch")
        XCTAssertEqual(LiveHeartRateSource.bluetooth.displayName, "Bluetooth")
        XCTAssertEqual(LiveHeartRateSource.healthKit.displayName, "Apple Saúde")
    }
}
