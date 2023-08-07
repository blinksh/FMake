import Foundation

public func xbArchive(
  archivePath: String? = nil,
  project: String = "",
  scheme: String = "",
  framework: String = "",
  platform: Platform = .iPhoneOS,
  buildForDistribution: Bool = true,
  enableBitCode: Bool = false,
  excludedArchs: [Platform.Arch] = [],
  skipInstall: Bool = false,
  env: [String: String]? = nil
) throws {
  
  let frameworkName = framework.isEmpty ? scheme : framework
  let path = archivePath ?? "\(frameworkName).xcarchive"
  
  var projectArg = ""
  if !project.isEmpty {
    projectArg = "-project \(project)\(project.hasSuffix(".xcodeproj") ? "" : ".xcodeproj")"
  }
  
  var excludedArchsArg = ""
  if !excludedArchs.isEmpty {
    excludedArchsArg = "EXCLUDED_ARCHS=\(excludedArchs.map({"\($0)"}).joined(separator: ","))"
  }
  
  try sh(
    "xcodebuild",
    "archive",
    projectArg,
    "-scheme", scheme,
    "-sdk", platform.sdk,
    "-archivePath", path,
    excludedArchsArg,
    platform == .Catalyst ? "-destination 'platform=macOS,variant=Mac Catalyst'" : "",
    "BUILD_FOR_DISTRIBUTION=\(buildForDistribution ? "YES" : "NO")",
    "SKIP_INSTALL=\(skipInstall ? "YES" : "NO")",
    "ENABLE_BITCODE=\(enableBitCode ? "YES" : "NO")",
    platform == .Catalyst ? "SUPPORTS_MACCATALYST=YES" : "",
    env: env
  )
}

public func xbArchive(
  dirPath: String,
  project: String = "",
  scheme: String = "",
  framework: String = "",
  platforms: [(Platform, excludedArchs: [Platform.Arch])],
  buildForDistribution: Bool = true,
  enableBitCode: Bool = true,
  skipInstall: Bool = false,
  env: [String: String]? = nil
) throws {
  for p in platforms {
    let path = "\(dirPath)/\(scheme)-\(p.0).xcarchive"
    try xbArchive(
      archivePath: path,
      project: project,
      scheme: scheme,
      framework: framework,
      platform: p.0,
      buildForDistribution: buildForDistribution,
      enableBitCode: enableBitCode,
      excludedArchs: p.excludedArchs,
      skipInstall: skipInstall,
      env: env
    )
  }
}

public func xcxcf(dirPath: String,
                  project: String = "",
                  scheme: String = "",
                  framework: String = "",
                  platforms: [(Platform, excludedArchs: [Platform.Arch])],
                  enableBitCode: Bool = true,
                  includeDSYMs: Bool = true
) throws {
  
  let dir = URL(fileURLWithPath: dirPath).path

  let frameworkName = framework.isEmpty ? scheme : framework
  
  try xbArchive(
    dirPath: dirPath,
    project: project,
    scheme: scheme,
    framework: framework,
    platforms: platforms,
    enableBitCode: enableBitCode
  )
  
  var args = ""
  
  for p in platforms {
    let xcarchive = "\(dir)/\(scheme)-\(p.0).xcarchive"
    let framework = "\(xcarchive)/Products/Library/Frameworks/\(frameworkName).framework"
    let dsym = "\(xcarchive)/dSYMs/\(frameworkName).framework.dSYM"
    
    args += " -framework \(framework)"
    if includeDSYMs {
      args += " -debug-symbols \(dsym)"
    }
  }
  
  args += " -output \(dirPath)/\(frameworkName).xcframework"
  try sh("rm -rf \(dirPath)/\(frameworkName).xcframework")
  try sh("xcodebuild -create-xcframework", args)
}
