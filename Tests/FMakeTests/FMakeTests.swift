import XCTest
@testable import FMake

final class FMakeTests: XCTestCase {
  func testReadLine() throws {
    let res = try readLine(cmd: "echo nice")
    XCTAssertEqual(res, "nice")
  }
  
  func testMD5() throws {
    try write(content: "test", atPath: "test.md5")
    let res = try md5(path: "test.md5")
    XCTAssertEqual(res, "098f6bcd4621d373cade4e832627b4f6")
  }
}
