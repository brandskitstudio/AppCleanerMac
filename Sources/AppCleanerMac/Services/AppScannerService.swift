import Foundation
import AppKit

// MARK: - Search Location Definition

private enum MatchRule {
    case hasPrefix(String)
    case exactName(String)
    case savedState(String)      // matches "<bundleID>.savedState"
    case groupContainer(String)  // matches if folder name contains the part
}

private struct SearchLocation {
    let directory: String
    let rule: MatchRule
}

// MARK: - AppScannerService

class AppScannerService: ObservableObject, @unchecked Sendable {
    @Published var scannedApp: AppBundle?
    @Published var foundFiles: [FileItem] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var statusMessage: String = ""
    @Published var hasFullDiskAccess: Bool = false

    func checkFullDiskAccess() {
        // Only check truly restricted paths. /Users/Shared is NOT restricted.
        let paths = [
            ("~/Library/Messages" as NSString).expandingTildeInPath,
            ("~/Library/Containers/com.apple.Safari/Data/Library/Cookies" as NSString).expandingTildeInPath,
            "/Library/Application Support/com.apple.TCC"
        ]
        
        var isGranted = false
        for path in paths {
            // If we can even list one of these, we definitely have FDA.
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: path), !contents.isEmpty {
                isGranted = true
                break
            }
        }
        
        // Double check with a simple file check in a known restricted folder
        if !isGranted {
            let testPath = ("~/Library/HomeKit" as NSString).expandingTildeInPath
            isGranted = FileManager.default.isReadableFile(atPath: testPath)
        }
        
