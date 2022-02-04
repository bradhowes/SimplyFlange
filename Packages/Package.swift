// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "Packages",
  platforms: [.iOS(.v13), .macOS(.v10_15)],
  products: [
    .library(name: "Kernel", targets: ["Kernel"]),
    .library(name: "Parameters", targets: ["Parameters"]),
    .library(name: "ParameterAddress", targets: ["ParameterAddress"]),
  ],
  dependencies: [
    .package(name: "AUv3SupportPackage", url: "https://github.com/bradhowes/AUv3Support", branch: "main"),
  ],
  targets: [
    .target(name: "ParameterAddress",
            dependencies: [
              .productItem(name: "AUv3-Support", package: "AUv3SupportPackage", condition: .none),
            ],
            exclude: ["README.md"]
           ),
    .target(name: "Kernel",
            dependencies: [
              .productItem(name: "AUv3-Support", package: "AUv3SupportPackage", condition: .none),
              "ParameterAddress"
            ],
            exclude: ["README.md"],
            cxxSettings: [.unsafeFlags(["-fmodules", "-fcxx-modules"], .none)]
           ),
    .target(name: "Parameters",
            dependencies: [
              .productItem(name: "AUv3-Support", package: "AUv3SupportPackage", condition: .none),
              "Kernel"
            ],
            exclude: ["README.md"]
           ),
    .testTarget(
      name: "KernelTests",
      dependencies: ["Kernel"],
      linkerSettings: [
        .linkedFramework("AVFoundation")
      ]
    ),
    .testTarget(
      name: "ParametersTests",
      dependencies: ["Parameters"]),
  ],
  cxxLanguageStandard: .cxx17
)
