import XCTest
@testable import FibriCheckCameraSDK

final class CameraSettingsTests: XCTestCase {

    func testInitWithValuesStoresAllProperties() {
        let input = CameraSettingsInput(
            values: .modeLocked,
            internal_manualIso: 200,
            internal_manualExposureTime: 160_000,
            internal_whiteBalanceMode: .manualRgb,
            internal_manualWhiteBalanceRgb: RgbColor(r: 1.0, g: 2.0, b: 3.0),
            internal_manualWhiteBalanceKelvin: 4000,
            internal_focusMode: .modeManual,
            internal_manualFocus: 0.5,
            internal_hdrMode: .on,
            internal_logExposure: true,
            internal_logWhiteBalance: false,
            internal_logFocus: true,
            internal_logHdr: false
        )

        XCTAssertEqual(input.internal_exposureMode, .modeLocked)
        XCTAssertEqual(input.internal_manualIso, 200)
        XCTAssertEqual(input.internal_manualExposureTime, 160_000)
        XCTAssertEqual(input.internal_whiteBalanceMode, .manualRgb)
        XCTAssertEqual(input.internal_manualWhiteBalanceRgb.r, 1.0, accuracy: 0.001)
        XCTAssertEqual(input.internal_manualWhiteBalanceRgb.g, 2.0, accuracy: 0.001)
        XCTAssertEqual(input.internal_manualWhiteBalanceRgb.b, 3.0, accuracy: 0.001)
        XCTAssertEqual(input.internal_manualWhiteBalanceKelvin, 4000)
        XCTAssertEqual(input.internal_focusMode, .modeManual)
        XCTAssertEqual(input.internal_manualFocus, 0.5, accuracy: 0.001)
        XCTAssertEqual(input.internal_hdrMode, .on)
        XCTAssertTrue(input.internal_logExposure)
        XCTAssertFalse(input.internal_logWhiteBalance)
        XCTAssertTrue(input.internal_logFocus)
        XCTAssertFalse(input.internal_logHdr)
    }

    func testDefaultValuesAreCorrect() {
        let settings = CameraSettings()

        XCTAssertEqual(settings.internal_exposureMode, .modeLocked)
        XCTAssertEqual(settings.internal_manualIso, 0)
        XCTAssertEqual(settings.internal_manualExposureTime, 0)
        XCTAssertEqual(settings.internal_whiteBalanceMode, .auto)
        XCTAssertEqual(settings.internal_manualWhiteBalanceKelvin, 5000)
        XCTAssertEqual(settings.internal_focusMode, .modeAuto)
        XCTAssertEqual(settings.internal_manualFocus, 0.0, accuracy: 0.001)
        XCTAssertEqual(settings.internal_hdrMode, .off)
        XCTAssertFalse(settings.internal_logExposure)
        XCTAssertTrue(settings.internal_logWhiteBalance)
        XCTAssertTrue(settings.internal_logFocus)
        XCTAssertFalse(settings.internal_logHdr)
    }

    func testSetCopiesAllProperties() {
        let input = CameraSettingsInput(
            values: .modeAuto,
            internal_manualIso: 400,
            internal_manualExposureTime: 320_000,
            internal_whiteBalanceMode: .auto,
            internal_manualWhiteBalanceRgb: RgbColor(r: 0.5, g: 0.5, b: 0.5),
            internal_manualWhiteBalanceKelvin: 6500,
            internal_focusMode: .modeAuto,
            internal_manualFocus: 0.8,
            internal_hdrMode: .auto,
            internal_logExposure: true,
            internal_logWhiteBalance: true,
            internal_logFocus: false,
            internal_logHdr: true
        )

        let settings = CameraSettings()
        settings.set(input)

        XCTAssertEqual(settings.internal_exposureMode, .modeAuto)
        XCTAssertEqual(settings.internal_manualIso, 400)
        XCTAssertEqual(settings.internal_manualExposureTime, 320_000)
        XCTAssertEqual(settings.internal_whiteBalanceMode, .auto)
        XCTAssertEqual(settings.internal_manualWhiteBalanceKelvin, 6500)
        XCTAssertEqual(settings.internal_focusMode, .modeAuto)
        XCTAssertEqual(settings.internal_manualFocus, 0.8, accuracy: 0.001)
        XCTAssertEqual(settings.internal_hdrMode, .auto)
        XCTAssertTrue(settings.internal_logExposure)
        XCTAssertTrue(settings.internal_logWhiteBalance)
        XCTAssertFalse(settings.internal_logFocus)
        XCTAssertTrue(settings.internal_logHdr)
    }
}
