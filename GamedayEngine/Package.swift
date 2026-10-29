// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GamedayEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GamedayEngine", targets: ["GamedayEngine"]),
    ],
    targets: [
        .target(name: "CGamedayEngine"),
        .target(name: "GamedayEngine", dependencies: ["CGamedayEngine"]),
        .testTarget(name: "GamedayEngineTests", dependencies: ["GamedayEngine"]),
        .executableTarget(name: "Backtest", dependencies: ["GamedayEngine"]),
    ]
)