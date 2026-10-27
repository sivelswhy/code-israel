// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodeIsraelKit",
    defaultLocalization: "fr",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CodeIsraelKit", targets: ["CodeIsraelKit"]),
    ],
    targets: [
        .target(name: "CodeIsraelKit"),
        .testTarget(
            name: "CodeIsraelKitTests",
            dependencies: ["CodeIsraelKit"],
            exclude: ["parity-inputs.json"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
