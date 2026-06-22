import Foundation
import AppKit

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let size: Int64
    var isSelected: Bool = true

    var name: String { url.lastPathComponent }

    var displayPath: String {
        let home = NSHomeDirectory()
        var p = url.path
        if p.hasPrefix(home) {
            p = "~" + p.dropFirst(home.count)
        }
        return p
    }

    var sizeString: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    var isDirectory: Bool {
        var flag: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &flag)
        return flag.boolValue
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (l: FileItem, r: FileItem) -> Bool { l.id == r.id }
}
