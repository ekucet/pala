// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pala",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        // Static is fine: the registry is stored process-globally (on UIApplication
        // via an interned selector key), so even if Pala is linked as multiple
        // copies across packages, `.palaInspect` and the hub share ONE registry.
        .library(
            name: "Pala",
            targets: ["Pala"]
        )
    ],
    targets: [
        .target(
            name: "Pala"
        ),
        .testTarget(
            name: "PalaTests",
            dependencies: ["Pala"]
        )
    ]
)
