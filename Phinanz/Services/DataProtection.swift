//
//  DataProtection.swift
//  Phinanz
//
//  iOS file protection for the journal database and for files PHINANZ
//  hands to the share sheet (backups, CSV exports, PDF reports).
//

import Foundation
import os

enum DataProtection {
    static let logger = Logger(subsystem: "Farhan.Phinanz", category: "security")

    /// Prefix of every file PHINANZ writes for the share sheet.
    static let exportPrefix = "PHINANZ-"

    /// Encrypts the database files with a key that is only available while the
    /// iPhone is unlocked (files that are open may finish their work after locking).
    static func protectStore(at storeURL: URL) {
        let manager = FileManager.default
        let directory = storeURL.deletingLastPathComponent()
        let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUnlessOpen]
        do {
            // New files (the -wal and -shm journals) inherit the directory's class.
            try manager.setAttributes(attributes, ofItemAtPath: directory.path)
            let name = storeURL.lastPathComponent
            for file in try manager.contentsOfDirectory(atPath: directory.path) where file.hasPrefix(name) {
                try manager.setAttributes(attributes, ofItemAtPath: directory.appendingPathComponent(file).path)
            }
        } catch {
            logger.error("Could not set file protection: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// A temporary URL for a file the user is about to share.
    static func exportURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(exportPrefix + name)
    }

    /// Writes data for the share sheet with complete file protection.
    static func writeExport(_ data: Data, named name: String) throws -> URL {
        let url = exportURL(named: name)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    /// Deletes exported files and leftover recordings from the temporary folder.
    /// Called when the app goes to the background and on launch.
    static func removeTemporaryExports() {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory
        guard let files = try? manager.contentsOfDirectory(atPath: directory.path) else { return }
        for file in files where file.hasPrefix(exportPrefix) {
            try? manager.removeItem(at: directory.appendingPathComponent(file))
        }
    }
}
