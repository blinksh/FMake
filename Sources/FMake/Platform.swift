//
//  File.swift
//  
//
//  Created by Yury Korolev on 24.12.2020.
//

import Foundation

public enum Platform: String, CaseIterable {
  public enum ModuleHeader {
    case umbrella(_ path: String)
    case umbrellaDir(_ path: String)
    
    func moduleCode() -> String {
      switch self {
      case .umbrella(let path):
        return "umbrella header \"\(path)\""
      case .umbrellaDir(let path):
        return "umbrella \"\(path)\""
      }
    }
  }
  
  public enum Arch: String {
    case x86_64, arm64, arm64e, armv7k, arm64_32
  }
  
  case AppleTVOS, AppleTVSimulator
  case iPhoneOS, iPhoneSimulator
  case MacOSX, Catalyst
  case WatchOS, WatchSimulator
  
  public var name: String {
    rawValue
  }
  
  public var sdk: String {
    self == .Catalyst ? Platform.MacOSX.rawValue.lowercased() : rawValue.lowercased()
  }
  
  public var archs: [Arch] {
    switch self {
    case .AppleTVOS:        return [.arm64]
    case .AppleTVSimulator: return [.x86_64 /*, .arm64 */]
    case .iPhoneOS:         return [.arm64, .arm64e]
    case .iPhoneSimulator:  return [.x86_64, .arm64]
    case .WatchOS:          return [.arm64_32]
    case .WatchSimulator:   return [.x86_64]
    case .MacOSX:           return [.x86_64, .arm64]
    case .Catalyst:         return [.x86_64, .arm64]
    }
  }
  
  var cmakeSystemName: String {
    switch self {
    case .AppleTVOS, .AppleTVSimulator: return "tvOS"
    case .MacOSX, .Catalyst:            return "Darwin"
    case .iPhoneOS, .iPhoneSimulator:   return "iOS"
    case .WatchOS, .WatchSimulator:     return "watchOS"
    }
  }
  
  private var _xcrunSdk: String {
    "xcrun --sdk \(sdk)"
  }
  
  public func sdkPath() throws -> String {
    return try readLine(cmd:  "\(_xcrunSdk) --show-sdk-path")
  }
  
  public func sdkVersion() throws -> String {
    return try readLine(cmd: "\(_xcrunSdk) --show-sdk-version")
  }
  
  public func ccPath() throws -> String {
    return try readLine(cmd: "\(_xcrunSdk) -f cc")
  }
  
  public func cxxPath() throws -> String {
    return try readLine(cmd: "\(_xcrunSdk) -f c++")
  }
  
  public var minSDKVersionName: String {
    switch self {
    case .AppleTVOS:        return "tvos_version_min"
    case .AppleTVSimulator: return "tvos_simulator_version_min"
    case .MacOSX:           return "macosx_version_min"
    case .Catalyst:         return "platform_version mac-catalyst 14.0"
    case .iPhoneOS:         return "ios_version_min"
    case .iPhoneSimulator:  return "ios_simulator_version_min"
    case .WatchOS:          return "watchos_version_min"
    case .WatchSimulator:   return "watchos_simulator_version_min"
    }
  }
  
  enum DeviceType: Int {
    case iphone = 1
    case ipad = 2
    case tv = 3
    case watch = 4
    case tv4k = 5
    case mac = 6
  }
  
  var deviceFamily: [DeviceType] {
    switch self {
    case .AppleTVOS, .AppleTVSimulator:
      return [.tv, .tv4k]
    case .MacOSX, .Catalyst:
      return [.ipad, .mac]
    case .iPhoneOS, .iPhoneSimulator:
      return [.iphone, .ipad]
    case .WatchOS, .WatchSimulator:
      return [.watch]
    }
  }
  
  public func module(name: String, headers: ModuleHeader) -> String {
    """
    module \(name) {
      \(headers.moduleCode())

      export *
    }
    """
  }
  
  public func plist(name: String, version: String, id: String, minSdkVersion: String) throws -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleDevelopmentRegion</key>
      <string>en</string>
      <key>CFBundleExecutable</key>
      <string>\(name)</string>
      <key>CFBundleIdentifier</key>
      <string>\(id)</string>
      <key>CFBundleInfoDictionaryVersion</key>
      <string>6.0</string>
      <key>CFBundleName</key>
      <string>\(name)</string>
      <key>CFBundlePackageType</key>
      <string>FMWK</string>
      <key>CFBundleShortVersionString</key>
      <string>\(version)</string>
      <key>CFBundleVersion</key>
      <string>1</string>
      <key>MinimumOSVersion</key>
      <string>\(minSdkVersion)</string>
      <key>CFBundleSupportedPlatforms</key>
      <array>
        <string>\(rawValue)</string>
      </array>
      <key>UIDeviceFamily</key>
      <array>
        \(self.deviceFamily.map({ (d) -> String in
          "   <integer>\(d.rawValue)</integer>"
        }).joined(separator: "\n"))
      </array>
      <key>DTPlatformName</key>
      <string>\(sdk)</string>
      <key>DTPlatformVersion</key>
      <string>\(try sdkVersion())</string>
      <key>DTSDKName</key>
      <string>\(sdk)\(try sdkVersion())</string>
    </dict>
    </plist>
    """
  }
}

public func repackFrameworkToMacOS(at path: String, name: String) throws {
  try cd(path) {
    let modules = exists("Modules")
    
    try mkdir("Versions")
    try mkdir("Versions/A")
    try mkdir("Versions/A/Resources")
    try sh("mv \(name) Headers \(modules ? "Modules" : "") Versions/A")
    try sh("mv Info.plist Versions/A/Resources")
    
    try cd("Versions") {
      try sh("ln -s A Current")
    }
    
    try sh("ln -s Versions/Current/\(name)")
    try sh("ln -s Versions/Current/Headers")
    try sh("ln -s Versions/Current/Resources")
    if modules {
      try sh("ln -s Versions/Current/Modules")
    }
  }
}


public func appleCMake() -> String {
    """
    include(Platform/Darwin)

    list(APPEND CMAKE_FIND_ROOT_PATH $ENV{SECOND_FIND_ROOT_PATH})
    set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO")
    set(CMAKE_XCODE_ATTRIBUTE_ENABLE_BITCODE "NO")

    if (NOT $ENV{APPLE_PLATFORM} MATCHES "macosx")
        set(UNIX True)
        set(APPLE True)

        set(CMAKE_MACOSX_BUNDLE TRUE)
        set(CMAKE_CROSSCOMPILING TRUE)

        set(CMAKE_OSX_SYSROOT $ENV{APPLE_SDK_PATH} CACHE PATH "Sysroot used for Apple support")
    endif()

    """
}
