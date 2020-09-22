// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "Aiolos",
    platforms: [
        .iOS(.v11)
    ],
    products: [
        .library(
            name: "Aiolos",
            targets: ["Aiolos"]
        )
    ],
    targets: [
        .target(
            name: "Aiolos",
            path: "Aiolos/Aiolos"
        )
    ]
)
