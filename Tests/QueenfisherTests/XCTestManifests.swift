import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(AuthenticationTests.allTests),
        testCase(SpreadsheetTests.allTests)
    ]
}
#endif
