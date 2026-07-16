import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct ContentView: View {
    @State private var document: URPDocument = URPDocument()
    @State private var saveStatus: String = ""
    @State private var showSavedAlert = false
    @State private var currentFileURL: URL? = nil
    @State private var showError = false
    @State private var lastError: String = ""

    // Focus state to guarantee clicks on padded containers focus the editor instantly
    public enum Field: Hashable {
        case title
        case subtitle
        case authorName
        case affiliation
        case abstract
        case problem
        case methodology
        case architecture
        case research
        case claimId
        case claimSources
        case claimBody
        case limitations
        case conclusion
        case references
    }
    @FocusState private var focusedField: Field?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Premium App Navigation Header
            HStack(spacing: 12) {
                LogoView(size: 20)

                Text("OpenWriter")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundStyle(.primary)

                Text("URP Standard 0.1")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())

                if let url = currentFileURL {
                    Text(url.lastPathComponent)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.08))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }

                Spacer()

                if !saveStatus.isEmpty {
                    Text(saveStatus)
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }

                Button(action: newDocument) {
                    Label("New", systemImage: "doc")
                }

                Button(action: openDocument) {
                    Label("Open…", systemImage: "doc.badge.plus")
                }

                Button(action: saveDocument) {
                    Label(currentFileURL == nil ? "Save as .rd" : "Save",
                          systemImage: currentFileURL == nil ? "arrow.down.doc.fill" : "checkmark.circle.fill")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()
            
            // Single-Column distraction-free writing canvas (foco-style inline sheet)
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    
                    // 1. Title Page Header Area (Inline Editable)
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Paper Title", text: $document.manifest.paper.title)
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .textFieldStyle(.plain)
                            .foregroundStyle(.primary)
                            .focused($focusedField, equals: .title)
                        
                        TextField("Subtitle / Abstract Concept", text: $document.manifest.paper.subtitle)
                            .font(.system(.title3, design: .serif))
                            .textFieldStyle(.plain)
                            .foregroundStyle(.secondary)
                            .focused($focusedField, equals: .subtitle)
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Inline Editable Author Affiliation
                        if !document.manifest.authors.isEmpty {
                            HStack {
                                TextField("Author Name", text: $document.manifest.authors[0].name)
                                    .font(.system(.body, design: .serif).bold())
                                    .textFieldStyle(.plain)
                                    .frame(width: 140)
                                    .focused($focusedField, equals: .authorName)
                                
                                Text("•")
                                    .foregroundStyle(.tertiary)
                                
                                TextField("Affiliation", text: $document.manifest.authors[0].affiliation)
                                    .font(.system(.body, design: .serif))
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(.secondary)
                                    .focused($focusedField, equals: .affiliation)
                            }
                        }
                    }
                    
                    // 2. Table of Contents (Auto-Generated, Non-Interactive)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text("📑")
                                .font(.title3)
                            Text("Table of Contents")
                                .font(.system(.headline, design: .serif))
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                        }
                        .padding(.bottom, 4)
                        
                        let tocItems = buildTOC()
                        ForEach(tocItems) { item in
                            HStack {
                                Text(item.title)
                                    .font(.system(item.isRequiredSection ? .body : .subheadline, design: .serif))
                                    .fontWeight(item.isRequiredSection ? .bold : .regular)
                                    .foregroundStyle(item.isRequiredSection ? .primary : .secondary)
                                    .padding(.leading, item.indent)
                                Spacer()
                                if item.isRequiredSection {
                                    Text("§")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        Divider()
                            .padding(.top, 8)
                    }
                    .padding(.vertical, 8)
                    
                    // 3. Document Sections (Non-removable, Inline TextEditors using multi-line TextField to fix focus jumping)
                    
                    // --- ABSTRACT ---
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Abstract")
                            .font(.system(.title2, design: .serif))
                            .fontWeight(.bold)

                        FocoSectionEditor(
                            text: $document.abstract,
                            placeholder: "Write abstract…",
                            field: .abstract,
                            focusedField: $focusedField
                        )
                        .padding(12)
                        .background(Color.secondary.opacity(0.03))
                        .cornerRadius(8)
                    }
                    
                    // --- PROBLEM ---
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Problem")
                            .font(.system(.title2, design: .serif))
                            .fontWeight(.bold)

                        FocoSectionEditor(
                            text: $document.problem,
                            placeholder: "Write problem statement…",
                            field: .problem,
                            focusedField: $focusedField
                        )
                        .padding(12)
                        .background(Color.secondary.opacity(0.03))
                        .cornerRadius(8)
                    }
                             // --- METHODOLOGY ---
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Methodology")
                            .font(.system(.title2, design: .serif))
                            .fontWeight(.bold)

                        FocoSectionEditor(
                            text: $document.methodology,
                            placeholder: "Write methodology…",
                            field: .methodology,
                            focusedField: $focusedField
                        )
                        .padding(12)
                        .background(Color.secondary.opacity(0.03))
                        .cornerRadius(8)
                    }
                    
                    // --- ARCHITECTURE ---
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Architecture")
                            .font(.system(.title2, design: .serif))
                            .fontWeight(.bold)

                        FocoSectionEditor(
                            text: $document.architecture,
                            placeholder: "Write architecture & diagram…",
                            field: .architecture,
                            focusedField: $focusedField
                        )
                        .padding(12)
                        .background(Color.secondary.opacity(0.03))
                        .cornerRadius(8)
                    }
                    

                    // --- RESEARCH (the main content / the juice) ---
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Research")
                            .font(.system(.title2, design: .serif))
                            .fontWeight(.bold)

                        FocoSectionEditor(
                            text: $document.research,
                            placeholder: "Write the research body…",
                            field: .research,
                            focusedField: $focusedField
                        )
                        .padding(12)
                        .background(Color.secondary.opacity(0.02))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
                        .padding(.vertical, 6)
                    }

                    // --- RESULTS ---
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Results & Claims")
                            .font(.system(.title2, design: .serif))
                            .fontWeight(.bold)
                        
                        // Claim Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Empirical Claim Specifications", systemImage: "checkmark.circle")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.orange)
                                Spacer()
                                TextField("ID", text: $document.claim.id)
                                    .font(.system(.caption2, design: .monospaced))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                                    .focused($focusedField, equals: .claimId)
                            }
                            
                            HStack {
                                Picker("Type", selection: $document.claim.type) {
                                    Text("empirical").tag("empirical")
                                    Text("theoretical").tag("theoretical")
                                    Text("design").tag("design")
                                }
                                .frame(width: 140)
                                
                                Picker("Confidence", selection: $document.claim.confidence) {
                                    Text("high").tag("high")
                                    Text("moderate").tag("moderate")
                                    Text("speculative").tag("speculative")
                                }
                                .frame(width: 140)
                                
                                TextField("Sources", text: $document.claim.sources)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: .claimSources)
                            }
                            
                            TextField("Claim statement...", text: $document.claim.body, axis: .vertical)
                                .font(.system(.body, design: .serif))
                                .lineLimit(2...5)
                                .padding(8)
                                .background(Color.black.opacity(0.05))
                                .cornerRadius(6)
                                .textFieldStyle(.plain)
                                .focused($focusedField, equals: .claimBody)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    focusedField = .claimBody
                                }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.02))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
                    }
                    
                    // --- LIMITATIONS ---
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Limitations")
                            .font(.system(.title2, design: .serif))
                            .fontWeight(.bold)

                        FocoSectionEditor(
                            text: $document.limitations,
                            placeholder: "Write limitations…",
                            field: .limitations,
                            focusedField: $focusedField
                        )
                        .padding(12)
                        .background(Color.secondary.opacity(0.03))
                        .cornerRadius(8)
                    }

                    // --- CONCLUSION ---
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Conclusion")
                            .font(.system(.title2, design: .serif))
                            .fontWeight(.bold)

                        FocoSectionEditor(
                            text: $document.conclusion,
                            placeholder: "Write conclusion…",
                            field: .conclusion,
                            focusedField: $focusedField
                        )
                        .padding(12)
                        .background(Color.secondary.opacity(0.03))
                        .cornerRadius(8)
                    }

                    // --- REFERENCES ---
                    VStack(alignment: .leading, spacing: 8) {
                        Text("References")
                            .font(.system(.title2, design: .serif))
                            .fontWeight(.bold)

                        FocoSectionEditor(
                            text: $document.references,
                            placeholder: "Write references…",
                            field: .references,
                            focusedField: $focusedField
                        )
                        .padding(12)
                        .background(Color.secondary.opacity(0.03))
                        .cornerRadius(8)
                    }
                }
                .padding(48)
                .frame(maxWidth: 750)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(minWidth: 800, minHeight: 650)
        .alert("OpenWriter", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lastError)
        }
    }

    private func newDocument() {
        document = URPDocument()
        currentFileURL = nil
        saveStatus = ""
        focusedField = .title
    }

    struct TOCItem: Identifiable {
        let id = UUID()
        let title: String
        let indent: CGFloat
        let isRequiredSection: Bool
    }

    private func buildTOC() -> [TOCItem] {
        var items: [TOCItem] = []
        
        items.append(TOCItem(title: "Abstract", indent: 0, isRequiredSection: true))
        items.append(TOCItem(title: "Problem", indent: 0, isRequiredSection: true))
        
        items.append(TOCItem(title: "Methodology", indent: 0, isRequiredSection: true))
        for line in document.methodology.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("## ") {
                let sub = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                items.append(TOCItem(title: sub, indent: 12, isRequiredSection: false))
            } else if trimmed.hasPrefix("### ") {
                let sub = trimmed.dropFirst(4).trimmingCharacters(in: .whitespaces)
                items.append(TOCItem(title: sub, indent: 24, isRequiredSection: false))
            }
        }

        items.append(TOCItem(title: "Architecture", indent: 0, isRequiredSection: true))
        for line in document.architecture.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("## ") {
                let sub = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                items.append(TOCItem(title: sub, indent: 12, isRequiredSection: false))
            } else if trimmed.hasPrefix("### ") {
                let sub = trimmed.dropFirst(4).trimmingCharacters(in: .whitespaces)
                items.append(TOCItem(title: sub, indent: 24, isRequiredSection: false))
            }
        }
        
        items.append(TOCItem(title: "Research", indent: 0, isRequiredSection: true))
        for line in document.research.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("## ") {
                let sub = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                items.append(TOCItem(title: sub, indent: 12, isRequiredSection: false))
            } else if trimmed.hasPrefix("### ") {
                let sub = trimmed.dropFirst(4).trimmingCharacters(in: .whitespaces)
                items.append(TOCItem(title: sub, indent: 24, isRequiredSection: false))
            }
        }
        
        items.append(TOCItem(title: "Results & Claims", indent: 0, isRequiredSection: true))
        items.append(TOCItem(title: "Limitations", indent: 0, isRequiredSection: true))
        items.append(TOCItem(title: "Conclusion", indent: 0, isRequiredSection: true))
        items.append(TOCItem(title: "References", indent: 0, isRequiredSection: true))
        
        return items
    }

    private func openDocument() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [UTType(filenameExtension: "rd")].compactMap { $0 }
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.title = "Open URP .rd Package"
        openPanel.begin { response in
            guard response == .OK, let url = openPanel.url else { return }
            if let loaded = URPDocument(rdPackageURL: url) {
                document = loaded
                currentFileURL = url
                withAnimation { saveStatus = "Opened \(url.lastPathComponent)" }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation { saveStatus = "" }
                }
            } else {
                lastError = "Could not open '\(url.lastPathComponent)'. The file is not a valid URP .rd package."
                showError = true
            }
        }
    }

    private func saveDocument() {
        let serializedString = document.serialize()
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)

            // 1. Write the main paper contents
            let paperPath = tempDir.appendingPathComponent("paper.rd.md")
            try serializedString.write(to: paperPath, atomically: true, encoding: .utf8)

            // 2. Write a minimal manifest urp.yaml
            let manifestPath = tempDir.appendingPathComponent("urp.yaml")
            let manifestYaml = """
urp: "0.1"
paper:
  id: "\(document.manifest.paper.id)"
  title: "\(document.manifest.paper.title)"
  subtitle: "\(document.manifest.paper.subtitle)"
  status: "\(document.manifest.paper.status)"
"""
            try manifestYaml.write(to: manifestPath, atomically: true, encoding: .utf8)

            // Create a temporary zip destination path
            let tempZipPath = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")

            // Package into zip
            guard ZipHelper.zip(directoryPath: tempDir.path, to: tempZipPath.path) else {
                lastError = "Error compressing package."
                showError = true
                try? fileManager.removeItem(at: tempDir)
                return
            }

            // If we already have a save URL, overwrite it. Otherwise prompt.
            if let url = currentFileURL {
                do {
                    if fileManager.fileExists(atPath: url.path) {
                        try fileManager.removeItem(at: url)
                    }
                    try fileManager.moveItem(at: tempZipPath, to: url)
                    withAnimation { saveStatus = "Saved \(url.lastPathComponent)" }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation { saveStatus = "" }
                    }
                } catch {
                    lastError = "Error saving: \(error.localizedDescription)"
                    showError = true
                }
            } else {
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [UTType(filenameExtension: "rd")].compactMap { $0 }
                savePanel.nameFieldStringValue = defaultFilename()
                savePanel.title = "Save as URP .rd Package"
                savePanel.canCreateDirectories = true
                savePanel.begin { response in
                    guard response == .OK, let url = savePanel.url else { return }
                    do {
                        if fileManager.fileExists(atPath: url.path) {
                            try fileManager.removeItem(at: url)
                        }
                        try fileManager.copyItem(at: tempZipPath, to: url)
                        self.currentFileURL = url
                        withAnimation { self.saveStatus = "Saved \(url.lastPathComponent)" }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation { self.saveStatus = "" }
                        }
                    } catch {
                        self.lastError = "Error saving: \(error.localizedDescription)"
                        self.showError = true
                    }
                }
            }

            try? fileManager.removeItem(at: tempDir)

        } catch {
            lastError = "Error saving package: \(error.localizedDescription)"
            showError = true
        }
    }

    private func defaultFilename() -> String {
        let cleaned = document.manifest.paper.title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let trimmed = cleaned.replacingOccurrences(of: "[^a-z0-9-]+", with: "", options: .regularExpression)
        return trimmed.isEmpty ? "paper.rd" : "\(trimmed).rd"
    }
}
