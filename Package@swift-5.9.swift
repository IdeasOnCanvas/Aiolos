// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "Aiolos",
    platforms: [
        .iOS(.v12)
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
            path: "Aiolos/Aiolos",
            resources: [.copy("Aiolos/Resources/PrivacyInfo.xcprivacy")]
        )
    ]
)
