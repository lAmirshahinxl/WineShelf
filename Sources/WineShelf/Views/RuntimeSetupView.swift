import SwiftUI

struct RuntimeSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var setup = RuntimeSetupModel()
    let onSteamAdded: (GameEntry) -> Void
    let onDone: () -> Void

    init(onSteamAdded: @escaping (GameEntry) -> Void = { _ in }, onDone: @escaping () -> Void = {}) {
        self.onSteamAdded = onSteamAdded
        self.onDone = onDone
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView(.vertical) {
                setupContent
                    .padding(22)
            }
            Divider()
            footer
        }
        .frame(minWidth: 650, minHeight: 590)
        .alert("Wine Setup", isPresented: errorAlertIsPresented) {
            Button("OK", role: .cancel) { setup.errorMessage = nil }
        } message: {
            Text(setup.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Wine Setup").font(.title2.weight(.semibold))
                Text("Check this Mac's requirements and install a managed Wine runtime when needed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { setup.refresh() } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Check Wine, Rosetta, and GStreamer again")
            .accessibilityLabel("Check setup again")
        }
        .padding(22)
    }

    private var setupContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            rosettaCard
            if setup.isAppleSilicon && !setup.isRosettaAvailable {
                Text("Open Terminal, paste `softwareupdate --install-rosetta`, and accept Apple's license. WineShelf cannot accept that license for you.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 50)
            }
            gstreamerCard
            if !setup.isGStreamerInstalled {
                HStack(spacing: 6) {
                    Text("Package source:")
                    Button("gstreamer.freedesktop.org") { setup.openGStreamerSource() }
                        .buttonStyle(.link)
                }
                .font(.footnote)
                .padding(.leading, 50)
            }
            runtimeCard
            if let status = setup.statusMessage {
                Label(status, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(13)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityElement(children: .combine)
            }
            aboutCard
        }
    }

    private var rosettaCard: some View {
        RequirementCard(
            title: "Rosetta",
            subtitle: rosettaDescription,
            symbol: "cpu",
            ready: setup.isRosettaAvailable,
            actionTitle: setup.isRosettaAvailable ? nil : "Copy install command",
            action: { setup.openRosettaInstructions() }
        )
    }

    private var rosettaDescription: String {
        if !setup.isAppleSilicon { return "Not needed on this Intel Mac." }
        if setup.isRosettaAvailable { return "Ready for the Intel Wine build offered below." }
        return "Required to run this Intel Wine build on Apple silicon."
    }

    private var gstreamerCard: some View {
        RequirementCard(
            title: "GStreamer",
            subtitle: setup.isGStreamerInstalled
                ? "The required system framework is installed."
                : "Required by this Wine build. The verified official package installs for all users.",
            symbol: "waveform",
            ready: setup.isGStreamerInstalled,
            actionTitle: setup.isGStreamerInstalled ? nil : (setup.isDownloadingGStreamer ? "Downloading…" : "Download and open Installer"),
            action: { installGStreamer() },
            isBusy: setup.isDownloadingGStreamer
        )
    }

    private var runtimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "wineglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.tint)
                    .frame(width: 36, height: 36)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Wine runtime").font(.headline)
                    Text(setup.runtimes.isEmpty ? "No Wine runtime found." : "Choose a detected runtime or install WineShelf's managed build.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(ready: !setup.runtimes.isEmpty, text: setup.runtimes.isEmpty ? "Needed" : "Found")
            }

            if !setup.runtimes.isEmpty {
                Picker("Runtime", selection: $setup.selectedRuntimeID) {
                    ForEach(setup.runtimes) { runtime in
                        Text(runtime.name).tag(Optional(runtime.id))
                    }
                }
                .labelsHidden()

                if let runtime = setup.selectedRuntime {
                    Text(runtime.winePath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)

                    if runtime.bundleURL != nil {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "hand.raised").foregroundStyle(.orange)
                            Text("If macOS blocks Wine, Control-click the Wine app in Finder, choose Open, and confirm. This is a one-time macOS approval.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Button("Show Wine app in Finder", systemImage: "folder") {
                            setup.revealSelectedRuntime()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Button(action: installWine) {
                if setup.isDownloadingWine {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Downloading and verifying Wine…")
                    }
                } else {
                    Label(wineButtonTitle, systemImage: "arrow.down.circle")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(setup.isDownloadingWine || hasManagedWine)

            if setup.runtimes.isEmpty {
                Text("The archive is about 190 MB. WineShelf keeps it in your user Library and checks its SHA-256 digest before installation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Divider().padding(.vertical, 3)

            VStack(alignment: .leading, spacing: 8) {
                Text("Steam for Windows").font(.subheadline.weight(.semibold))
                Text("Download Valve's official Steam Setup, create a separate Wine prefix, and add Steam to your library after installation. Sign in and install games inside Steam.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: installSteam) {
                    if setup.isInstallingSteam {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Installing Steam in Wine…")
                        }
                    } else {
                        Label("Install Steam", systemImage: "square.and.arrow.down")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!canInstallSteam || setup.isInstallingSteam)
                if !canInstallSteam {
                    Text("Choose a Wine runtime and complete Rosetta and GStreamer setup first.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(15)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
    }

    private var wineButtonTitle: String {
        hasManagedWine
            ? "WineShelf Wine \(RuntimeSetupModel.wineVersion) is installed"
            : "Download and install Wine \(RuntimeSetupModel.wineVersion)"
    }

    private var hasManagedWine: Bool {
        setup.runtimes.contains(where: { $0.winePath.contains("/WineShelf/Runtimes/") })
    }

    private var canInstallSteam: Bool {
        setup.isRosettaAvailable && setup.isGStreamerInstalled && setup.selectedRuntime != nil
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("About this Wine build").font(.subheadline.weight(.medium))
            Text("WineShelf downloads Wine from Gcenx's macOS builds and verifies the published SHA-256 digest before unpacking. This build is x86_64 and needs Rosetta on Apple silicon. After installation, approve the Wine app in Finder using Control-click → Open. WineShelf does not disable Gatekeeper or remove quarantine attributes.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("View Wine release source") { setup.openWineSource() }
                .buttonStyle(.link)
                .font(.footnote)
        }
        .padding(.top, 4)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Done") {
                onDone()
                dismiss()
            }
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private var errorAlertIsPresented: Binding<Bool> {
        Binding(
            get: { setup.errorMessage != nil },
            set: { if !$0 { setup.errorMessage = nil } }
        )
    }

    private func installWine() {
        Task { await setup.installWine() }
    }

    private func installGStreamer() {
        Task { await setup.installGStreamer() }
    }

    private func installSteam() {
        Task {
            guard let entry = await setup.installSteam() else { return }
            onSteamAdded(entry)
            onDone()
            dismiss()
        }
    }
}

private struct RequirementCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let ready: Bool
    let actionTitle: String?
    let action: (() -> Void)?
    var isBusy = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    StatusBadge(ready: ready, text: ready ? "Ready" : "Needed")
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let action {
                    Button(action: action) {
                        HStack(spacing: 8) {
                            if isBusy { ProgressView().controlSize(.small) }
                            Text(actionTitle)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBusy)
                }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
    }
}

private struct StatusBadge: View {
    let ready: Bool
    let text: String

    var body: some View {
        Label(text, systemImage: ready ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(ready ? Color.green : Color.orange)
    }
}
