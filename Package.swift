// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "FleetLog",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "FleetLogCore", targets: ["FleetLogCore"])
    ],
    targets: [
        .target(name: "FleetLogCore"),
        .testTarget(name: "FleetLogCoreTests", dependencies: ["FleetLogCore"])
    ]
)
