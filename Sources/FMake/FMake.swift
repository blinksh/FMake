import Foundation

public func mkdir(_ path: String..., outputLevel: OutputLevel = .default) throws {
  try sh("mkdir -p", path.joined(separator: "/"), outputLevel: outputLevel)
}

public func download(url: String, outputLevel: OutputLevel = .default) throws {
  try sh("curl", url, "-O", "-L", outputLevel: outputLevel)
}

public func cwd() -> String {
  FileManager.default.currentDirectoryPath
}


public func cd(_ path: String) {
  FileManager.default.changeCurrentDirectoryPath(path)
}

public func cd(_ path: String, block: (() throws -> ())) rethrows  {
  let current = cwd()
  defer {
    cd(current)
  }
  cd(path)
  try block()
}

public func exists(_ path: String) -> Bool {
  FileManager.default.fileExists(atPath: path)
}

public func write(content: String, atPath: String) throws {
  let data = content.data(using: .utf8)
  try data?.write(to: URL(fileURLWithPath: atPath))
}

public func readLine(cmd: String) throws -> String {
  var data = Data()
  let p = Pipe()
  let fh = p.fileHandleForReading
  fh.readabilityHandler = { f in
    data.append(f.availableData)
  }
  try sh(cmd, out: p.fileHandleForWriting, outputLevel: .none)
  let content = String(data: data, encoding: .utf8) ?? ""
  
  return content.firstLine() ?? ""
}

public func md5(path: String) throws -> String {
  try readLine(cmd: "md5 -q \(path)")
}
