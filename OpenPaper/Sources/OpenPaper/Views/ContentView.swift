import SwiftUI
import AppKit
import PDFKit
import UniformTypeIdentifiers

public struct ContentView: View {
    @State private var document: URPDocument? = nil
    @State private var openedFilePath: String = ""
    @State private var consoleOutput: [String] = []
    @State private var isProcessing = false
    @State private var lastExportError: String? = nil
    @State private var showExportError = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                LogoView(size: 20)

                Text("OpenPaper")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundStyle(.primary)

                Text("Reader & Publisher")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())



                Spacer()

                Button(action: openFile) {
                    Label("Open .rd Package", systemImage: "doc.badge.plus")
                }
                .disabled(isProcessing)

                if document != nil {
                    Button(action: runPrint) {
                        Label("Print…", systemImage: "printer.fill")
                    }
                    .disabled(isProcessing)

                    Button(action: exportAsPDF) {
                        Label("Save as PDF", systemImage: "doc.richtext")
                    }
                    .disabled(isProcessing)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            if isProcessing {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView()
                        .progressViewStyle(.linear)
                    ForEach(consoleOutput, id: \.self) { line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .transition(.slide)
            }

            if let doc = document {
                DocumentPreviewView(document: doc)
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Open an OpenResearch URP (.rd) package to view")
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(.secondary)
                    Text("Select a compiled package containing coordinate schemas, claims, and topology models.")
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                    Button(action: openFile) {
                        Text("Select .rd File")
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .frame(minWidth: 800, minHeight: 650)
        .alert("Export failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lastExportError ?? "Unknown error")
        }
    }

    // MARK: - Open -----------------------------------------------------------

    private func openFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.init(filenameExtension: "rd")!]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.begin { response in
            if response == .OK, let fileURL = openPanel.url {
                loadPackage(at: fileURL)
            }
        }
    }

    private func loadPackage(at url: URL) {
        isProcessing = true
        consoleOutput = ["$ urp load \(url.lastPathComponent)"]

        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            consoleOutput.append("Extracting platform-agnostic URP package container...")

            do {
                try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)

                if UnzipHelper.unzip(zipPath: url.path, to: tempDir.path) {
                    consoleOutput.append("Package unzipped successfully.")
                    let paperMdPath = tempDir.appendingPathComponent("paper.rd.md").path

                    if fileManager.fileExists(atPath: paperMdPath) {
                        consoleOutput.append("Loading document paper.rd.md...")
                        let rawContent = try String(contentsOfFile: paperMdPath, encoding: .utf8)

                        let parsedDoc = URPDocument(rawContent: rawContent)
                        document = parsedDoc
                        openedFilePath = url.path
                        consoleOutput.append("Document '\(parsedDoc.manifest.paper.title)' loaded.")
                        consoleOutput.append("Parsed \(parsedDoc.sections.count) sections, \(parsedDoc.claims.count) claims, \(parsedDoc.equations.count) equations, \(parsedDoc.codeBlocks.count) code blocks.")
                    } else {
                        consoleOutput.append("Error: paper.rd.md file not found in package.")
                    }
                } else {
                    consoleOutput.append("Error unzipping .rd package.")
                }

                withAnimation { isProcessing = false }
            } catch {
                consoleOutput.append("Error: \(error.localizedDescription)")
                withAnimation { isProcessing = false }
            }
        }
    }

    // MARK: - Export ---------------------------------------------------------

    private func runPrint() {
        guard let doc = document else { return }
        isProcessing = true
        consoleOutput = ["$ urp print \(doc.manifest.document.source) --print"]

        consoleOutput.append("Rendering document to PDF for native print dialog...")
        URPExporter.generatePDF(for: doc) { result in
            switch result {
            case .success(let pdfData):
                consoleOutput.append("PDF ready (\(pdfData.count) bytes). Opening print panel...")
                withAnimation { isProcessing = false }
                presentPrintDialog(pdfData: pdfData)
            case .failure(let error):
                consoleOutput.append("Error producing print PDF: \(error.localizedDescription)")
                lastExportError = error.localizedDescription
                showExportError = true
                withAnimation { isProcessing = false }
            }
        }
    }

    private func exportAsPDF() {
        guard let doc = document else { return }
        isProcessing = true
        consoleOutput = ["$ urp build \(doc.manifest.document.source) --format pdf"]
        consoleOutput.append("Compiling '\(doc.manifest.paper.title)' into PDF...")

        URPExporter.generatePDF(for: doc) { result in
            switch result {
            case .success(let data):
                self.consoleOutput.append("Generated \(data.count) bytes of PDF content.")
                let savePanel = NSSavePanel()
                savePanel.title = "Save as PDF"
                savePanel.allowedContentTypes = [.pdf]
                savePanel.allowsOtherFileTypes = false
                savePanel.nameFieldStringValue = self.defaultFilename(for: doc)
                savePanel.canCreateDirectories = true
                savePanel.begin { resp in
                    if resp == .OK, let url = savePanel.url {
                        do {
                            if FileManager.default.fileExists(atPath: url.path) {
                                try FileManager.default.removeItem(at: url)
                            }
                            try data.write(to: url)
                            self.consoleOutput.append("Exported successfully: \(url.path)")
                        } catch {
                            self.consoleOutput.append("Error writing file: \(error.localizedDescription)")
                            self.lastExportError = error.localizedDescription
                            self.showExportError = true
                        }
                    } else {
                        self.consoleOutput.append("Export cancelled.")
                    }
                    withAnimation { self.isProcessing = false }
                }
            case .failure(let error):
                self.consoleOutput.append("Error producing PDF: \(error.localizedDescription)")
                self.lastExportError = error.localizedDescription
                self.showExportError = true
                withAnimation { self.isProcessing = false }
            }
        }
    }

    private func defaultFilename(for doc: URPDocument) -> String {
        let cleaned = doc.manifest.paper.title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let base = cleaned.isEmpty ? "paper" : cleaned
        let trimmed = base.replacingOccurrences(of: "[^a-z0-9-]+", with: "", options: .regularExpression)
        return trimmed.isEmpty ? "paper.pdf" : "\(trimmed).pdf"
    }

    // MARK: - Native Print Dialog --------------------------------------------

    private func presentPrintDialog(pdfData: Data) {
        guard let pdfDoc = PDFDocument(data: pdfData) else {
            lastExportError = "Could not open the generated PDF for printing."
            showExportError = true
            return
        }
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = pdfDoc

        let printInfo = NSPrintInfo.shared
        printInfo.scalingFactor = 1.0
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit
        printInfo.leftMargin = 36; printInfo.rightMargin = 36
        printInfo.topMargin = 36; printInfo.bottomMargin = 36

        let operation = NSPrintOperation(view: pdfView, printInfo: printInfo)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true

        guard let window = NSApp.windows.first(where: { $0.isVisible }) else {
            lastExportError = "No visible window to attach the print dialog to."
            showExportError = true
            return
        }
        operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        _ = window
    }
}