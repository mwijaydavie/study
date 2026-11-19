import XCTest

class RunnerTests: XCTestCase {
  func testStudyDeskDisplayName() {
    XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "StudyDesk")
  }
}
