// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Murmur",
    // iOS for the iPhone app and keyboard in iPhone/, which use the two libraries below.
    // iOS 18 is the oldest that runs the Bark 3.0 models.
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "MurmurCore", targets: ["MurmurCore"]),
        .library(name: "MurmurSpeech", targets: ["MurmurSpeech"]),
    ],
    dependencies: [
        // Speech to text on the device (Parakeet models). `traits: []` leaves out
        // its text-to-speech and speaker parts, which Murmur never uses.
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.18.2", traits: []),
    ],
    targets: [
        // Plain logic with no AppKit, UIKit or audio: tested by `swift test`.
        .target(name: "MurmurCore"),
        // The speech model and microphone sound, shared by the Mac and the iPhone.
        .target(
            name: "MurmurSpeech",
            dependencies: [.product(name: "FluidAudio", package: "FluidAudio")]
        ),
        // The Mac menu bar app.
        .executableTarget(
            name: "Murmur",
            dependencies: ["MurmurCore", "MurmurSpeech"]
        ),
        .testTarget(name: "MurmurCoreTests", dependencies: ["MurmurCore"]),
    ]
)
