// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "VarPNUtunHelper",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .executable(
      name: "VarPNUtunHelper",
      targets: ["VarPNUtunHelper"]
    ),
  ],
  dependencies: [
    .package(
      url: "https://github.com/EbrahimTahernejad/Tun2SocksKit.git",
      from: "5.14.4"
    ),
  ],
  targets: [
    .executableTarget(
      name: "VarPNUtunHelper",
      dependencies: [
        .product(name: "Tun2SocksKit", package: "Tun2SocksKit"),
      ]
    ),
  ]
)
