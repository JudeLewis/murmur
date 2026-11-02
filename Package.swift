// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Murmur",
    platforms: [.macOS(.v15)],
    dependencies: [
        // Speech to text on the Mac (Parakeet models). `traits: []` leaves out
        // its text-to-speech and speaker parts, which Murmur never uses.
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.18.2", traits: []),
    ],
    targets: [
        // Plain logic with no AppKit or audio: tested by `swift test`.
        .target(name: "MurmurCore"),
        // The menu bar app.
        .executableTarget(
            name: "Murmur",
            dependencies: [
                "MurmurCore",
                .product(name: "FluidAudio", package: "FluidAudio"),
            ]
        ),
        .testTarget(name: "MurmurCoreTests", dependencies: ["MurmurCore"]),
    ]
)
