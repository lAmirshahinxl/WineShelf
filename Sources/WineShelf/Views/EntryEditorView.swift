import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct EntryEditorView: View {
    let entry: GameEntry?
    let onSave: (GameEntry) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var executablePath = ""
    @State private var prefixPath = ""
    @State private var winePath = ""
    @State private var wineServerPath = ""
    @State private var argumentText = ""
    @State private var environmentText = ""
    @State private var createNewPrefix = false
    @State private var isPreparing = false
    @State private var errorMessage: String?

    private var isEditing: Bool { entry != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isEditing ? "Edit Wine App" : "Add Windows App")
                        .font(.title2.weight(.semibold))
                    Text("A library entry keeps the app, prefix, and launch options together.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(22)

            Divider()

            Form {
                Section("APP") {
                    TextField("Name", text: $name)
                    PathField(title: "Windows executable", path: $executablePath, buttonTitle: "Choose…") {
                        chooseExecutable()
                    }
                }

                Section("WINE") {
                    PathField(title: "Wine prefix", path: $prefixPath, buttonTitle: "Choose…") { chooseDirectory(for: $prefixPath) }
                    Toggle("Create a new prefix with wineboot", isOn: $createNewPrefix)
                        .disabled(isEditing)
                    PathField(title: "Wine binary", path: $winePath, buttonTitle: "Choose…") { chooseFile(for: $winePath, title: "Choose the Wine binary") }
                    PathField(title: "Wineserver binary", path: $wineServerPath, buttonTitle: "Choose…") { chooseFile(for: $wineServerPath, title: "Choose the wineserver binary") }
                }

                Section("LAUNCH OPTIONS") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Arguments (one per line)").font(.subheadline)
                        TextEditor(text: $argumentText).font(.system(.body, design: .monospaced)).frame(minHeight: 62, maxHeight: 90)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Environment overrides (KEY=VALUE, one per line)").font(.subheadline)
                        TextEditor(text: $environmentText).font(.system(.body, design: .monospaced)).frame(minHeight: 70, maxHeight: 112)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 10)

            Divider()

            HStack {
                if isPreparing {
                    ProgressView().controlSize(.small)
                    Text("Initializing Wine prefix…").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction).disabled(isPreparing)
                Button(isEditing ? "Save Changes" : (createNewPrefix ? "Create Prefix & Add" : "Add to Library"), action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isPreparing || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(18)
        }
        .onAppear(perform: loadEntry)
        .alert("Couldn’t Save Entry", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func loadEntry() {
        guard let entry else { return }
        name = entry.name
        executablePath = entry.executablePath
        prefixPath = entry.prefixPath
        winePath = entry.winePath
        wineServerPath = entry.wineServerPath
        argumentText = entry.arguments.joined(separator: "\n")
        environmentText = entry.environment.keys.sorted().map { "\($0)=\(entry.environment[$0] ?? "")" }.joined(separator: "\n")
    }

    private func makeEntry() -> GameEntry {
        var result = entry ?? GameEntry(name: "", executablePath: "", prefixPath: "", winePath: "", wineServerPath: "")
        result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.executablePath = GameEntry.normalizedPath(executablePath)
        result.prefixPath = GameEntry.normalizedPath(prefixPath)
        result.winePath = GameEntry.normalizedPath(winePath)
        result.wineServerPath = GameEntry.normalizedPath(wineServerPath)
        result.arguments = argumentText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        result.environmentEditorText = environmentText
        return result
    }

    private func save() {
        let newEntry = makeEntry()
        do {
            try validatePaths(newEntry)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        if createNewPrefix {
            isPreparing = true
            let logURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/WineShelf/Logs", isDirectory: true)
                .appendingPathComponent("prefix-\(newEntry.id.uuidString).log")
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result { try WineRuntime.createPrefix(for: newEntry, logURL: logURL) }
                DispatchQueue.main.async {
                    isPreparing = false
                    switch result {
                    case .success: onSave(newEntry)
                    case .failure(let error): errorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            do {
                try WineRuntime.validate(newEntry)
                onSave(newEntry)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func validatePaths(_ candidate: GameEntry) throws {
        guard !candidate.name.isEmpty else { throw WineShelfError.processFailed("Enter a name for this app.") }
        guard !candidate.executablePath.isEmpty else { throw WineShelfError.processFailed("Choose the Windows app executable (.exe).") }
        guard !candidate.prefixPath.isEmpty else { throw WineShelfError.processFailed("Choose a Wine prefix folder.") }
        guard !candidate.winePath.isEmpty else { throw WineShelfError.processFailed("Choose the Wine binary.") }
        guard !candidate.wineServerPath.isEmpty else { throw WineShelfError.processFailed("Choose the wineserver binary.") }
        for key in candidate.environment.keys where !GameEntry.validEnvironmentKey(key) {
            throw WineShelfError.invalidEnvironment(key)
        }
        guard FileManager.default.isReadableFile(atPath: candidate.executablePath) else { throw WineShelfError.missingFile(candidate.executablePath) }
        guard FileManager.default.isExecutableFile(atPath: candidate.winePath) else { throw WineShelfError.missingFile(candidate.winePath) }
        guard FileManager.default.isExecutableFile(atPath: candidate.wineServerPath) else { throw WineShelfError.missingFile(candidate.wineServerPath) }
        if createNewPrefix {
            if FileManager.default.fileExists(atPath: candidate.prefixURL.appendingPathComponent("system.reg").path) {
                throw WineShelfError.alreadyInitialized(candidate.prefixPath)
            }
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: candidate.prefixPath), !contents.isEmpty {
                throw WineShelfError.occupiedPrefix(candidate.prefixPath)
            }
        } else if !FileManager.default.fileExists(atPath: candidate.prefixURL.appendingPathComponent("system.reg").path) {
            throw WineShelfError.invalidPrefix(candidate.prefixPath)
        }
    }

    private func chooseExecutable() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Windows application"
        panel.allowedContentTypes = [UTType(filenameExtension: "exe") ?? .data]
        panel.allowsOtherFileTypes = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            executablePath = url.path
            if name.isEmpty { name = url.deletingPathExtension().lastPathComponent }
        }
    }

    private func chooseDirectory(for binding: Binding<String>) {
        let panel = NSOpenPanel()
        panel.title = "Choose a Wine prefix folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsOtherFileTypes = true
        if panel.runModal() == .OK, let url = panel.url { binding.wrappedValue = url.path }
    }

    private func chooseFile(for binding: Binding<String>, title: String) {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsOtherFileTypes = true
        if panel.runModal() == .OK, let url = panel.url { binding.wrappedValue = url.path }
    }
}

private struct PathField: View {
    let title: String
    @Binding var path: String
    let buttonTitle: String
    let choose: () -> Void

    var body: some View {
        HStack {
            TextField(title, text: $path)
                .textFieldStyle(.roundedBorder)
            Button(buttonTitle, action: choose)
        }
        .accessibilityLabel(title)
    }
}
