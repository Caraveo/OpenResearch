import Foundation

public struct URPClaim: Identifiable, Equatable {
    public var id: String
    public var type: String
    public var confidence: String
    public var sources: String
    public var body: String
}

public struct URPVariable: Identifiable, Equatable {
    public var id: String { symbol }
    public var symbol: String
    public var definition: String
}

public struct URPVariablesBlock: Identifiable, Equatable {
    public var id: String { forEquation }
    public var forEquation: String
    public var variables: [URPVariable]
}

public struct URPEquation: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var math: String
}

public struct URPCodeBlock: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var language: String
    public var executable: Bool
    public var environment: String
    public var code: String
}

public struct URPSection: Identifiable, Equatable {
    public var id: String { title }
    public var title: String
    public var level: Int
    public var body: String
}

public struct URPDocument: Equatable {
    public var manifest: URPManifest = URPManifest()
    
    // Core non-removable sections
    public var abstract: String = ""
    public var problem: String = ""
    public var methodology: String = ""
    public var architecture: String = ""
    public var research: String = ""
    public var limitations: String = ""
    public var conclusion: String = ""
    public var references: String = ""
    
    // Inline structured blocks
    public var claim: URPClaim = URPClaim(id: "claim-pipeline-01", type: "empirical", confidence: "high", sources: "urp-pilot-2026", body: "Separating metadata engineering (OpenDeveloper) from author composition (OpenWriter) reduces syntax/validation errors by 94% on initial save.")
    public var equation: URPEquation = URPEquation(id: "eq-repro", title: "Reproducibility Index", math: "E_{repro} = \\frac{D \\cdot W}{P}")
    public var variables: [URPVariable] = [
        URPVariable(symbol: "E_{repro}", definition: "reproducibility efficiency index"),
        URPVariable(symbol: "D", definition: "developer schema validation conformance score"),
        URPVariable(symbol: "W", definition: "writer distraction-free focus efficiency"),
        URPVariable(symbol: "P", definition: "publisher rendering print fidelity")
    ]
    public var diagramCode: String = """
nodes:
  dev: "OpenDeveloper (Schema & XML Validation)"
  writer: "OpenWriter (Foco-Style Editor Sheet)"
  paper: "OpenPaper (Read-Only Previewer)"
  pdf: "Academic Vector PDF (Print Engine)"
links:
  dev -> writer
  writer -> paper
  paper -> pdf
"""

    public init() {
        self.resetToDefaultTemplate()
    }
    
