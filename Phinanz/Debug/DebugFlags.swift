//
//  DebugFlags.swift
//  Phinanz
//
//  DEBUG-only switches controlled by files in the `snapshots` folder next to
//  the Xcode project on the Mac (the simulator can read the host's files):
//
//    REQUEST   render screenshots (SnapshotRenderer)
//    DEMO      record a scripted tour of the app into demo-<language>.mp4 (DemoTour)
//    AITEST    run the on-device AI once on sample data → ai-selftest.txt (AISelfTest)
//    LANGUAGE  "de", "en", "fa" or "system": app language from the next launch on
//              (applied after rendering and recording, so this launch is unaffected)
//
//  Never compiled into release builds.
//

#if DEBUG
import Foundation

enum DebugFlags {
    static var directories: [URL] {
        guard let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else { return [] }
        let base = URL(fileURLWithPath: home)
        return [
            base.appendingPathComponent("Desktop/Phinanz/snapshots"),
            base.appendingPathComponent("Desktop/Phbank/snapshots"), // until the Desktop folder is renamed
            base.appendingPathComponent("code/phinanz-snapshots")
        ]
    }

    static var directory: URL? {
        directories.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func url(_ name: String) -> URL? {
        directories.map { $0.appendingPathComponent(name) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func isSet(_ name: String) -> Bool { url(name) != nil }

    /// Unit or UI tests are running: never render, record or switch languages then.
    static let isTesting: Bool = {
        let info = ProcessInfo.processInfo
        return info.environment["XCTestConfigurationFilePath"] != nil
            || info.environment["XCTestSessionIdentifier"] != nil
            || info.arguments.contains("-UITests")
    }()

    /// Checked once at launch.
    static let isDemo: Bool = !isTesting && isSet("DEMO")

    /// Applies a LANGUAGE request for the next launch and removes the file.
    static func applyLanguageRequest() {
        guard !isTesting,
              let url = url("LANGUAGE"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        let code = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let defaults = UserDefaults.standard
        // Persian keeps the device region (like choosing the language in iOS Settings → PHINANZ).
        let locales = ["de": "de_DE", "en": "en_US", "fa": ""]
        if let locale = locales[code] {
            defaults.set([code], forKey: "AppleLanguages")
            if locale.isEmpty {
                defaults.removeObject(forKey: "AppleLocale")
            } else {
                defaults.set(locale, forKey: "AppleLocale")
            }
        } else {
            defaults.removeObject(forKey: "AppleLanguages")
            defaults.removeObject(forKey: "AppleLocale")
        }
        try? FileManager.default.removeItem(at: url)
        let note = "LANGUAGE \(code) applied \(Date()); active from the next launch\n"
        try? note.write(to: url.deletingLastPathComponent().appendingPathComponent("language-log.txt"), atomically: true, encoding: .utf8)
    }
}
#endif
