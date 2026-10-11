import AppKit
import SwiftUI

struct RuntimeSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var setup = RuntimeSetupModel()
    @State private var isShowingAdvancedOptions = false

    let onSteamAdded: (GameEntry) -> Void
    let onDone: () -> Void
    init(
        onSteamAdded: @escaping (GameEntry) -> Void = { _ in },
        onDone: @escaping () -> Void = {}
    ) {
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
        .frame(minWidth: 570, minHeight: 500)
        .task {
            await setup.prepareWineAutomatically()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            setup.refresh()
            Task { await setup.resumeAutomaticSetupAfterSystemStep() }
        }
        .alert("Wine Setup", isPresented: errorAlertIsPresented) {
            Button("OK", role: .cancel) { setup.errorMessage = nil }
        } message: {
            Text(setup.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Wine Setup").font(.title2.weight(.semibold))
                Text("WineShelf checks this Mac and installs what Windows apps need.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                setup.refresh()
                Task { await setup.resumeAutomaticSetupAfterSystemStep() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Check setup again")
            .accessibilityLabel("Check setup again")
        }
        .padding(22)
    }

    private var setupContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            introCard
            requirementsCard

            if !setup.isReadyForWindowsApps {
                Button {
                    if setup.isWaitingForWineApproval {
                        setup.continueAfterWineApproval()
                    } else {
                        Task { await setup.prepareWineAutomatically() }
                    }
                } label: {
                    HStack(spacing: 10) {
                        if setup.isPreparingWine || setup.isDownloadingWine || setup.isDownloadingGStreamer {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                        Text(setup.nextSetupActionTitle)
                        Spacer()
                        if !setup.isPreparingWine && !setup.isDownloadingWine && !setup.isDownloadingGStreamer {
                            Image(systemName: "arrow.right")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(setup.isPreparingWine || setup.isDownloadingWine || setup.isDownloadingGStreamer)
            }

            if let status = setup.statusMessage {
                Label(status, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(13)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityElement(children: .combine)
            }

            if setup.isReadyForWindowsApps {
                steamCard
            }

            advancedOptions
        }
    }

    private var introCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: setup.isReadyForWindowsApps ? "checkmark.circle.fill" : "wineglass")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(setup.isReadyForWindowsApps ? Color.green : Color.accentColor)
                .frame(width: 42, height: 42)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text(setup.isWaitingForWineApproval
                     ? "Approve Wine in Finder"
                     : (setup.isReadyForWindowsApps ? "Ready for Windows apps" : "Set up Wine automatically"))
                    .font(.headline)
                Text(setup.isWaitingForWineApproval
                     ? "Control-click the Wine app in Finder, choose Open, and confirm. Then return here and continue."
                     : (setup.isReadyForWindowsApps
                        ? "Wine and its required components are ready on this Mac."
                        : "WineShelf checks what's installed, downloads missing components, and guides any macOS approval."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
    }

    private var requirementsCard: some View {
        VStack(spacing: 0) {
            SetupRequirementRow(
                title: "Rosetta",
                detail: setup.isAppleSilicon ? "Needed to run the Wine build on Apple silicon." : "Not needed on this Intel Mac.",
                isReady: !setup.isAppleSilicon || setup.isRosettaAvailable,
                state: !setup.isAppleSilicon ? "Not needed" : (setup.isRosettaAvailable ? "Ready" : "Needed")
            )
            Divider()
            SetupRequirementRow(
                title: "GStreamer",
                detail: "Required support files for Wine.",
                isReady: setup.isGStreamerInstalled,
                state: setup.isGStreamerInstalled ? "Ready" : (setup.isWaitingForGStreamerInstaller ? "Finish Installer" : "Automatic")
            )
            Divider()
            SetupRequirementRow(
                title: "Wine runtime",
                detail: setup.isWaitingForWineApproval
                    ? "Control-click Wine in Finder, choose Open, confirm, then continue here."
                    : (setup.selectedRuntime?.name ?? "WineShelf installs Wine when no runtime is found."),
                isReady: setup.selectedRuntime != nil && !setup.isWaitingForWineApproval,
                state: setup.isWaitingForWineApproval ? "Approve in Finder" : (setup.selectedRuntime == nil ? "Automatic" : "Ready")
            )
        }
        .padding(.horizontal, 14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
    }

    private var steamCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(.tint)
                Text("Steam is optional")
                    .font(.headline)
            }
            Text("Install Steam in its own Wine prefix, then sign in and install games inside Steam.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: installSteam) {
                if setup.isInstallingSteam {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Installing Steam…")
                    }
                } else {
                    Label("Install Steam", systemImage: "square.and.arrow.down")
                }
            }
            .buttonStyle(.bordered)
            .disabled(setup.isInstallingSteam)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
    }

    private var advancedOptions: some View {
        DisclosureGroup("Advanced options", isExpanded: $isShowingAdvancedOptions) {
            VStack(alignment: .leading, spacing: 12) {
                if setup.runtimes.isEmpty {
                    Text("No existing Wine runtime was found. WineShelf will install one when you start setup.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Wine runtime", selection: $setup.selectedRuntimeID) {
                        ForEach(setup.runtimes) { runtime in
                            Text(runtime.name).tag(Optional(runtime.id))
                        }
                    }
                    if let runtime = setup.selectedRuntime {
                        Text(runtime.winePath)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                        if runtime.bundleURL != nil {
                            Button("Show Wine in Finder", systemImage: "folder") {
                                setup.revealSelectedRuntime()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                Button("View Wine source") { setup.openWineSource() }
                    .buttonStyle(.link)
                    .font(.footnote)
            }
            .padding(.top, 10)
        }
        .font(.subheadline.weight(.medium))
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
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

    private func installSteam() {
        Task {
            guard let entry = await setup.installSteam() else { return }
            onSteamAdded(entry)
            onDone()
            dismiss()
        }
    }
}

private struct SetupRequirementRow: View {
    let title: String
    let detail: String
    let isReady: Bool
    let state: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isReady ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 18))
                .foregroundStyle(isReady ? Color.green : Color.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 10)
            Text(state)
                .font(.caption.weight(.medium))
                .foregroundStyle(isReady ? Color.green : Color.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