    public mutating func resetToDefaultTemplate() {
        self.manifest.paper.id = "urp:openresearch:paradigm:2026"
        self.manifest.paper.title = "The OpenResearch Paradigm"
        self.manifest.paper.subtitle = "A Human-Centered Pipeline for Reproducible Scientific Publishing"
        self.manifest.paper.status = "published"
        
        self.manifest.authors = [
            URPManifest.AuthorInfo(authorId: "author-caraveo", name: "Jon Caraveo", affiliation: "OpenResearch Initiative", roles: ["conceptualization", "writing"])
        ]
        
        self.abstract = "This paper presents the OpenResearch publishing pipeline, a tripartite native desktop ecosystem designed to make scientific writing, review, and publication reproducible and accessible. By splitting tasks across three specific native contexts (OpenDeveloper, OpenWriter, and OpenPaper), the pipeline separates raw technical structure validation from focused academic composition, culminating in standardized vector PDF print layouts."
        self.problem = "Academic journals remain trapped in static formats. PDFs hold raw pixel instructions but lack semantic models, rendering them inaccessible to screen readers and search indexes. Conversely, LaTeX source code remains hard to parse and lacks standardized runtime dependencies. Standard research models need structured document wrappers that preserve equations, database schemas, and diagrams, while keeping editing simple."
        self.methodology = """
We define the reproducibility index \\(E_{repro}\\) as a ratio of structural composition quality and publisher layout stability:

$$
E_{repro} = \\frac{D \\cdot W}{P}
$$
{#eq-repro title="Reproducibility Index"}

<variables for="eq-repro">
  <variable symbol="E_{repro}">reproducibility efficiency index</variable>
  <variable symbol="D">developer schema validation conformance score</variable>
  <variable symbol="W">writer distraction-free focus efficiency</variable>
  <variable symbol="P">publisher rendering print fidelity</variable>
</variables>
"""
        self.architecture = """
The tripartite native desktop ecosystem distributes publishing lifecycle actions across distinct system nodes:

```arcmark
nodes:
  dev: "OpenDeveloper (Schema & XML Validation)"
  writer: "OpenWriter (Foco-Style Editor Sheet)"
  paper: "OpenPaper (Read-Only Previewer)"
  pdf: "Academic Vector PDF (Print Engine)"
links:
  dev -> writer
  writer -> paper
  paper -> pdf
```
{#diag-pipeline title="Grid Topology"}
"""
        self.research = """
The OpenResearch ecosystem distributes publishing across three specialized native desktop tools:

1. **OpenDeveloper**: Employs split-screen editors where engineers design schema rules, align XML nodes, and validate dependency runs.
2. **OpenWriter**: Provides authors with a distraction-free, single-column focused editing canvas. Complex markup code is hidden under inline visual cards.
3. **OpenPaper**: Offers readers a locked, high-quality typography viewer that unzips URP `.rd` packages and exports conforming LaTeX, HTML, or PDFs.
"""
        self.limitations = "While the initial specifications support key components, real-time sync and nested multi-variable schemas remain in experimental drafts."
        self.conclusion = "By establishing standardized publishing pipelines, URP bridges the gap between raw research code and beautiful output typography."
        self.references = "OpenResearch Standard Specifications, v0.1 (2026)."
    }
    
    // Serializer to save into standard .rd format
    public func serialize() -> String {
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
        
        xml += "  <reproducibility>\n"
        xml += "    <level>\(manifest.reproducibility.level)</level>\n"
        xml += "  </reproducibility>\n"
        xml += "</urp>\n\n"
        
        // Add minimal sections
        xml += "# Abstract\n\n\(abstract)\n\n"
        xml += "# Problem\n\n\(problem)\n\n"
        
        xml += "# Methodology\n\n\(methodology)\n\n"
        xml += "# Architecture\n\n\(architecture)\n\n"
        xml += "# Research\n\n\(research)\n\n"
        
        xml += "# Results\n\n"
        xml += "<claim id=\"\(claim.id)\" type=\"\(claim.type)\" confidence=\"\(claim.confidence)\" sources=\"\(claim.sources)\">\n"
        xml += "\(claim.body)\n"
        xml += "</claim>\n\n"
        
        xml += "# Limitations\n\n\(limitations)\n\n"
        xml += "# Conclusion\n\n\(conclusion)\n\n"
        xml += "# References\n\n\(references)\n"

        return xml
    }

    /// Load a `.rd` package (zip) and deserialize its `paper.rd.md` back into the
    /// writer's editable section fields. Returns nil if the package is malformed.
    public init?(rdPackageURL: URL) {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("urp-open-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tempDir) }

        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return nil
        }

        guard UnzipHelper.unzip(zipPath: rdPackageURL.path, to: tempDir.path) else { return nil }
        let paperMdURL = tempDir.appendingPathComponent("paper.rd.md")
        guard fm.fileExists(atPath: paperMdURL.path),
              let raw = try? String(contentsOf: paperMdURL, encoding: .utf8) else {
            return nil
        }

        self.init()
        self.applyRawContent(raw)
    }

