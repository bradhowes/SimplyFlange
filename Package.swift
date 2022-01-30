// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "Packages",
  platforms: [.iOS(.v13), .macOS(.v10_15)],
  products: [
    .library(name: "Kernel", targets: ["Kernel"]),
    .library(name: "Logging", targets: ["Logging"]),
    .library(name: "Parameters", targets: ["Parameters"]),
    .library(name: "SwiftKernel", targets: ["SwiftKernel"]),
    .library(name: "FilterAudioUnit", targets: ["FilterAudioUnit"]),
    .library(name: "UI", targets: ["UI"]),
  ],
  dependencies: [
    .package(name: "AUv3SupportPackage", url: "https://github.com/bradhowes/AUv3Support", branch: "main"),
  ],
  targets: [
    .target(
      name: "FilterAudioUnit",
      dependencies: ["Parameters"]
    ),
    .target(
      name: "Kernel",
      dependencies: [],
      exclude: ["README.md"],
      cxxSettings: []
    ),
    .target(name: "Logging"),
    .target(
      name: "Parameters",
      dependencies: [
        .productItem(name: "AUv3-Support", package: "AUv3SupportPackage", condition: .none),
        "Logging",
        "SwiftKernel"
      ]
    ),
    .target(
      name: "SwiftKernel",
      dependencies: ["Kernel"]
    ),
    .target(
      name: "UI",
      dependencies: ["FilterAudioUnit", "Parameters", "Logging", "SwiftKernel", "Kernel"]
    ),
    .testTarget(
      name: "ParametersTests",
      dependencies: ["Parameters"]),
  ],
  cxxLanguageStandard: .cxx17
)
