// swift-tools-version: 6.0
import PackageDescription

// UAV Playlist — an iPhone app that extracts a direct video/HLS stream link from a
// supported site and writes a VLC-ready .m3u8 playlist file instead of downloading
// any video data. Requires Xcode 16 or later (uses the "Swift package as an iOS app"
// product type introduced there). Open this folder's Package.swift directly in
// Xcode, pick an iPhone (or simulator) run destination, and press Run.
let package = Package(
    name: "UAVPlaylist",
    platforms: [.iOS(.v17)],
    products: [
        .iOSApplication(
            name: "UAVPlaylist",
            targets: ["UAVPlaylistApp"],
            bundleIdentifier: "com.uavdownloader.playlist",
            displayVersion: "1.0",
            bundleVersion: "1",
            supportedDeviceFamilies: [.phone],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
            ],
            additionalInfoPlistContentFilePath: "Support/Info-Additions.plist"
        )
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0")
    ],
    targets: [
        .executableTarget(
            name: "UAVPlaylistApp",
            dependencies: ["SwiftSoup"],
            path: "Sources/UAVPlaylistApp"
        )
    ]
)
