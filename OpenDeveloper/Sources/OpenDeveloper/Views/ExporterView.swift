import SwiftUI
import AppKit
import PDFKit
import UniformTypeIdentifiers

public struct ExporterView: View {
    public var document: URPDocument
    public var issues: [URPValidationIssue]

    @State private var consoleOutput: [String] = []
    @State private var isRunning = false
    @State private var selectedFormat: URPExportFormat = .html
    @State private var lastError: String? = nil
    @State private var showError = false

    public init(document: URPDocument, issues: [URPValidationIssue]) {
        self.document = document
        self.issues = issues
    }

    public var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("URP Command Center")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Compile, package, and export URP papers to HTML, PDF, Word, EPUB, LaTeX, and Markdown.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.top, .horizontal])

            HStack(spacing: 12) {
                Button(action: runValidate) {
                    Label("Validate Paper", systemImage: "checkmark.shield")
                }

                Picker("Format", selection: $selectedFormat) {
                    Text("HTML").tag(URPExportFormat.html)
                    Text("PDF").tag(URPExportFormat.pdf)
                    Text("Word (.docx)").tag(URPExportFormat.docx)
                    Text("EPUB").tag(URPExportFormat.epub)
                    Text("LaTeX").tag(URPExportFormat.latex)
                    Text("Markdown").tag(URPExportFormat.markdown)
                }
                .frame(width: 180)

                Button(action: runBuild) {
                    Label("Build & Export", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button(action: runPackage) {
                    Label("Package .rd", systemImage: "archivebox.fill")
                }
            }
            .disabled(isRunning)
            .padding(.horizontal)

            VStack(spacing: 0) {
                HStack {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Circle().fill(Color.yellow).frame(width: 8, height: 8)
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Spacer()
                    Text("urp-terminal")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: { consoleOutput.removeAll() }) {
                        Image(systemName: "trash")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if consoleOutput.isEmpty {
                            Text("Ready. Select a format and click Build & Export.")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            ForEach(consoleOutput, id: \.self) { line in
                                Text(line)
                                    .foregroundStyle(lineColor(for: line))
                            }
                        }
                    }
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.black)
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .padding([.bottom, .horizontal])
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Export failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lastError ?? "Unknown error")
        }
    }

    private func lineColor(for line: String) -> Color {
        if line.contains("Error") || line.contains("URP00") {
            return .red
        } else if line.contains("Warning") {
            return .orange
        } else if line.contains("successfully") || line.contains("Exported") {
            return .green
        } else if line.hasPrefix("$") {
            return .cyan
        }
        return .white
    }

    // MARK: - Validate

    private func runValidate() {
        isRunning = true
        consoleOutput = ["$ urp validate \(document.manifest.document.source)"]

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            consoleOutput.append("Validating paper structure and manifest specifications...")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            consoleOutput.append("URP validation completed.")
            let errors = issues.filter { $0.severity == .error }.count
            let warnings = issues.filter { $0.severity == .warning }.count
            consoleOutput.append("Errors:   \(errors)")
            consoleOutput.append("Warnings: \(warnings)")

            for issue in issues {
                consoleOutput.append("")
                consoleOutput.append("\(issue.code) (\(issue.severity.rawValue)):")
                consoleOutput.append("  \(issue.message)")
            }
            isRunning = false
        }
    }

    // MARK: - Build & Export (real)

    private func runBuild() {
        isRunning = true
        let fmt = selectedFormat
        consoleOutput = ["$ urp build \(document.manifest.document.source) --format \(fmt.fileExtension)"]
        consoleOutput.append("Compiling '\(document.manifest.paper.title)' into \(fmt.displayName)...")

        switch fmt {
        case .epub:
            do {
                let data = try URPExporter.generateEPUB(for: document)
                finishExport(format: fmt, data: data)
            } catch {
                fail(with: error)
            }
        case .pdf:
            URPExporter.generatePDF(for: document) { result in
                switch result {
                case .success(let data):
                    self.finishExport(format: fmt, data: data)
                case .failure(let error):
                    self.fail(with: error)
                }
            }
        case .html:
            finishExport(format: fmt, text: URPExporter.generateHTML(for: document))
        case .docx, .doc:
            finishExport(format: fmt, text: URPExporter.generateWord(for: document))
        case .latex, .tex:
            finishExport(format: fmt, text: URPExporter.generateLaTeX(for: document))
        case .markdown, .md:
            finishExport(format: fmt, text: URPExporter.generateMarkdown(for: document))
        }
    }

    private func finishExport(format: URPExportFormat, text: String) {
        finishExport(format: format, data: Data(text.utf8))
    }

    private func finishExport(format: URPExportFormat, data: Data) {
        consoleOutput.append("Generated \(data.count) bytes of \(format.fileExtension.uppercased()) content.")

        let savePanel = NSSavePanel()
        savePanel.title = "Export as \(format.displayName)"
        if let ut = format.utType {
            savePanel.allowedContentTypes = [ut]
        }
        savePanel.nameFieldStringValue = defaultFilename(for: format)
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                    try data.write(to: url)
                    self.consoleOutput.append("Exported successfully: \(url.path)")
                } catch {
                    self.fail(with: error)
                }
            } else {
                self.consoleOutput.append("Export cancelled.")
            }
            withAnimation { self.isRunning = false }
        }
    }

    private func fail(with error: Error) {
        consoleOutput.append("Error: \(error.localizedDescription)")
        lastError = error.localizedDescription
        showError = true
        withAnimation { isRunning = false }
    }

    private func defaultFilename(for format: URPExportFormat) -> String {
        let cleaned = document.manifest.paper.title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let base = cleaned.isEmpty ? "paper" : cleaned
        let trimmed = base.replacingOccurrences(of: "[^a-z0-9-]+", with: "", options: .regularExpression)
        return trimmed.isEmpty ? "paper.\(format.fileExtension)" : "\(trimmed).\(format.fileExtension)"
    }

    // MARK: - Package .rd

    private func runPackage() {
        isRunning = true
        consoleOutput = ["$ urp package \(document.manifest.document.source)"]

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            consoleOutput.append("Archiving paper.rd.md + urp.yaml into application/vnd.urp+zip...")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            let fm = FileManager.default
            let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            do {
                try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
                try document.rawContent.write(
                    to: tempDir.appendingPathComponent("paper.rd.md"),
                    atomically: true, encoding: .utf8)
                let yaml = """
                urp: "\(document.manifest.urp)"
                paper:
                  id: "\(document.manifest.paper.id)"
                  title: "\(document.manifest.paper.title)"
                  status: "\(document.manifest.paper.status)"
                """
                try yaml.write(to: tempDir.appendingPathComponent("urp.yaml"), atomically: true, encoding: .utf8)

                let tempZip = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".rd")
                if ZipHelper.zip(directoryPath: tempDir.path, to: tempZip.path) {
                    let savePanel = NSSavePanel()
                    savePanel.allowedContentTypes = [.init(filenameExtension: "rd")!]
                    savePanel.nameFieldStringValue = "paper.rd"
                    savePanel.canCreateDirectories = true
                    savePanel.begin { resp in
                        if resp == .OK, let url = savePanel.url {
                            do {
                                if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
                                try fm.copyItem(at: tempZip, to: url)
                                self.consoleOutput.append("Package created successfully: \(url.path)")
                            } catch {
                                self.fail(with: error)
                                return
                            }
                        } else {
                            self.consoleOutput.append("Package cancelled.")
                        }
                        try? fm.removeItem(at: tempDir)
                        try? fm.removeItem(at: tempZip)
                        withAnimation { self.isRunning = false }
                    }
                } else {
                    self.fail(with: NSError(domain: "URP", code: 1, userInfo: [NSLocalizedDescriptionKey: "zip failed"]))
                }
            } catch {
                self.fail(with: error)
            }
        }
    }
}