    /// Parse a `paper.rd.md` raw string into the writer's editable fields.
    /// Mirrors the format produced by `serialize()`.
    public mutating func applyRawContent(_ raw: String) {
        var content = raw

        // 1. XML header → manifest fields.
        if content.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<urp") {
            if let endRange = content.range(of: "</urp>") {
                let xmlHeader = String(content[..<endRange.upperBound])
                applyXMLHeader(xmlHeader)
                content = String(content[endRange.upperBound...])
            }
        }

// 2. Pull the equation block: $$\n<math>\n$$\n{#<id> title="<title>"}
        if let eqRegex = try? NSRegularExpression(pattern: #"\$\$\n([\s\S]*?)\n\$\$\n\{#([^\s}]+)\s*title="([^"]*)"\}"#, options: []) {
            let ns = content as NSString
            if let m = eqRegex.firstMatch(in: content, range: NSRange(location: 0, length: ns.length)) {
                let math = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                let id = ns.substring(with: m.range(at: 2))
                let title = ns.substring(with: m.range(at: 3))
                equation.id = id
                equation.title = title
                equation.math = math
                let blockRange = m.range
                let safeRange = blockRange.location + blockRange.length <= ns.length ? blockRange : NSRange(location: blockRange.location, length: ns.length - blockRange.location)
                content = (content as NSString).replacingCharacters(in: safeRange, with: "")
            }
        }

        // 3. Variables block: <variables for="eq-id">...</variables>
        if let varRange = content.range(of: #"<variables\s+for="([^"]*)">([\s\S]*?)</variables>"#, options: .regularExpression) {
            let block = String(content[varRange])
            if let forRange = block.range(of: #"for="([^"]*)""#, options: .regularExpression) {
                let forId = String(block[forRange].dropFirst(5).dropLast())
                if forId == equation.id {
                    var parsed: [URPVariable] = []
                    if let varRegex = try? NSRegularExpression(pattern: #"<variable\s+symbol="([^"]*)">([\s\S]*?)</variable>"#) {
                        let ns = block as NSString
                        for m in varRegex.matches(in: block, range: NSRange(location: 0, length: ns.length)) {
                            let sym = ns.substring(with: m.range(at: 1))
                            let def = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                            parsed.append(URPVariable(symbol: sym, definition: def))
                        }
                    }
                    if !parsed.isEmpty { variables = parsed }
                }
            }
            content.removeSubrange(varRange)
        }

        // 4. Arcmark diagram code block: ```arcmark\n<code>\n```\n{#diag-pipeline}
        if let diagRange = content.range(of: #"```arcmark\n([\s\S]*?)\n```\n\{#diag-pipeline\}"#, options: .regularExpression) {
            let block = String(content[diagRange])
            if let codeRange = block.range(of: "```arcmark\n"),
               let fenceEnd = block.range(of: "\n```\n{#diag-pipeline}", range: codeRange.upperBound..<block.endIndex) {
                diagramCode = String(block[codeRange.upperBound..<fenceEnd.lowerBound])
            }
            content.removeSubrange(diagRange)
        }

        // 5. Claim block: <claim id="..." type="..." confidence="..." sources="...">...</claim>
        if let claimRange = content.range(of: #"<claim\s+([^>]*?)>([\s\S]*?)</claim>"#, options: .regularExpression) {
            let block = String(content[claimRange])
            let attrString = String(block[block.range(of: "<claim")!.upperBound..<(block.range(of: ">")?.lowerBound ?? block.endIndex)])
            let body = String(block[(block.range(of: ">")?.upperBound ?? block.endIndex)..<(block.range(of: "</claim>")?.lowerBound ?? block.endIndex)])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            claim.id = attrValue(attrString, "id") ?? claim.id
            claim.type = attrValue(attrString, "type") ?? claim.type
            claim.confidence = attrValue(attrString, "confidence") ?? claim.confidence
            claim.sources = attrValue(attrString, "sources") ?? claim.sources
            claim.body = body
            content.removeSubrange(claimRange)
        }

        // 6. Section headers → editable fields.
        abstract = extractSection(&content, "Abstract") ?? abstract
        problem = extractSection(&content, "Problem") ?? problem
        
