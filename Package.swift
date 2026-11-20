// swift-tools-version:5.9
import PackageDescription

// tsubomi のアプリ（Profilink・TouchRotator ほか）が共通で使う部品。
//
// - TsubomiKitCore: UI を持たない部分（アプリ同士のやり取りの形、🌸 を出す担当の決め方など）。
//   Foundation だけに依存させ、Linux でもテストできるようにしている。
// - TsubomiMenuBar: メニューバーのアイコンとガラスのパネル、アイコンを 1 つにまとめる仕組み。
//   AppKit + SwiftUI なので macOS でだけビルドする。

var products: [Product] = [
    .library(name: "TsubomiKitCore", targets: ["TsubomiKitCore"]),
]

var targets: [Target] = [
    .target(
        name: "TsubomiKitCore",
        path: "Sources/TsubomiKitCore"
    ),
    .testTarget(
        name: "TsubomiKitCoreTests",
        dependencies: ["TsubomiKitCore"],
        path: "Tests/TsubomiKitCoreTests"
    ),
]

#if os(macOS)
products.append(.library(name: "TsubomiMenuBar", targets: ["TsubomiMenuBar"]))
targets.append(
    .target(
        name: "TsubomiMenuBar",
        dependencies: ["TsubomiKitCore"],
        path: "Sources/TsubomiMenuBar"
    )
)
#endif

let package = Package(
    name: "tsubomi-kit",
    platforms: [
        .macOS(.v13)
    ],
    products: products,
    targets: targets
)
