import XCTest
@testable import FibriCheckCameraSDK

final class LabelInfoTests: XCTestCase {

    func testGetLabelReturnsAllRequiredKeys() {
        let label = LabelInfo.getLabel()

        XCTAssertNotNil(label["componentName"], "componentName key missing")
        XCTAssertNotNil(label["udi"], "udi key missing")
        XCTAssertNotNil(label["ceLabel"], "ceLabel key missing")
        XCTAssertNotNil(label["manufacturer"], "manufacturer key missing")
        XCTAssertNotNil(label["releaseDate"], "releaseDate key missing")
        XCTAssertNotNil(label["ifu"], "ifu key missing")
    }

    func testComponentNameContainsSDKVersion() {
        let label = LabelInfo.getLabel()
        let componentName = label["componentName"]!

        XCTAssertTrue(componentName.hasPrefix("FibriCheck Camera SDK iOS"),
                      "componentName should start with 'FibriCheck Camera SDK iOS'")

        // Extract version from componentName
        let version = componentName.replacingOccurrences(of: "FibriCheck Camera SDK iOS ", with: "")

        // Version should be in format X.Y.Z
        let versionRegex = try! NSRegularExpression(pattern: "^\\d+\\.\\d+\\.\\d+$")
        let range = NSRange(version.startIndex..., in: version)
        XCTAssertNotNil(versionRegex.firstMatch(in: version, range: range),
                        "componentName should contain version in X.Y.Z format")
    }

    func testUDIHasCorrectFormatAndMatchesSDKVersion() {
        let label = LabelInfo.getLabel()
        let udi = label["udi"]!
        let componentName = label["componentName"]!

        // Check prefix
        XCTAssertTrue(udi.hasPrefix("(01)05419980589323(8012)CAMIOS"),
                      "UDI should start with correct prefix")

        // Extract version code from UDI
        let versionCode = udi.replacingOccurrences(of: "(01)05419980589323(8012)CAMIOS", with: "")

        // Version code should only contain digits
        XCTAssertTrue(versionCode.allSatisfy { $0.isNumber },
                      "UDI version part should only contain digits")

        // Extract SDK version from componentName and compute expected version code
        let sdkVersion = componentName.replacingOccurrences(of: "FibriCheck Camera SDK iOS ", with: "")
        let expectedVersionCode = sdkVersion
            .split(separator: ".")
            .map { String(format: "%02d", Int($0) ?? 0) }
            .joined()

        XCTAssertEqual(versionCode, expectedVersionCode,
                       "UDI version code should match padded SDK version")
    }

    func testCELabelIsCorrect() {
        let label = LabelInfo.getLabel()
        XCTAssertEqual(label["ceLabel"], "CE 1639")
    }

    func testManufacturerIsCorrect() {
        let label = LabelInfo.getLabel()
        XCTAssertEqual(label["manufacturer"],
                       "Qompium NV - Kempische Steenweg 303/27 - 3500 Hasselt - Belgium")
    }

    func testReleaseDateHasYYYYMMFormat() {
        let label = LabelInfo.getLabel()
        let releaseDate = label["releaseDate"]!

        // Should be in YYYY-MM format (7 characters)
        XCTAssertEqual(releaseDate.count, 7,
                       "releaseDate should be in YYYY-MM format")

        let regex = try! NSRegularExpression(pattern: "^\\d{4}-\\d{2}$")
        let range = NSRange(releaseDate.startIndex..., in: releaseDate)
        XCTAssertNotNil(regex.firstMatch(in: releaseDate, range: range),
                        "releaseDate should match YYYY-MM format")
    }

    func testIFUURLIsCorrect() {
        let label = LabelInfo.getLabel()
        XCTAssertEqual(label["ifu"], "https://pages.fibricheck.com/ifu")
    }

    func testFibriCheckerGetLabelDelegatesToLabelInfo() {
        let labelFromLabelInfo = LabelInfo.getLabel()
        let labelFromFibriChecker = FibriChecker.getLabel()

        XCTAssertEqual(labelFromLabelInfo, labelFromFibriChecker,
                       "FibriChecker.getLabel() should return same result as LabelInfo.getLabel()")
    }
}
