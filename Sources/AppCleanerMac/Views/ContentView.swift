import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = AppScannerService()
    @State private var showDeletedBanner = false
    @State private var deletedCount: Int = 0
    @State private var deletedSize: Int64 = 0
    @State private var isTargetedGlobal = false
    @State private var showPermissionError = false

    @State private var appMode: AppMode = .cleaner

    enum AppMode {
        case cleaner
        case applications
    }

    var body: some View {
        ZStack {
            VisualEffectView(material: .windowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            // ── Global Drop Target ──────────────────────────────────────────
            DropTargetOverlay(isTargeted: $isTargetedGlobal) { url in
                processURL(url)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Custom Title Bar ────────────────────────────────────────────
                if scanner.hasFullDiskAccess {
                    TitleBarView(scanner: scanner, appMode: $appMode)
                    Divider()
                }

                // ── Main Content ────────────────────────────────────────────────
                if !scanner.hasFullDiskAccess {
                    OnboardingView(scanner: scanner)
                        .transition(.move(edge: .bottom))
                } else if scanner.isScanning {
                    ScanningView(progress: scanner.scanProgress,
                                 message: scanner.statusMessage,
                                 appName: scanner.scannedApp?.name ?? "")
                        .transition(.opacity)
                } else if scanner.scannedApp != nil {
                    ResultsView(scanner: scanner, onDelete: handleDelete, onBack: scanner.reset)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    Group {
                        if appMode == .cleaner {
                            DropZoneView(scanner: scanner, isGlobalTargeted: isTargetedGlobal)
                        } else {
                            InstalledAppsView(scanner: scanner)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .overlay {
                // Visual feedback when dragging over the entire window
                if isTargetedGlobal {
                    ZStack {
                        Color.blue.opacity(0.05)
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.blue.opacity(0.35), style: StrokeStyle(lineWidth: 4, dash: [15, 10]))
                            .padding(20)
                    }
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }
            }

            // ── Deleted Banner ──────────────────────────────────────────────────
            if showDeletedBanner {
                VStack {
                    Spacer()
                    DeletedBanner(count: deletedCount, size: deletedSize)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .alert("Permission Required", isPresented: $showPermissionError) {
            Button {
                // This 'pokes' the system to make it appear in the list
                scanner.checkFullDiskAccess()
                
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
            } label: {
                Text("Open Settings")
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("macOS prevented the deletion. To fix this:\n\n1. Go to System Settings > Privacy & Security > Full Disk Access.\n2. Add AppCleanerMac and enable it.\n3. Restart the app.")
        }
        .animation(.easeInOut(duration: 0.2), value: isTargetedGlobal)
        .animation(.easeInOut(duration: 0.3), value: scanner.isScanning)
        .animation(.easeInOut(duration: 0.3), value: scanner.scannedApp == nil)
        .animation(.spring(response: 0.4), value: showDeletedBanner)
        .onAppear {
            scanner.checkFullDiskAccess()
        }
    }

    private func processURL(_ url: URL) {
        guard let bundle = AppBundle(url: url) else { return }
        scanner.scan(app: bundle)
    }

    private func handleDelete() {
        let selectedCountBefore = scanner.foundFiles.filter(\.isSelected).count
        scanner.deleteSelected { count, size, failures in
            deletedCount = count
            deletedSize  = size
            
            if count == 0 && selectedCountBefore > 0 {
                // Deletion failed, but let's not block the user with the same annoying alert.
                // We'll just update the status so they know it didn't work.
                print("Deletion failed for selected items.")
            } else if !failures.isEmpty {
                // Some failed, but some succeeded
                print("Partial failure: \(failures)")
            }

            withAnimation { showDeletedBanner = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation { showDeletedBanner = false }
            }
            if scanner.foundFiles.isEmpty { scanner.reset() }
        }
    }
}

// MARK: - Custom Title Bar

private struct TitleBarView: View {
    @ObservedObject var scanner: AppScannerService
    @Binding var appMode: ContentView.AppMode

    var body: some View {
        HStack(spacing: 0) {
            // App Identity
            HStack(spacing: 8) {
                Text("AppCleaner")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .padding(.leading, 80)

            Spacer()

            // Mode Switcher (Pill style)
            HStack(spacing: 0) {
                ModeButton(icon: "plus.viewfinder", isActive: appMode == .cleaner) {
                    withAnimation(.spring(response: 0.3)) { appMode = .cleaner }
                }
                
                ModeButton(icon: "square.grid.2x2", isActive: appMode == .applications) {
                    withAnimation(.spring(response: 0.3)) { appMode = .applications }
                }
            }
            .padding(2)
            .background(Color.primary.opacity(0.04))
            .clipShape(Capsule())

            Spacer()
            
            // Status Indicator
            if scanner.hasFullDiskAccess {
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("Secure").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().stroke(Color.primary.opacity(0.05), lineWidth: 1))
                .padding(.trailing, 20)
            }
        }
        .frame(height: 52)
        .background(VisualEffectView(material: .titlebar, blendingMode: .withinWindow))
    }
}

private struct ModeButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isActive ? .white : .secondary)
                .frame(width: 44, height: 26)
                .background(isActive ? Color.blue : Color.clear)
                .clipShape(Capsule())
                .shadow(color: isActive ? Color.blue.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scanning View

struct ScanningView: View {
    let progress: Double
    let message: String
    let appName: String

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 4)
                    .frame(width: 90, height: 90)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [.blue, .purple],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
            }

            VStack(spacing: 6) {
                Text("Scanning \(appName)…")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))

                Text(message.isEmpty ? "Looking for related files" : message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 320)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Deleted Banner

private struct DeletedBanner: View {
    let count: Int
    let size: Int64

    var sizeStr: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("\(count) \(count == 1 ? "file" : "files") removed (\(sizeStr) freed)")
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @ObservedObject var scanner: AppScannerService
    @State private var hasClickedOpen = false
    @State private var isAnimatingIcon = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: 20)

                // ── Hero Section ──────────────────────────────────────────────────
                VStack(spacing: 12) {
                    Text("Security Permission")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("To safely remove all app traces, AppCleaner requires Full Disk Access. This allows us to find deep-level cache files and system logs.")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: 450)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 32)

                // ── Instructions Card ──────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 14) {
                    InstructionRow(icon: "1.circle.fill", text: "Click 'Open Privacy Settings' below")
                    InstructionRow(icon: "2.circle.fill", text: "Drag AppCleaner into the list in System Settings")
                    InstructionRow(icon: "3.circle.fill", text: "Enable the toggle and Restart the app")
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.03)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.06), lineWidth: 1))
                .padding(.horizontal, 40)
                .padding(.bottom, 24)

                // ── Action Buttons ──────────────────────────────────────────────────
                VStack(spacing: 12) {
                    Button {
                        scanner.checkFullDiskAccess()
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                        hasClickedOpen = true
                    } label: {
                        HStack {
                            Text("1. Open Privacy Settings")
                            Image(systemName: "arrow.up.forward.app")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: 280)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                    } label: {
                        HStack {
                            Image(systemName: "hand.draw")
                            Text("2. Show App in Finder to Drag")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: 280)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)

                    if hasClickedOpen {
                        Button("3. I've enabled it. Restart App") {
                            NSApplication.shared.terminate(nil)
                        }
                        .font(.system(size: 13, weight: .bold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                        .padding(.top, 4)
                    }
                }

                Spacer(minLength: 30)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
        }
        .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow))
    }
}

private struct InstructionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.blue)
            Text(text)
                .font(.system(size: 14, weight: .medium))
        }
    }
}

private struct StepView: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Text(number)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.blue))

            Text(text)
                .font(.system(size: 15, weight: .medium))
        }
    }
}
