import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var sourceURL: URL?
    @State private var name: String = ""
    @State private var useClone = true
    @State private var convertPict = false
    @State private var extractSit = false
    @State private var onlyPattern: String = "Starmax*"
    @State private var log: String = ""
    @State private var isRunning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Starmax")
                .font(.title2.bold())

            GroupBox("Source") {
                HStack {
                    Text(sourceURL?.path ?? "No folder selected")
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose Folder…") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK {
                            sourceURL = panel.url
                            if name.isEmpty {
                                name = panel.url?.lastPathComponent ?? ""
                            }
                        }
                    }
                }
            }

            GroupBox("Options") {
                TextField("Name", text: $name)
                Toggle("Clone (full unmodified extract)", isOn: $useClone)
                Toggle("Convert PICT → PNG", isOn: $convertPict)
                Toggle("Extract StuffIt", isOn: $extractSit)
                TextField("Batch --only pattern", text: $onlyPattern)
            }

            HStack {
                Button("Rescue this folder") {
                    runRescue()
                }
                .disabled(sourceURL == nil || isRunning)

                Button("Batch parent folder") {
                    runBatch()
                }
                .disabled(sourceURL == nil || isRunning)

                if isRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            GroupBox("Log") {
                ScrollView {
                    Text(log)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 200)
            }
        }
        .padding()
        .frame(minWidth: 640, minHeight: 480)
    }

    private func append(_ text: String) {
        DispatchQueue.main.async {
            log += text
            if !text.hasSuffix("\n") { log += "\n" }
        }
    }

    private func scriptPath(_ name: String) -> String? {
        // Look relative to repo or next to the app
        let candidates = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("scripts/\(name)"),
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("scripts/\(name)"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Dev/Starmax/scripts/\(name)")
        ]
        for url in candidates where FileManager.default.isExecutableFile(atPath: url.path) {
            return url.path
        }
        return nil
    }

    private func runRescue() {
        guard let src = sourceURL else { return }
        guard let script = scriptPath("rescue-cd.sh") else {
            append("ERROR: rescue-cd.sh not found")
            return
        }
        var args = ["--src", src.path, "--name", name.isEmpty ? src.lastPathComponent : name, "--go"]
        if useClone { args.append("--clone") }
        if convertPict { args.append("--convert-pict") }
        if extractSit { args.append("--extract-sit") }
        run(script: script, args: args)
    }

    private func runBatch() {
        guard let src = sourceURL else { return }
        guard let script = scriptPath("batch-rescue.sh") else {
            append("ERROR: batch-rescue.sh not found")
            return
        }
        var args = ["--only", onlyPattern]
        if useClone { args.append("--clone") }
        if convertPict { args.append("--convert-pict") }
        if extractSit { args.append("--extract-sit") }
        args.append(src.path)
        run(script: script, args: args)
    }

    private func run(script: String, args: [String]) {
        isRunning = true
        log = ""
        append("$ \(script) \(args.joined(separator: " "))\n")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: script)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                append(str)
            }
        }

        process.terminationHandler = { _ in
            DispatchQueue.main.async {
                isRunning = false
                append("\n--- finished ---")
            }
        }

        do {
            try process.run()
        } catch {
            append("Failed to start: \(error)")
            isRunning = false
        }
    }
}
