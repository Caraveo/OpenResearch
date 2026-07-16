import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct ContentView: View {
    @State private var markdownText: String = ""
    @State private var document: URPDocument = URPDocument(rawContent: "")
    @State private var viewMode: Int = 0
    @State private var editorTab: Int = 0
    @State private var currentFileURL: URL? = nil
    @State private var statusMessage: String = ""
    @State private var showError = false
    @State private var lastError: String = ""
    
    public init() {
        let defaultText = """
<urp version="0.1">
  <paper>
    <id>urp:example:grid-balance</id>
    <title>Distributed Grid Balance Models</title>
    <subtitle>An Open Model for Regional Power Systems</subtitle>
    <type>white-paper</type>
    <language>en-US</language>
    <version>1.0.0</version>
    <created>2026-07-15</created>
    <status>draft</status>
  </paper>
  <authors>
    <author>
      <name>Jon Caraveo</name>
      <affiliation>Independent Researcher</affiliation>
      <orcid>0000-0002-1825-0097</orcid>
    </author>
  </authors>
  <license>
    <text>CC-BY-4.0</text>
    <code>MIT</code>
    <data>CC-BY-4.0</data>
  </license>
</urp>

# Abstract

This paper presents a reproducible method for calculating regional grid power flows and simulating grid balance.

# Problem

Energy grid estimations are frequently presented without identifying formulas, units, assumptions, or implementation details.

# Methodology

Energy is calculated as the product of power and elapsed time.

$$
E = Pt
$$
{#eq-energy}

<variables for="eq-energy">
  <variable symbol="$E$">energy in kilowatt-hours</variable>
  <variable symbol="$P$">power in kilowatts</variable>
  <variable symbol="$t$">time in hours</variable>
</variables>

# Architecture

We model the network flow with the following topology:

```arcmark
nodes:
  gen: "Generation Source"
  grid: "Regional Grid Hub"
  cons: "Industrial Consumers"
  bat: "Battery Storage Bank"
links:
  gen -> grid
  grid -> cons
  grid -> bat
  bat -> grid
```
{#diag-grid-flow title="Grid Energy Flow Topology"}

# Research

The regional grid pilot ran across three western zones for ninety days.

## Findings

- Peak-shaving approached 18% under load.
- Storage returns were strongest at the Alpha substation.

| Zone | Peak (kW) | Savings | Notes |
| --- | --- | --- | --- |
| Alpha | 1820 | 22% | nominal |
| Beta | 1690 | 17% | minor curtail |
| Zeta | 1100 | 9% | partial grid |
| Sigma | 2380 | 24% | export mode |

> Persistence of reduction outlasted discharge windows by margin of 1.4 hours.

![grid-stack](assets/grid-stack.webp)

# Results

For a constant load of 10 kilowatts operating for 5 hours:

$$
E = 10 \\times 5 = 50\\text{ kWh}
$$

<claim id="claim-energy-01" type="empirical" confidence="moderate">
Distributed energy storage can reduce peak transmission demand under the modeled conditions.
</claim>

# Limitations

The calculation assumes constant power throughout the measured period and does not account for line losses.

# Conclusion

The model and architecture expose a clear reproducible method for validating regional grid balance.

# References

No external sources were required.
"""
        self._markdownText = State(initialValue: defaultText)
        self._document = State(initialValue: URPDocument(rawContent: defaultText))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                LogoView(size: 16)
                Text("OpenDeveloper")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundStyle(.primary)
                
                Divider()
                    .frame(height: 16)
                
                Picker("Workspace View", selection: $viewMode) {
                    Text("Write & Preview").tag(0)
                    Text("Validate").tag(1)
                    Text("Build & Export").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
                
                Spacer()

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }

                if let url = currentFileURL {
                    Text(url.lastPathComponent)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.08))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }

                Button(action: newDocument) {
                    Label("New", systemImage: "doc")
                }

                Button(action: openDocument) {
                    Label("Open…", systemImage: "doc.badge.plus")
                }

                Button(action: saveDocument) {
                    Label(currentFileURL == nil ? "Save .rd" : "Save",
                          systemImage: currentFileURL == nil ? "arrow.down.doc.fill" : "checkmark.circle.fill")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Divider().frame(height: 16)

                let issues = URPValidator.validate(document)
                if !issues.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("\(issues.count) alerts")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(6)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("Spec Conforming")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(6)
                }
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            detailWorkspace
        }
        .onChange(of: markdownText) { _, newValue in
            document = URPDocument(rawContent: newValue)
        }
        .onChange(of: document.manifest) { _, newManifest in
            updateXMLHeader(with: newManifest)
        }
        .alert("OpenDeveloper", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lastError)
        }
    }
    
    @ViewBuilder
    private var detailWorkspace: some View {
        let issues = URPValidator.validate(document)
        
        switch viewMode {
        case 1:
            ValidationPanelView(issues: issues)
        case 2:
            ExporterView(document: document, issues: issues)
        default:
            HSplitView {
                VStack(spacing: 0) {
                    Picker("Editor Type", selection: $editorTab) {
                        Text("foco Source").tag(0)
                        Text("Metadata GUI").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .background(Color.secondary.opacity(0.02))

                    Divider()

                    if editorTab == 0 {
                        FocoMarkdownEditor(text: $markdownText)
                    } else {
                        MetadataEditorView(manifest: $document.manifest)
                    }
                }
                .frame(minWidth: 400, idealWidth: 480)
                
                DocumentPreviewView(document: document)
                    .frame(minWidth: 500, idealWidth: 620)
            }
        }
    }
    
    private func updateXMLHeader(with manifest: URPManifest) {
        var markdown = markdownText
        if markdown.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<urp") {
            if let endRange = markdown.range(of: "</urp>") {
                markdown = String(markdown[endRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        var xml = "<urp version=\"\(manifest.urp)\">\n"
        xml += "  <paper>\n"
        xml += "    <id>\(manifest.paper.id)</id>\n"
        xml += "    <title>\(manifest.paper.title)</title>\n"
        if !manifest.paper.subtitle.isEmpty {
            xml += "    <subtitle>\(manifest.paper.subtitle)</subtitle>\n"
        }
        xml += "    <type>\(manifest.paper.type)</type>\n"
        xml += "    <language>\(manifest.paper.language)</language>\n"
        xml += "    <version>\(manifest.paper.version)</version>\n"
        if !manifest.paper.created.isEmpty {
            xml += "    <created>\(manifest.paper.created)</created>\n"
        }
        xml += "    <status>\(manifest.paper.status)</status>\n"
        xml += "  </paper>\n"
        
        if !manifest.authors.isEmpty {
            xml += "  <authors>\n"
            for author in manifest.authors {
                xml += "    <author>\n"
                xml += "      <name>\(author.name)</name>\n"
                if !author.affiliation.isEmpty {
                    xml += "      <affiliation>\(author.affiliation)</affiliation>\n"
                }
                if let orcid = author.orcid, !orcid.isEmpty {
                    xml += "      <orcid>\(author.orcid ?? "")</orcid>\n"
                }
                xml += "    </author>\n"
            }
            xml += "  </authors>\n"
        }
        
        xml += "  <license>\n"
        xml += "    <text>\(manifest.license.text)</text>\n"
        xml += "    <code>\(manifest.license.code)</code>\n"
        xml += "    <data>\(manifest.license.data)</data>\n"
        xml += "  </license>\n"
        xml += "</urp>\n\n"
        
        markdownText = xml + markdown
    }

    // MARK: - File: New / Open / Save (.rd) -----------------------------------

    private func newDocument() {
        markdownText = ""
        document = URPDocument(rawContent: "")
        currentFileURL = nil
        statusMessage = "New document"
        viewMode = 0
        editorTab = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation { statusMessage = "" }
        }
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
                markdownText = loaded.rawContent.isEmpty ? loaded.serialize() : loaded.rawContent
                currentFileURL = url
                statusMessage = "Opened \(url.lastPathComponent)"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation { statusMessage = "" }
                }
            } else {
                lastError = "Could not open '\(url.lastPathComponent)'. The file is not a valid URP .rd package."
                showError = true
            }
        }
    }

    private func saveDocument() {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("urp-save-\(UUID().uuidString)")
        let serialized = document.serialize()

        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            try serialized.write(to: tempDir.appendingPathComponent("paper.rd.md"), atomically: true, encoding: .utf8)
            let yaml = """
            urp: "\(document.manifest.urp)"
            paper:
              id: "\(document.manifest.paper.id)"
              title: "\(document.manifest.paper.title)"
              status: "\(document.manifest.paper.status)"
            """
            try yaml.write(to: tempDir.appendingPathComponent("urp.yaml"), atomically: true, encoding: .utf8)

            let tempZip = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".rd")
            guard ZipHelper.zip(directoryPath: tempDir.path, to: tempZip.path) else {
                lastError = "Failed to compress .rd package."
                showError = true
                try? fm.removeItem(at: tempDir)
                return
            }

            if let url = currentFileURL {
                if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
                try fm.moveItem(at: tempZip, to: url)
                statusMessage = "Saved \(url.lastPathComponent)"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation { statusMessage = "" }
                }
            } else {
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [UTType(filenameExtension: "rd")].compactMap { $0 }
                savePanel.nameFieldStringValue = defaultFilename()
                savePanel.title = "Save as URP .rd Package"
                savePanel.canCreateDirectories = true
                savePanel.begin { resp in
                    guard resp == .OK, let url = savePanel.url else { return }
                    do {
                        if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
                        try fm.copyItem(at: tempZip, to: url)
                        self.currentFileURL = url
                        self.statusMessage = "Saved \(url.lastPathComponent)"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation { self.statusMessage = "" }
                        }
                    } catch {
                        self.lastError = "Error saving: \(error.localizedDescription)"
                        self.showError = true
                    }
                }
            }
            try? fm.removeItem(at: tempDir)
        } catch {
            lastError = "Error saving: \(error.localizedDescription)"
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
