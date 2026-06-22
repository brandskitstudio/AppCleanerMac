import AppKit
import SwiftUI

// MARK: - NSView-based Drop Target (most reliable for .app bundles)

class AppDropTargetView: NSView {
    var onDropURL: ((URL) -> Void)?
    var onTargetChange: ((Bool) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("com.apple.application-bundle"),
            NSPasteboard.PasteboardType("public.application"),
            NSPasteboard.PasteboardType("public.unix-executable"),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Drag Validation

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasValidApp(in: sender.draggingPasteboard) else { return [] }
        onTargetChange?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasValidApp(in: sender.draggingPasteboard) else { return [] }
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetChange?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return hasValidApp(in: sender.draggingPasteboard)
    }

    // MARK: - Perform Drop

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onTargetChange?(false)
        let pb = sender.draggingPasteboard

        // Read file URLs from pasteboard (most reliable)
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: options) as? [URL] {
            for url in urls {
                if url.pathExtension.lowercased() == "app" {
                    DispatchQueue.main.async { self.onDropURL?(url) }
                    return true
                }
            }
            // Accept any dropped item as a fallback (might be app without extension)
            if let first = urls.first {
                DispatchQueue.main.async { self.onDropURL?(first) }
                return true
            }
        }
        return false
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        onTargetChange?(false)
    }

    // MARK: - Helpers

    private func hasValidApp(in pasteboard: NSPasteboard) -> Bool {
        let opts: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: opts) as? [URL] else {
            return false
        }
        return urls.contains { $0.pathExtension.lowercased() == "app" }
    }
}

// MARK: - SwiftUI Representable Wrapper

struct DropTargetOverlay: NSViewRepresentable {
    @Binding var isTargeted: Bool
    let onDrop: (URL) -> Void

    func makeNSView(context: Context) -> AppDropTargetView {
        let view = AppDropTargetView()
        view.onDropURL = onDrop
        view.onTargetChange = { targeted in
            DispatchQueue.main.async { self.isTargeted = targeted }
        }
        return view
    }

    func updateNSView(_ nsView: AppDropTargetView, context: Context) {
        nsView.onDropURL = onDrop
        nsView.onTargetChange = { targeted in
            DispatchQueue.main.async { self.isTargeted = targeted }
        }
    }
}
