//
//  DebugFlags.swift
//  Phbank
//
//  DEBUG-only switches controlled by files in the `snapshots` folder next to
//  the Xcode project on the Mac (the simulator can read the host's files):
//
//    REQUEST   render screenshots (SnapshotRenderer)
//    DEMO      record a scripted tour of the app into demo-<language>.mp4 (DemoTour)
//    LANGUAGE  "de", "en", "fa" or "system": app language from the next launch on
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
            base.appendingPathComponent("Desktop/Phbank/snapshots"),
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

    /// Checked once at launch.
    static let isDemo: Bool = isSet("DEMO")

    /// Applies a LANGUAGE request for the next launch and removes the file.
    static func applyLanguageRequest() {
        guard let url = url("LANGUAGE"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        let code = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let defaults = UserDefaults.standard
        let locales = ["de": "de_DE", "en": "en_US", "fa": "fa_IR"]
        if let locale = locales[code] {
            defaults.set([code], forKey: "AppleLanguages")
            defaults.set(locale, forKey: "AppleLocale")
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
