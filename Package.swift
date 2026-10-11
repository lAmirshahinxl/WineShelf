// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WineShelf",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "WineShelf", targets: ["WineShelf"])
    ],
    targets: [
        .executableTarget(name: "WineShelf", path: "Sources/WineShelf")
    ],
    swiftLanguageModes: [.v5]
)
