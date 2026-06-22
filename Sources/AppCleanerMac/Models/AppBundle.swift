import Foundation
import AppKit

struct AppBundle: Identifiable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let path: URL
    let version: String?

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: path.path)
    }

    var displayVersion: String {
        version.map { "v\($0)" } ?? ""
    }

    init?(url: URL) {
        guard url.pathExtension.lowercased() == "app",
              FileManager.default.fileExists(atPath: url.path) else { return nil }

        self.path = url
        let infoPlistURL = url.appendingPathComponent("Contents/Info.plist")

        if let data = try? Data(contentsOf: infoPlistURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            self.name = (plist["CFBundleDisplayName"] as? String)
                     ?? (plist["CFBundleName"] as? String)
                     ?? url.deletingPathExtension().lastPathComponent
            self.bundleIdentifier = (plist["CFBundleIdentifier"] as? String) ?? ""
            self.version = plist["CFBundleShortVersionString"] as? String
        } else {
            self.name = url.deletingPathExtension().lastPathComponent
            self.bundleIdentifier = ""
            self.version = nil
        }
    }
}
