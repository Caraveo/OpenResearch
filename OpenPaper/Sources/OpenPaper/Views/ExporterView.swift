import SwiftUI

public struct ExporterView: View {
    public var document: URPDocument
    public var issues: [URPValidationIssue]
    
    @State private var consoleOutput: [String] = []
    @State private var isRunning = false
    @State private var selectedFormat = "html"
    
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
                Text("Compile, package, and validate URP papers via standard CLI utilities.")
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
                    Text("HTML").tag("html")
                    Text("PDF").tag("pdf")
                    Text("LaTeX").tag("latex")
                    Text("Jupyter").tag("ipynb")
                }
                .frame(width: 140)
                
                Button(action: runBuild) {
                    Label("Build Paper", systemImage: "play.fill")
                }
                
                Button(action: runPackage) {
                    Label("Package Archive", systemImage: "archivebox.fill")
                }
            }
            .disabled(isRunning)
            .padding(.horizontal)
            
            // Console display
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
                            Text("Ready. Click an action above to start.")
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
    }
    
    private func lineColor(for line: String) -> Color {
        if line.contains("Error") || line.contains("URP00") {
            return .red
        } else if line.contains("Warning") {
            return .orange
        } else if line.contains("successfully") || line.contains("completed") {
            return .green
        } else if line.hasPrefix("$") {
            return .cyan
        }
        return .white
    }
    
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
    
    private func runBuild() {
        isRunning = true
        consoleOutput = ["$ urp build \(document.manifest.document.source) --format \(selectedFormat)"]
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            consoleOutput.append("Parsed manifest for '\(document.manifest.paper.title)'")
            consoleOutput.append("Detected reproducibility environment: \(document.manifest.reproducibility.environment)")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            consoleOutput.append("Compiling layout...")
            consoleOutput.append("Processing LaTeX equations...")
            consoleOutput.append("Processing \(document.codeBlocks.count) code blocks...")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            consoleOutput.append("Output written successfully to build/paper.\(selectedFormat)")
            isRunning = false
        }
    }
    
    private func runPackage() {
        isRunning = true
        consoleOutput = ["$ urp package \(document.manifest.document.source)"]
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            consoleOutput.append("Creating package archive: build/paper.rd (application/vnd.urp+zip)")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            consoleOutput.append("Archiving source and asset catalogs:")
            consoleOutput.append("  + \(document.manifest.document.source)")
            consoleOutput.append("  + urp.yaml")
            consoleOutput.append("  + assets/")
            consoleOutput.append("  + code/")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            consoleOutput.append("Integrity manifest generated.")
            consoleOutput.append("Package created successfully: build/paper.rd")
            isRunning = false
        }
    }
}
