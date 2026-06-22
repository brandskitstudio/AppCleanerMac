import SwiftUI
import AppKit

// MARK: - Results View

struct ResultsView: View {
    @ObservedObject var scanner: AppScannerService
    let onDelete: () -> Void
    let onBack: () -> Void

    @State private var isDeleting = false
    @State private var showConfirm = false

    private var selectedFiles: [FileItem] { scanner.foundFiles.filter(\.isSelected) }
    private var totalBytes: Int64 { scanner.foundFiles.reduce(0) { $0 + $1.size } }
    private var selectedBytes: Int64 { selectedFiles.reduce(0) { $0 + $1.size } }

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ────────────────────────────────────────────────────────
            ResultsHeader(
                app: scanner.scannedApp,
                fileCount: scanner.foundFiles.count,
                totalBytes: totalBytes,
                selectedCount: selectedFiles.count,
                selectedBytes: selectedBytes,
                onSelectAll: scanner.selectAll,
                onDeselectAll: scanner.deselectAll
            )

            Divider()

            // ── File List ─────────────────────────────────────────────────────
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(scanner.foundFiles) { item in
                        FileRowView(item: item) {
                            scanner.toggleSelection(id: item.id)
                        }

                        if item != scanner.foundFiles.last {
                            Divider().padding(.leading, 62)
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            Divider()

            // ── Footer ────────────────────────────────────────────────────────
            ResultsFooter(
                selectedCount: selectedFiles.count,
                selectedBytes: selectedBytes,
                isDeleting: isDeleting,
                onBack: onBack,
                onDelete: {
                    guard !selectedFiles.isEmpty else { return }
                    showConfirm = true
                }
            )
        }
        .alert("Move to Trash?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                isDeleting = true
                onDelete()
                isDeleting = false
            }
        } message: {
            Text("This will move \(selectedFiles.count) \(selectedFiles.count == 1 ? "item" : "items") (\(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file))) to the Trash.")
        }
    }
}

// MARK: - Results Header

private struct ResultsHeader: View {
    let app: AppBundle?
    let fileCount: Int
    let totalBytes: Int64
    let selectedCount: Int
    let selectedBytes: Int64
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // App Icon with Shadow
            if let app {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                    
                    Image(nsImage: app.icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 44, height: 44)
                        .padding(2)
                }
                .frame(width: 48, height: 48)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    Text(app?.name ?? "Files Found")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    
                    Text("\(fileCount) items")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Text(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue.opacity(0.8)))
                    
                    Text("selected size: " + ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Action Menu
            Menu {
                Button("Select All", action: { withAnimation { onSelectAll() } })
                Button("Deselect All", action: { withAnimation { onDeselectAll() } })
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
    }
}

// MARK: - File Row View

struct FileRowView: View {
    let item: FileItem
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            // Premium Checkbox
            Button {
                withAnimation(.spring(response: 0.2)) { onToggle() }
            } label: {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(item.isSelected ? Color.blue : Color.secondary.opacity(0.4))
            }
            .buttonStyle(.plain)

            // Dynamic Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.03))
                    .frame(width: 36, height: 36)
                
                Image(nsImage: item.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 28, height: 28)
            }
            .opacity(item.isSelected ? 1 : 0.6)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(item.isSelected ? .primary : .secondary)
                    .lineLimit(1)

                Text(item.displayPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Metadata
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.sizeString)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(item.isSelected ? .blue : .secondary)
                
                Text(item.isDirectory ? "Folder" : "File")
                    .font(.system(size: 9, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.quaternary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).stroke(.quaternary, lineWidth: 0.5))
            }
            .frame(minWidth: 70)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(
            ZStack {
                if item.isSelected {
                    Color.blue.opacity(0.03)
                }
                if isHovered {
                    Color.primary.opacity(0.04)
                }
            }
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { withAnimation { onToggle() } }
    }
}

// MARK: - Results Footer

private struct ResultsFooter: View {
    let selectedCount: Int
    let selectedBytes: Int64
    let isDeleting: Bool
    let onBack: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button {
                onBack()
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Spacer()

            if selectedCount > 0 {
                Text("\(selectedCount) selected • \(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Button {
                onDelete()
            } label: {
                if isDeleting {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Removing…")
                    }
                } else {
                    Label("Remove", systemImage: "trash")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedCount > 0 ? .red : .secondary)
            .controlSize(.regular)
            .disabled(selectedCount == 0 || isDeleting)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}