        let methAndArch = extractSection(&content, "Methodology & Architecture")
        if let both = methAndArch {
            methodology = both
            architecture = ""
        } else {
            methodology = extractSection(&content, "Methodology") ?? methodology
            architecture = extractSection(&content, "Architecture") ?? architecture
        }
        
        research = extractSection(&content, "Research") ?? research
        limitations = extractSection(&content, "Limitations") ?? limitations
        conclusion = extractSection(&content, "Conclusion") ?? conclusion
        references = extractSection(&content, "References") ?? references
    }

    private mutating func applyXMLHeader(_ xml: String) {
        if let v = extractTag(xml, tag: "urp") {
            manifest.urp = v
        } else if let r = xml.range(of: "version=\"([^\"]+)\"", options: .regularExpression) {
            let sub = xml[r]
            if let q = sub.range(of: "\"") {
                manifest.urp = String(sub[q.upperBound...].dropLast())
            }
        }
        manifest.paper.id = extractTag(xml, tag: "id") ?? manifest.paper.id
        manifest.paper.title = extractTag(xml, tag: "title") ?? manifest.paper.title
        manifest.paper.subtitle = extractTag(xml, tag: "subtitle") ?? manifest.paper.subtitle
        manifest.paper.type = extractTag(xml, tag: "type") ?? manifest.paper.type
        manifest.paper.language = extractTag(xml, tag: "language") ?? manifest.paper.language
        manifest.paper.version = extractTag(xml, tag: "version") ?? manifest.paper.version
        manifest.paper.created = extractTag(xml, tag: "created") ?? manifest.paper.created
        manifest.paper.status = extractTag(xml, tag: "status") ?? manifest.paper.status

        if let authorsXml = extractTag(xml, tag: "authors") {
            var parsed: [URPManifest.AuthorInfo] = []
            if let regex = try? NSRegularExpression(pattern: "<author>([\\s\\S]*?)</author>", options: [.dotMatchesLineSeparators]) {
                let ns = authorsXml as NSString
                for m in regex.matches(in: authorsXml, range: NSRange(location: 0, length: ns.length)) {
                    let a = ns.substring(with: m.range(at: 1))
                    let name = extractTag(a, tag: "name") ?? ""
                    let aff = extractTag(a, tag: "affiliation") ?? ""
                    let orcid = extractTag(a, tag: "orcid")
                    parsed.append(URPManifest.AuthorInfo(authorId: nil, name: name, affiliation: aff, roles: [], orcid: orcid))
                }
            }
            if !parsed.isEmpty { manifest.authors = parsed }
        }

        if let lic = extractTag(xml, tag: "license") {
            manifest.license.text = extractTag(lic, tag: "text") ?? manifest.license.text
            manifest.license.code = extractTag(lic, tag: "code") ?? manifest.license.code
            manifest.license.data = extractTag(lic, tag: "data") ?? manifest.license.data
        }

        if let repro = extractTag(xml, tag: "reproducibility") {
            manifest.reproducibility.level = extractTag(repro, tag: "level") ?? manifest.reproducibility.level
        }
    }

    private func extractTag(_ text: String, tag: String) -> String? {
        let pattern = "<\(tag)>([\\s\\S]*?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func attrValue(_ s: String, _ name: String) -> String? {
        guard let r = s.range(of: "\(name)=\"([^\"]*)\"", options: .regularExpression) else { return nil }
        return String(s[r].dropFirst(name.count + 2).dropLast())
    }

    /// Pull the body of `# Title\n\n<content>\n\n# ...` from `content`; mutates content to remove it.
    private func extractSection(_ content: inout String, _ title: String) -> String? {
        guard let headerRange = content.range(of: "# \(title)\n") else { return nil }
        let bodyStart = headerRange.upperBound
        let searchStart = bodyStart
        let bodyEnd = content.range(of: "\n# ", range: searchStart..<content.endIndex)?.lowerBound ?? content.endIndex
        let body = String(content[bodyStart..<bodyEnd])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        content.removeSubrange(headerRange.lowerBound..<bodyEnd)
        return body
    }
}
