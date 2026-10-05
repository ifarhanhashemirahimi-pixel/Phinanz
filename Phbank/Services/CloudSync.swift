//
//  CloudSync.swift
//  Phbank
//
//  Optional iCloud sync through SwiftData + CloudKit (private database).
//  Off by default. It only switches on when this build is signed with the
//  iCloud (CloudKit) capability, which needs the Apple Developer Program —
//  otherwise PHINANZ stays local and never touches CloudKit.
//

import Foundation

enum CloudSync {
    /// Must match the container in Signing & Capabilities → iCloud.
    static let containerID = "iCloud.Farhan.Phbank"

    /// Whether sync was switched on when the database was opened. Changing
    /// the setting takes effect after the app restarts.
    static var isActive = false

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: SettingsKeys.iCloudSync)
    }

    /// True when the provisioning profile grants CloudKit.
    static let isAvailable: Bool = entitlementGranted(in: Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"))

    static var restartNeeded: Bool { isAvailable && isEnabled != isActive }

    /// Reads the plist inside a provisioning profile and looks for CloudKit.
    static func entitlementGranted(in profileURL: URL?) -> Bool {
        guard let profileURL, let data = try? Data(contentsOf: profileURL) else { return false }
        return entitlementGranted(inProfileData: data)
    }

    static func entitlementGranted(inProfileData data: Data) -> Bool {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound ..< data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                from: data.subdata(in: start.lowerBound ..< end.upperBound), format: nil
              ) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any]
        else { return false }
        switch entitlements["com.apple.developer.icloud-services"] {
        case let list as [String]: return list.contains("CloudKit") || list.contains("*")
        case let value as String: return value == "CloudKit" || value == "*"
        default: return false
        }
    }
}
