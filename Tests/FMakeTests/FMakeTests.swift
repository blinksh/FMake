import XCTest
@testable import FMake

final class FMakeTests: XCTestCase {
  func testReadLine() throws {
    let res = try readLine(cmd: "echo nice")
    XCTAssertEqual(res, "nice")
  }
  
  func testCheckSum() throws {
    try write(content: "test", atPath: "test.file")

    let md5_ = try md5(path: "test.file")
    XCTAssertEqual(md5_, "098f6bcd4621d373cade4e832627b4f6")

    let sha256 = try sha(path: "test.file")
    XCTAssertEqual(sha256, "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08")
  }
}
