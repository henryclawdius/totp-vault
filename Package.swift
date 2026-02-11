// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "totp-vault",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "totp-vault", targets: ["totp-vault"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-crypto", from: "3.0.0")
    ],
    targets: [
        .executableTarget(
            name: "totp-vault",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Crypto", package: "swift-crypto")
            ]
        )
    ]
)
