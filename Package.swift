// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CPUTemp",
    platforms: [.macOS(.v13)],
    targets: [
        // Private IOKit (IOHIDEventSystem) bridge for reading thermal sensors.
        .target(
            name: "SMCSensors",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .executableTarget(
            name: "CPUTemp",
            dependencies: ["SMCSensors"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("AppKit")
            ]
        )
    ]
)