        DispatchQueue.main.async {
            self.hasFullDiskAccess = isGranted
        }
    }

    // MARK: Public API

    func scan(app: AppBundle) {
        scannedApp = app
        foundFiles = []
        isScanning = true
        scanProgress = 0

        let bundleID  = app.bundleIdentifier
        let appName   = app.name
        let appPath   = app.path

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let results = await Self.performScan(
                bundleID: bundleID,
                appName: appName,
                appPath: appPath,
                progressCallback: { [weak self] prog, msg in
                    DispatchQueue.main.async {
                        self?.scanProgress = prog
                        self?.statusMessage = msg
                    }
                }
            )

            DispatchQueue.main.async {
                self.foundFiles = results
                self.isScanning = false
                self.scanProgress = 1.0
                self.statusMessage = ""
            }
        }
    }

    func toggleSelection(id: UUID) {
        if let idx = foundFiles.firstIndex(where: { $0.id == id }) {
            foundFiles[idx].isSelected.toggle()
        }
    }

    func selectAll()   { for i in foundFiles.indices { foundFiles[i].isSelected = true  } }
    func deselectAll() { for i in foundFiles.indices { foundFiles[i].isSelected = false } }

    func deleteSelected(completion: @escaping (Int, Int64, [String]) -> Void) {
        let toDelete = foundFiles.filter(\.isSelected)
        let appBundleURL = scannedApp?.path

        Task.detached(priority: .userInitiated) { [weak self] in
            // 1. Force terminate
            if let targetURL = appBundleURL {
                let runningApps = NSWorkspace.shared.runningApplications
                for app in runningApps {
                    if app.bundleURL == targetURL {
                        app.forceTerminate()
                    }
                }
            }

            var count: Int  = 0
            var freed: Int64 = 0
            var failures: [String] = []
            let trashPath = ("~/.Trash" as NSString).expandingTildeInPath

            for item in toDelete {
                do {
                    try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                    count += 1
                    freed += item.size
                } catch {
                    // Collect failures to try with admin privileges later if we want, 
                    // or just report them. For now, let's try one clean AppleScript per item 
                    // but with proper escaping.
                    let escapedPath = item.url.path.replacingOccurrences(of: "\"", with: "\\\"")
                    let scriptSource = "do shell script \"rm -rf \\\"\(escapedPath)\\\"\" with administrator privileges"
                    
                    let semaphore = DispatchSemaphore(value: 0)
                    var scriptSuccess = false
                    
                    DispatchQueue.main.async {
                        if let script = NSAppleScript(source: scriptSource) {
                            var errorDict: NSDictionary?
                            script.executeAndReturnError(&errorDict)
                            if errorDict == nil {
                                scriptSuccess = true
                            }
                        }
                        semaphore.signal()
                    }
                    semaphore.wait()
                    
                    if scriptSuccess {
                        count += 1
                        freed += item.size
                    } else {
                        failures.append(item.name)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self?.foundFiles.removeAll(where: { item in
                    item.isSelected && !failures.contains(item.name)
                })
                completion(count, freed, failures)
            }
        }
    }

    @Published var installedApps: [AppBundle] = []

    func fetchInstalledApps() {
        let appDirs = ["/Applications", "/System/Applications", ("~/Applications" as NSString).expandingTildeInPath]
        var apps: [AppBundle] = []
        let fm = FileManager.default

        for dir in appDirs {
            let url = URL(fileURLWithPath: dir)
            if let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                for item in contents {
                    if let app = AppBundle(url: item) {
                        apps.append(app)
                    }
                }
            }
        }
        // Sort alphabetically
        self.installedApps = apps.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
    }

    func reset() {
        scannedApp   = nil
        foundFiles   = []
        isScanning   = false
        scanProgress = 0
        statusMessage = ""
    }

    // MARK: Private scan logic

    private static func performScan(
        bundleID: String,
        appName: String,
        appPath: URL,
        progressCallback: @escaping (Double, String) -> Void
    ) async -> [FileItem] {

        let bidLow  = bundleID.lowercased()
        let bidPart = bidLow.components(separatedBy: ".").last ?? ""   // e.g. "safari"

        let locations: [SearchLocation] = [
            // ── User Library ────────────────────────────────────────────────────
            SearchLocation(directory: "~/Library/Preferences",
                           rule: .hasPrefix(bidLow)),

            SearchLocation(directory: "~/Library/Application Support",
                           rule: .exactName(appName)),
            SearchLocation(directory: "~/Library/Application Support",
                           rule: .exactName(bundleID)),

            SearchLocation(directory: "~/Library/Caches",
                           rule: .hasPrefix(bidLow)),
            SearchLocation(directory: "~/Library/Caches",
                           rule: .exactName(appName)),

            SearchLocation(directory: "~/Library/Logs",
                           rule: .exactName(appName)),
            SearchLocation(directory: "~/Library/Logs",
                           rule: .exactName(bundleID)),

            SearchLocation(directory: "~/Library/Saved Application State",
                           rule: .savedState(bidLow)),

            SearchLocation(directory: "~/Library/Containers",
                           rule: .exactName(bundleID)),

            SearchLocation(directory: "~/Library/Group Containers",
                           rule: .groupContainer(bidPart)),

            SearchLocation(directory: "~/Library/WebKit",
                           rule: .exactName(bundleID)),

            SearchLocation(directory: "~/Library/HTTPStorages",
                           rule: .hasPrefix(bidLow)),

            SearchLocation(directory: "~/Library/Cookies",
                           rule: .hasPrefix(bidLow)),

            // ── System Library ───────────────────────────────────────────────────
            SearchLocation(directory: "/Library/Preferences",
                           rule: .hasPrefix(bidLow)),
            SearchLocation(directory: "/Library/Application Support",
                           rule: .exactName(appName)),
        ]

        var seen  = Set<String>()
        var items = [FileItem]()

        // Always include the .app itself first
        let appSize = fileSize(url: appPath)
        items.append(FileItem(url: appPath, size: appSize, isSelected: true))
        seen.insert(appPath.path)

        let total = Double(locations.count)

        for (idx, loc) in locations.enumerated() {
            let expandedDir = (loc.directory as NSString).expandingTildeInPath
            progressCallback(Double(idx) / total * 0.9,
                             "Scanning \((loc.directory as NSString).lastPathComponent)…")

            guard FileManager.default.fileExists(atPath: expandedDir) else { continue }

            let dirURL = URL(fileURLWithPath: expandedDir)
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            ) else { continue }

            for item in contents {
                guard !seen.contains(item.path) else { continue }
                let name    = item.lastPathComponent
                let nameLow = name.lowercased()

                var matched = false
                switch loc.rule {
                case .hasPrefix(let prefix) where !prefix.isEmpty:
                    matched = nameLow.hasPrefix(prefix)
                case .exactName(let n) where !n.isEmpty:
                    matched = name == n
                case .savedState(let bid) where !bid.isEmpty:
                    matched = nameLow == "\(bid).savedstate"
                         || (nameLow.hasPrefix(bid) && nameLow.hasSuffix(".savedstate"))
                case .groupContainer(let part) where part.count > 3:
                    matched = nameLow.contains(part)
                default:
                    break
                }

                if matched {
                    let sz = fileSize(url: item)
                    items.append(FileItem(url: item, size: sz, isSelected: true))
                    seen.insert(item.path)
                }
            }
        }

        return items
    }

    // Synchronous recursive size (called from detached Task so it's fine to block)
    private static func fileSize(url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if isDir.boolValue {
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
                options: []
            ) else { return 0 }
            var total: Int64 = 0
            for case let child as URL in enumerator {
                let v = try? child.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
                total += Int64(v?.totalFileAllocatedSize ?? v?.fileAllocatedSize ?? 0)
            }
            return total
        } else {
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? Int64) ?? 0
        }
    }
}
