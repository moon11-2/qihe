// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Qihe",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Qihe", targets: ["Qihe"])
    ],
    targets: [
        .executableTarget(
            name: "Qihe",
            path: "Qihe",
            resources: [
                .process("Resources")
            ]
        )
    ]
)

