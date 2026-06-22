import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DropZoneView: View {
    @ObservedObject var scanner: AppScannerService
    let isGlobalTargeted: Bool
    @State private var iconScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Minimalist Drop Target ──────────────────────────────────
            ZStack {
                // Subtle Outer Circle
                Circle()
                    .strokeBorder(Color.primary.opacity(0.05), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(isGlobalTargeted ? 90 : 0))
                    .animation(isGlobalTargeted ? .linear(duration: 4).repeatForever(autoreverses: false) : .default, value: isGlobalTargeted)

                Image(systemName: isGlobalTargeted ? "square.and.arrow.down.fill" : "square.and.arrow.down")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(isGlobalTargeted ? .blue : .secondary.opacity(0.5))
                    .scaleEffect(isGlobalTargeted ? 1.1 : 1.0)
                    .animation(.spring(), value: isGlobalTargeted)
            }
            .padding(.bottom, 48)

            VStack(spacing: 16) {
                Text("Drop your apps here.")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                
                Text(isGlobalTargeted ? "Release to start scanning" : "AppCleaner finds all related files so you can remove them safely.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .animation(.easeInOut, value: isGlobalTargeted)

                if !isGlobalTargeted {
                    HStack(spacing: 12) {
                        Text("or")
                            .foregroundStyle(.tertiary)
                        
                        Button {
                            openFilePicker()
                        } label: {
                            Label("Choose App...", systemImage: "plus")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                    .padding(.top, 8)
                }
            }

            Spacer()

            Text("Files will be moved to Trash — nothing is permanently deleted.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary.opacity(0.6))
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func processURL(_ url: URL) {
        guard let bundle = AppBundle(url: url) else { return }
        scanner.scan(app: bundle)
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Choose an Application"
        panel.allowedContentTypes = [.applicationBundle, .application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            processURL(url)
        }
    }
}
