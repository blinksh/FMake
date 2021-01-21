//
//  File.swift
//  
//
//  Created by Yury Korolev on 25.12.2020.
//

import Foundation
import Combine
import System

fileprivate var _sigintSource: DispatchSourceSignal? = nil
fileprivate var _processes: [Process] = []

fileprivate func _installSigintIfNeeded() {
  guard
    _sigintSource == nil
  else {
    return
  }
  
  signal(SIGINT, SIG_IGN)
  _sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
  _sigintSource?.setEventHandler {
    _processes.forEach { $0.terminate() }
    exit(-1)
  }
  _sigintSource?.resume()
}

public enum BuildError: Error {
  case unexpectedStatusCode
  case unexpectedOutput
}

extension String {
  func firstLine() -> String? {
    split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true).first.flatMap(String.init)
  }
}

public enum OutputLevel {
  case debug, info, error, none
  
  public static var `default`: OutputLevel = .info
  public static var progressIndicator = "."
  
  func on(cmd: String) {
    switch self {
    case .debug: print(cmd)
    case .info: print(cmd)
    case .error: print(cmd)
    case .none: break
    }
  }
  
  func on(env: [String: String]?) {
    switch self {
    case .debug: print("env:", env as Any)
    case .info: print("env:", env as Any)
    case .error: break
    case .none: break
    }
  }
  
  func progressIndicator(every: TimeInterval = 1) -> AnyCancellable {
    var printed = false
    let data = Data(Self.progressIndicator.utf8)
    return Timer
      .publish(every: every, on: .main, in: .common)
      .autoconnect()
      .handleEvents(receiveCancel: {
        if printed {
          print()
        }
      })
      .sink { _ in
        FileHandle.standardOutput.write(data)
        printed = true
      }
  }
}

public func sh(
  _ arguments: String...,
  shPath: String = "/bin/sh",
  in in_:  FileHandle? = nil,
  out: FileHandle? = nil,
  err: FileHandle? = nil,
  env: [String: String]? = nil,
  expectedStatusCode: Int32 = 0,
  outputLevel: OutputLevel = .default
 ) throws {
  _installSigintIfNeeded()
  
  let p = Process()
  p.executableURL = URL(fileURLWithPath: shPath)
  
  let cmd = arguments.joined(separator: " ")
  p.arguments = ["-c", cmd]
  outputLevel.on(cmd: cmd)

  p.environment = env ?? ["PATH": ProcessInfo.processInfo.environment["PATH"] ?? ""]
  outputLevel.on(env: p.environment)
  
  if let in_ = in_ {
    p.standardInput = in_
  }
  
  var outputPipe: Pipe? = nil
  var chunks: [Data] = []
  
  var progressIndicator: AnyCancellable? = nil
  
  switch outputLevel {
  case .debug:
    p.standardOutput = out ?? FileHandle.standardOutput
    p.standardError  = err ?? FileHandle.standardError
  case .info:
    let pipe = Pipe()
    p.standardOutput = out ?? FileHandle.standardOutput
    p.standardError  = err ?? pipe.fileHandleForWriting
    outputPipe = pipe
    progressIndicator = outputLevel.progressIndicator()
  case .error:
    let pipe = Pipe()
    p.standardOutput = out ?? pipe.fileHandleForWriting
    p.standardError  = err ?? pipe.fileHandleForWriting
    outputPipe = pipe
    progressIndicator = outputLevel.progressIndicator()
  case .none:
    p.standardOutput = out ?? FileHandle.nullDevice
    p.standardError  = err ?? FileHandle.nullDevice
  }
  
  if let fh = outputPipe?.fileHandleForReading {
    fh.readabilityHandler = { chunks.append($0.availableData) }
  }
  
  _processes.append(p)
  try p.run()
  p.waitUntilExit()
  _processes.removeAll(where: { $0.processIdentifier == p.processIdentifier })
  progressIndicator?.cancel()
  
  guard
    p.terminationStatus == expectedStatusCode
  else {
    
    if outputLevel != .none {
      print("Unexpected exit code \(p.terminationStatus)")
      print("----------------------------------------")
      for (name, value) in p.environment ?? [:] {
        print("\(name)=\"\(value)\" \\")
      }
      print("\(cmd)")
      print("----------------------------------------")
      
      chunks.forEach(FileHandle.standardOutput.write)
    }
    
    throw BuildError.unexpectedStatusCode
  }
}
