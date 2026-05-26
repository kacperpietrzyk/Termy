// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Termy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Termy", targets: ["Termy"]),
        .library(name: "TermyCore", targets: ["TermyCore"])
    ],
    dependencies: [
        // M3-1: SwiftTerm 1.13.0 (exact pin) is a real dependency of the
        // `Termy` app target (and `TermyTests`). `TermyCore`/`TermyRDP`/
        // `TermySync` deliberately remain SwiftTerm-free — TermyCore is
        // Foundation-only and that boundary is intentional, so SwiftTerm
        // must never be added to those targets. NOTE: swift-tools 5.10
        // requires `products:` to precede `dependencies:` in the Package()
        // initializer, so this block follows `products:` above (the
        // `exact:` pin form is supported from swift-tools 5.7+).
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.13.0"),
        // M4: Sparkle 2.9.2 (exact pin) — auto-update, app target only.
        // Like SwiftTerm, NEVER add to TermyCore/TermyRDP/TermySync
        // (asserted by the M4 dependency-boundary guard test). Sparkle
        // is a binary dynamic framework: package_dmg.sh / build_and_run.sh
        // embed it + fix rpath + sign inside-out.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.2")
    ],
    targets: [
        .executableTarget(
            name: "Termy",
            dependencies: ["TermyCore", "TermyRDP", "TermySync", .product(name: "SwiftTerm", package: "SwiftTerm"), .product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Termy"
        ),
        .target(
            name: "TermyCore",
            path: "Sources/TermyCore"
        ),
        // M5: CTermyRDP C-shim — statically links vendored FreeRDP 3.26.0
        // archives. This target is the sole admitted import path for FreeRDP
        // symbols (guard §8). All include paths are wired here so Task 4 need
        // not touch Package.swift.
        //
        // Why static-vendored, not a SwiftPM package: FreeRDP ships no
        // upstream SwiftPM package — it is a CMake C library, built offline
        // and pinned by script/build_freerdp.sh into vendor/freerdp/. Static
        // linking (BUILD_SHARED_LIBS=OFF) folds it straight into the Termy
        // binary like SwiftTerm, deliberately avoiding the dyld embed / rpath
        // / inside-out-signing / notarization-embed complexity that M4's
        // *dynamic* Sparkle framework required (spec §4).
        //
        // The vendor/... paths in cSettings/linkerSettings unsafeFlags are
        // resolved relative to the *package root*, not this file — always
        // invoke via `swift build`/`swift test --package-path <root>`.
        .target(
            name: "CTermyRDP",
            path: "Sources/CTermyRDP",
            cSettings: [
                // freerdp3/freerdp/*.h and freerdp3/winpr/*.h both reside under
                // versioned subdirs; expose all three roots so #include <freerdp/...>,
                // #include <winpr/...>, and bare zlib.h all resolve.
                .unsafeFlags([
                    "-Ivendor/freerdp/include/freerdp3",
                    "-Ivendor/freerdp/include/winpr3",
                    "-Ivendor/freerdp/include",
                ])
            ],
            linkerSettings: [
                .unsafeFlags(["-Lvendor/freerdp/lib"]),
                .linkedLibrary("freerdp3"),
                .linkedLibrary("freerdp-client3"),
                .linkedLibrary("winpr3"),
                // libwinpr-tools3.a is deliberately NOT linked — it is the
                // WinPR command-line tools archive, unused by the shim.
                .linkedLibrary("ssl"),
                .linkedLibrary("crypto"),
                .linkedLibrary("z"),
                .linkedFramework("Security"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("Cocoa"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AVFoundation"),
            ]
        ),
        .target(
            name: "TermyRDP",
            // CTermyRDP is the sole admitted import path for FreeRDP symbols (spec §3/§8).
            // `import CTermyRDP` is NOT added to any .swift source yet (Task 4 wires it).
            dependencies: ["TermyCore", "CTermyRDP"],
            path: "Sources/TermyRDP"
        ),
        .target(
            name: "TermySync",
            dependencies: ["TermyCore"],
            path: "Sources/TermySync"
        ),
        .testTarget(
            name: "TermyCoreTests",
            dependencies: ["TermyCore", "TermyRDP", "TermySync"],
            path: "Tests/TermyCoreTests"
        ),
        .testTarget(
            name: "TermyTests",
            dependencies: ["Termy", "TermyCore", "TermyRDP", "TermySync", .product(name: "SwiftTerm", package: "SwiftTerm"), .product(name: "Sparkle", package: "Sparkle")],
            path: "Tests/TermyTests"
        ),
        .testTarget(
            name: "TermyRDPTests",
            dependencies: ["TermyRDP"],
            path: "Tests/TermyRDPTests"
        )
    ]
)
