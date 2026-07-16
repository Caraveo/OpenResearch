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
    public var rawContent: String = ""
    public var manifest: URPManifest = URPManifest()
    public var sections: [URPSection] = []
    public var claims: [URPClaim] = []
    public var equations: [URPEquation] = []
    public var variablesBlocks: [URPVariablesBlock] = []
    public var codeBlocks: [URPCodeBlock] = []
    
    public init(rawContent: String) {
        self.rawContent = rawContent
        self.parse()
    }
    
    public mutating func parse() {
        var markdown = rawContent

        // 1. Parse XML Metadata Header
        if markdown.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<urp") {
            if let endRange = markdown.range(of: "</urp>") {
                let xmlHeader = String(markdown[..<endRange.upperBound])
                self.manifest = parseXMLMetadata(xmlHeader)
                markdown = String(markdown[endRange.upperBound...])
            }
        }

        // 2. Extract Code Blocks first (so $$ inside code isn't misread).
        //    Each surviving block leaves a single placeholder line so the
        //    downstream viewers know where to render the structured card.
        (self.codeBlocks, markdown) = extractAndMaskCodeBlocks(markdown)

        // 3. Extract Equations ($$...$$ {#eq-id ...}) → placeholder.
        (self.equations, markdown) = extractAndMaskEquations(markdown)

        // 4. Extract Variables Blocks (<variables for="eq-id">...</variables>).
        //    These render attached to their equation, so fully strip them.
        (self.variablesBlocks, markdown) = extractAndStripVariables(markdown)

        // 5. Extract Claims (<claim ...>...</claim>) → placeholder.
        (self.claims, markdown) = extractAndMaskClaims(markdown)

        // 6. Extract Sections (operating on the cleaned body).
        self.sections = parseSections(markdown)
    }

    // Returns the matcher id and metadata string for a `$$ ... $$ {#... title="..."}` segment.
    private static let eqPattern: String = "\\$\\$([\\s\\S]*?)\\$\\$\\s*\\{#([^\\s}]+)([^}]*)\\}"
    private static let claimPattern: String = "<claim\\s+([^>]*?)>([\\s\\S]*?)</claim>"
    private static let variablesPattern: String = "<variables\\s+for=\"([^\"]*?)\">([\\s\\S]*?)</variables>"
    private static let codePattern: String = "```(\\w+)[\\s\\S]*?\\n([\\s\\S]*?)\\n```\\s*\\{#([^\\s}]+)([^}]*)\\}"

    private func extractAndMaskEquations(_ text: String) -> ([URPEquation], String) {
        var list: [URPEquation] = []
        guard let regex = try? NSRegularExpression(pattern: Self.eqPattern, options: [.dotMatchesLineSeparators]) else {
            return ([], text)
        }
        let ns = text as NSString
        let mutable = NSMutableString(string: text)
        var delta = 0
        for m in regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) {
            let math = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            let id = ns.substring(with: m.range(at: 2))
            let meta = ns.substring(with: m.range(at: 3))
            let titleValue = parseAttribute(meta, name: "title") ?? "Equation"
            list.append(URPEquation(id: id, title: titleValue, math: math))

            // Replace with placeholder that the view detects. Keep id accessible.
            let placeholder = "\n[URP-EQ:\(id)]\n"
            mutable.replaceCharacters(in: NSRange(location: m.range.location + delta, length: m.range.length), with: placeholder)
            delta += (placeholder as NSString).length - m.range.length
        }
        return (list, mutable as String)
    }

    private func extractAndMaskClaims(_ text: String) -> ([URPClaim], String) {
        var list: [URPClaim] = []
        guard let regex = try? NSRegularExpression(pattern: Self.claimPattern, options: [.dotMatchesLineSeparators]) else {
            return ([], text)
        }
        let ns = text as NSString
        let mutable = NSMutableString(string: text)
        var delta = 0
        for m in regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) {
            let metaString = ns.substring(with: m.range(at: 1))
            let body = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            let id = parseAttribute(metaString, name: "id") ?? "unknown"
            let type = parseAttribute(metaString, name: "type") ?? "empirical"
            let confidence = parseAttribute(metaString, name: "confidence") ?? "moderate"
            let sources = parseAttribute(metaString, name: "sources") ?? ""
            list.append(URPClaim(id: id, type: type, confidence: confidence, sources: sources, body: body))

            let placeholder = "\n[URP-CLAIM:\(id)]\n"
            mutable.replaceCharacters(in: NSRange(location: m.range.location + delta, length: m.range.length), with: placeholder)
            delta += (placeholder as NSString).length - m.range.length
        }
        return (list, mutable as String)
    }

    private func extractAndStripVariables(_ text: String) -> ([URPVariablesBlock], String) {
        var list: [URPVariablesBlock] = []
        guard let regex = try? NSRegularExpression(pattern: Self.variablesPattern, options: [.dotMatchesLineSeparators]) else {
            return ([], text)
        }
        let ns = text as NSString
        let mutable = NSMutableString(string: text)
        var delta = 0
        for m in regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) {
            let equationId = ns.substring(with: m.range(at: 1))
            let body = ns.substring(with: m.range(at: 2))

            var variables: [URPVariable] = []
            if let varRegex = try? NSRegularExpression(pattern: "<variable\\s+symbol=\"(.*?)\">(.*?)</variable>", options: [.dotMatchesLineSeparators]) {
                let bodyNs = body as NSString
                for vm in varRegex.matches(in: body, options: [], range: NSRange(location: 0, length: bodyNs.length)) {
                    let symbol = bodyNs.substring(with: vm.range(at: 1))
                    let def = bodyNs.substring(with: vm.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    variables.append(URPVariable(symbol: symbol, definition: def))
                }
            }
            list.append(URPVariablesBlock(forEquation: equationId, variables: variables))

            // Fully strip — variables render inside their equation card.
            mutable.replaceCharacters(in: NSRange(location: m.range.location + delta, length: m.range.length), with: "\n")
            delta += 1 - m.range.length
        }
        return (list, mutable as String)
    }

    private func extractAndMaskCodeBlocks(_ text: String) -> ([URPCodeBlock], String) {
        var list: [URPCodeBlock] = []
        guard let regex = try? NSRegularExpression(pattern: Self.codePattern, options: [.dotMatchesLineSeparators]) else {
            return ([], text)
        }
        let ns = text as NSString
        let mutable = NSMutableString(string: text)
        var delta = 0
        for m in regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) {
            let language = ns.substring(with: m.range(at: 1))
            let code = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            let id = ns.substring(with: m.range(at: 3))
            let meta = ns.substring(with: m.range(at: 4))
            let title = parseAttribute(meta, name: "title") ?? "Code Block"
            let executable = parseAttribute(meta, name: "executable").map { $0 == "true" } ?? false
            let env = parseAttribute(meta, name: "environment") ?? ""
            list.append(URPCodeBlock(id: id, title: title, language: language.isEmpty ? "text" : language, executable: executable, environment: env, code: code))

            let placeholder = "\n[URP-CODE:\(id)]\n"
            mutable.replaceCharacters(in: NSRange(location: m.range.location + delta, length: m.range.length), with: placeholder)
            delta += (placeholder as NSString).length - m.range.length
        }
        return (list, mutable as String)
    }
    
    private func parseXMLMetadata(_ xml: String) -> URPManifest {
        var manifest = URPManifest()
        
        if let versionMatch = xml.range(of: "<urp version=\"([^\"]+)\"", options: .regularExpression) {
            let sub = xml[versionMatch]
            if let startQuote = sub.range(of: "\"") {
                let val = sub[startQuote.upperBound...].dropLast()
                manifest.urp = String(val)
            }
        }
        
        manifest.paper.id = extractTag(xml, tag: "id") ?? ""
        manifest.paper.title = extractTag(xml, tag: "title") ?? ""
        manifest.paper.subtitle = extractTag(xml, tag: "subtitle") ?? ""
        manifest.paper.type = extractTag(xml, tag: "type") ?? "white-paper"
        manifest.paper.language = extractTag(xml, tag: "language") ?? "en-US"
        manifest.paper.version = extractTag(xml, tag: "version") ?? "1.0.0"
        manifest.paper.created = extractTag(xml, tag: "created") ?? ""
        manifest.paper.updated = extractTag(xml, tag: "updated") ?? ""
        manifest.paper.status = extractTag(xml, tag: "status") ?? "draft"
        
        if let licenseXml = extractTag(xml, tag: "license") {
            manifest.license.text = extractTag(licenseXml, tag: "text") ?? "CC-BY-4.0"
            manifest.license.code = extractTag(licenseXml, tag: "code") ?? "MIT"
            manifest.license.data = extractTag(licenseXml, tag: "data") ?? "CC-BY-4.0"
        }
        
        if let reproXml = extractTag(xml, tag: "reproducibility") {
            manifest.reproducibility.level = extractTag(reproXml, tag: "level") ?? "0"
            manifest.reproducibility.environment = extractTag(reproXml, tag: "environment") ?? ""
            manifest.reproducibility.entrypoint = extractTag(reproXml, tag: "entrypoint") ?? ""
            manifest.reproducibility.expectedRuntime = extractTag(reproXml, tag: "expected_runtime") ?? ""
        }
        
        manifest.authors = []
        let authorMatches = matches(for: "<author>(.*?)</author>", in: xml)
        for authorXml in authorMatches {
            let name = extractTag(authorXml, tag: "name") ?? ""
            let aff = extractTag(authorXml, tag: "affiliation") ?? ""
            let orcid = extractTag(authorXml, tag: "orcid")
            
            let idName = name.lowercased().replacingOccurrences(of: " ", with: "-")
            manifest.authors.append(URPManifest.AuthorInfo(
                authorId: "author:\(idName)",
                name: name,
                affiliation: aff,
                roles: [],
                orcid: orcid
            ))
        }
        
        return manifest
    }
    
    private func extractTag(_ text: String, tag: String) -> String? {
        let pattern = "<\(tag)>(.*?)</\(tag)>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let nsString = text as NSString
        if let match = regex?.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) {
            return nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    private func matches(for pattern: String, in text: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let nsString = text as NSString
        let results = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        return results.map { nsString.substring(with: $0.numberOfRanges > 1 ? $0.range(at: 1) : $0.range) }
    }
    
    private func parseClaims(_ text: String) -> [URPClaim] {
        var list: [URPClaim] = []
        let pattern = "<claim\\s*(.*?)>(.*?)</claim>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let nsString = text as NSString
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for match in matches {
            let metaString = nsString.substring(with: match.range(at: 1))
            let body = nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let id = parseAttribute(metaString, name: "id") ?? "unknown"
            let type = parseAttribute(metaString, name: "type") ?? "empirical"
            let confidence = parseAttribute(metaString, name: "confidence") ?? "moderate"
            let sources = parseAttribute(metaString, name: "sources") ?? ""
            
            list.append(URPClaim(id: id, type: type, confidence: confidence, sources: sources, body: body))
        }
        return list
    }
    
    private func parseEquations(_ text: String) -> [URPEquation] {
        var list: [URPEquation] = []
        let pattern = "\\$\\$(.*?)\\$\\$\\s*\\{\\#(.*?)\\}"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let nsString = text as NSString
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for match in matches {
            let math = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            let meta = nsString.substring(with: match.range(at: 2))
            
            let parts = meta.components(separatedBy: .whitespaces)
            let id = parts.first ?? "unknown"
            let title = parseAttribute(meta, name: "title") ?? "Equation"
            
            list.append(URPEquation(id: id, title: title, math: math))
        }
        return list
    }
    
    private func parseVariables(_ text: String) -> [URPVariablesBlock] {
        var list: [URPVariablesBlock] = []
        let pattern = "<variables\\s+for=\"(.*?)\">(.*?)</variables>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let nsString = text as NSString
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for match in matches {
            let equationId = nsString.substring(with: match.range(at: 1))
            let body = nsString.substring(with: match.range(at: 2))
            
            var variables: [URPVariable] = []
            let varPattern = "<variable\\s+symbol=\"(.*?)\">(.*?)</variable>"
            let varRegex = try? NSRegularExpression(pattern: varPattern, options: [])
            let varNsString = body as NSString
            let varMatches = varRegex?.matches(in: body, options: [], range: NSRange(location: 0, length: varNsString.length)) ?? []
            
            for varMatch in varMatches {
                let symbol = varNsString.substring(with: varMatch.range(at: 1))
                let def = varNsString.substring(with: varMatch.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                variables.append(URPVariable(symbol: symbol, definition: def))
            }
            
            list.append(URPVariablesBlock(forEquation: equationId, variables: variables))
        }
        return list
    }
    
    private func parseCodeBlocks(_ text: String) -> [URPCodeBlock] {
        var list: [URPCodeBlock] = []
        let pattern = "```(\\w+)\\n(.*?)\\n```\\s*\\{\\#(.*?)\\}"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let nsString = text as NSString
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for match in matches {
            let language = nsString.substring(with: match.range(at: 1))
            let code = nsString.substring(with: match.range(at: 2))
            let meta = nsString.substring(with: match.range(at: 3))
            
            let parts = meta.components(separatedBy: .whitespaces)
            let id = parts.first ?? "unknown"
            let title = parseAttribute(meta, name: "title") ?? "Code Block"
            let executable = parseAttribute(meta, name: "executable") == "true"
            let env = parseAttribute(meta, name: "environment") ?? ""
            
            list.append(URPCodeBlock(id: id, title: title, language: language, executable: executable, environment: env, code: code))
        }
        return list
    }
    
    private func parseSections(_ text: String) -> [URPSection] {
        var list: [URPSection] = []
        let lines = text.components(separatedBy: .newlines)
        
        var currentSectionTitle = ""
        var currentSectionLevel = 1
        var currentBody: [String] = []
        
        for line in lines {
            if line.hasPrefix("#") {
                let hashCount = line.prefix(while: { $0 == "#" }).count
                if hashCount <= 3 {
                    if !currentSectionTitle.isEmpty || !currentBody.isEmpty {
                        list.append(URPSection(title: currentSectionTitle.isEmpty ? "Intro" : currentSectionTitle, level: currentSectionLevel, body: currentBody.joined(separator: "\n")))
                    }
                    currentSectionTitle = line.dropFirst(hashCount).trimmingCharacters(in: .whitespaces)
                    currentSectionLevel = hashCount
                    currentBody = []
                    continue
                }
            }
            currentBody.append(line)
        }
        
        if !currentSectionTitle.isEmpty || !currentBody.isEmpty {
            list.append(URPSection(title: currentSectionTitle, level: currentSectionLevel, body: currentBody.joined(separator: "\n")))
        }
        
        return list
    }
    
    private func parseAttribute(_ text: String, name: String) -> String? {
        let pattern = "\(name)=\"(.*?)\""
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = text as NSString
        if let match = regex?.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) {
            return nsString.substring(with: match.range(at: 1))
        }
        let pattern2 = "\(name)=([^\\s,}>]+)"
        let regex2 = try? NSRegularExpression(pattern: pattern2, options: [])
        if let match = regex2?.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) {
            return nsString.substring(with: match.range(at: 1))
        }
        return nil
    }

    /// Round-trip serializer back to `paper.rd.md` source.
    public func serialize() -> String {
        var out = "<urp version=\"\(manifest.urp)\">\n"
        out += "  <paper>\n"
        out += "    <id>\(manifest.paper.id)</id>\n"
        out += "    <title>\(manifest.paper.title)</title>\n"
        if !manifest.paper.subtitle.isEmpty { out += "    <subtitle>\(manifest.paper.subtitle)</subtitle>\n" }
        out += "    <type>\(manifest.paper.type)</type>\n"
        out += "    <language>\(manifest.paper.language)</language>\n"
        out += "    <version>\(manifest.paper.version)</version>\n"
        if !manifest.paper.created.isEmpty { out += "    <created>\(manifest.paper.created)</created>\n" }
        out += "    <status>\(manifest.paper.status)</status>\n"
        out += "  </paper>\n"
        if !manifest.authors.isEmpty {
            out += "  <authors>\n"
            for a in manifest.authors {
                out += "    <author>\n"
                out += "      <name>\(a.name)</name>\n"
                if !a.affiliation.isEmpty { out += "      <affiliation>\(a.affiliation)</affiliation>\n" }
                if let orcid = a.orcid, !orcid.isEmpty { out += "      <orcid>\(orcid)</orcid>\n" }
                out += "    </author>\n"
            }
            out += "  </authors>\n"
        }
        out += "  <license>\n"
        out += "    <text>\(manifest.license.text)</text>\n"
        out += "    <code>\(manifest.license.code)</code>\n"
        out += "    <data>\(manifest.license.data)</data>\n"
        out += "  </license>\n"
        out += "  <reproducibility>\n"
        out += "    <level>\(manifest.reproducibility.level)</level>\n"
        out += "  </reproducibility>\n"
        out += "</urp>\n\n"

        for section in sections {
            let hashes = String(repeating: "#", count: max(section.level, 1))
            out += "\(hashes) \(section.title.isEmpty ? "Introduction" : section.title)\n\n"
            // Strip the internal `[URP-EQ:…]` / `[URP-CLAIM:…]` / `[URP-CODE:…]`
            // placeholders before writing out — re-emit the original structured
            // blocks so the file round-trips cleanly on reload.
            let cleaned = stripPlaceholders(section.body)
            out += "\(cleaned.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"

            // Re-attach structured blocks that belong to this section.
            for eq in equations where section.body.contains("[URP-EQ:\(eq.id)]") {
                out += "$$\n\(eq.math)\n$$\n{#\(eq.id) title=\"\(eq.title)\"}\n\n"
                if let vb = variablesBlocks.first(where: { $0.forEquation == eq.id }), !vb.variables.isEmpty {
                    out += "<variables for=\"\(eq.id)\">\n"
                    for v in vb.variables { out += "  <variable symbol=\"\(v.symbol)\">\(v.definition)</variable>\n" }
                    out += "</variables>\n\n"
                }
            }
            for c in codeBlocks where section.body.contains("[URP-CODE:\(c.id)]") {
                out += "```\(c.language)\n\(c.code)\n```\n{#\(c.id) title=\"\(c.title)\"}\n\n"
            }
            for c in claims where section.body.contains("[URP-CLAIM:\(c.id)]") {
                out += "<claim id=\"\(c.id)\" type=\"\(c.type)\" confidence=\"\(c.confidence)\" sources=\"\(c.sources)\">\n\(c.body)\n</claim>\n\n"
            }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private func stripPlaceholders(_ s: String) -> String {
        var out = s
        for kind in ["URP-EQ", "URP-CLAIM", "URP-CODE"] {
            if let regex = try? NSRegularExpression(pattern: "\\[\(kind):[^\\]]+\\]") {
                let mutable = NSMutableString(string: out)
                let ns = out as NSString
                for m in regex.matches(in: out, range: NSRange(location: 0, length: ns.length)).reversed() {
                    mutable.replaceCharacters(in: m.range, with: "")
                }
                out = mutable as String
            }
        }
        return out
    }

    /// Open a `.rd` package (zip), unzip, and parse `paper.rd.md`.
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

        self.init(rawContent: raw)
    }
}
