import SwiftUI

public struct DocumentPreviewView: View {
    public var document: URPDocument
    
    public init(document: URPDocument) {
        self.document = document
    }
    
    // Abstracted Block types for advanced rendering layout
    private enum RenderBlock: Identifiable {
        case paragraph(String)
        case header(level: Int, text: String)
        case bulletList(items: [String])
        case numberedList(items: [String])
        case blockquote(text: String)
        case image(alt: String, path: String)
        case table(headers: [String], rows: [[String]])
        case equationBlock(URPEquation)
        case claimBlock(URPClaim)
        case codeBlock(URPCodeBlock)
        case divider

        var id: String {
            switch self {
            case .paragraph(let text): return "p-\(text.hashValue)"
            case .header(let lvl, let text): return "h\(lvl)-\(text.hashValue)"
            case .bulletList(let items): return "bul-\(items.hashValue)"
            case .numberedList(let items): return "num-\(items.hashValue)"
            case .blockquote(let text): return "bq-\(text.hashValue)"
            case .image(_, let path): return "img-\(path)"
            case .table(_, let rows): return "tbl-\(rows.hashValue)"
            case .equationBlock(let eq): return "eq-\(eq.id)"
            case .claimBlock(let cl): return "cl-\(cl.id)"
            case .codeBlock(let cd): return "cd-\(cd.id)"
            case .divider: return "hr-\(UUID().uuidString)"
            }
        }
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header Title Block
                VStack(alignment: .leading, spacing: 12) {
                    if !document.manifest.paper.title.isEmpty {
                        Text(document.manifest.paper.title)
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundStyle(.primary)
                    } else {
                        Text("Untitled Research Paper")
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundStyle(.secondary)
                    }
                    
                    if !document.manifest.paper.subtitle.isEmpty {
                        Text(document.manifest.paper.subtitle)
                            .font(.system(.title3, design: .serif))
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    
                    Divider()
                        .padding(.vertical, 16)
                    
                    // Authors list
                    if !document.manifest.authors.isEmpty {
                        HStack(alignment: .top, spacing: 32) {
                            ForEach(document.manifest.authors) { author in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(author.name)
                                        .font(.system(.body, design: .serif))
                                        .fontWeight(.semibold)
                                    Text(author.affiliation)
                                        .font(.system(.caption, design: .serif))
                                        .foregroundStyle(.secondary)
                                    if let orcid = author.orcid {
                                        Text("ORCID: \(orcid)")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Stage badge & License
                    HStack(spacing: 16) {
                        Text(document.manifest.paper.status.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                        
                        Text("Spec: URP \(document.manifest.urp)")
                            .font(.system(.caption, design: .serif))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("License: \(document.manifest.license.text)")
                            .font(.system(.caption, design: .serif))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)
                }
                
                // Table of Contents / Outline Index
                if !document.sections.isEmpty {
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
                        
                        ForEach(document.sections) { section in
                            HStack {
                                Text(section.title)
                                    .font(.system(.body, design: .serif))
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Text("§ \(section.level)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        
                        Divider()
                            .padding(.top, 8)
                    }
                    .padding(.vertical, 8)
                }
                
                // Document Sections
                ForEach(document.sections) { section in
                    VStack(alignment: .leading, spacing: 18) {
                        Text(section.title)
                            .font(.system(section.level == 1 ? .title2 : .headline, design: .serif))
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .padding(.top, 12)
                        
                        let blocks = parseBody(section.body)
                        ForEach(blocks, id: \.id) { block in
                            renderBlock(block)
                        }
                    }
                }
            }
            .padding(48) // Spacious whitespace padding
            .frame(maxWidth: 700, alignment: .leading) // Readable text column width
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    @ViewBuilder
    private func renderBlock(_ block: RenderBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(inlineMarkdown(text))
                .font(.system(.body, design: .serif))
                .lineSpacing(8) // Standardized beautiful line height
                .foregroundStyle(.primary)
            
        case .image(let alt, let path):
            // Render full width inline image placeholder with standard caption styling
            VStack(alignment: .center, spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text(path)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    )
                
                Text(alt)
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical, 12)
            
        case .table(let headers, let rows):
            // Render table on its own inline column
            VStack(alignment: .leading, spacing: 8) {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        ForEach(headers, id: \.self) { header in
                            Text(header)
                                .font(.system(.subheadline, design: .serif))
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Divider()
                    
                    ForEach(0..<rows.count, id: \.self) { rIdx in
                        GridRow {
                            ForEach(rows[rIdx], id: \.self) { cell in
                                Text(cell)
                                    .font(.system(.body, design: .serif))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if rIdx < rows.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.02))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                )
            }
            .padding(.vertical, 8)
            
        case .equationBlock(let eq):
            equationBlockView(eq)
            
        case .claimBlock(let claim):
            ClaimCardView(claim: claim)
                .padding(.vertical, 4)
            
        case .codeBlock(let code):
            if code.language.lowercased() == "arcmark" {
                ArcmarkDiagramView(codeBlock: code)
                    .frame(maxWidth: .infinity)
            } else {
                codeBlockView(code)
            }

        case .header(let lvl, let text):
            Text(text)
                .font(.system(size: lvl <= 2 ? 20 : 16, weight: .semibold, design: .serif))
                .foregroundStyle(.primary)
                .padding(.top, 6)

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items.indices, id: \.self) { idx in
                    HStack(alignment: .top, spacing: 10) {
                        Text("•")
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(.secondary)
                        Text(inlineMarkdown(items[idx]))
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.vertical, 4)

        case .numberedList(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items.indices, id: \.self) { idx in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(idx + 1).")
                            .font(.system(.body, design: .serif).bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)
                        Text(inlineMarkdown(items[idx]))
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.vertical, 4)

        case .blockquote(let text):
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 3)
                Text(text)
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.04))
            .cornerRadius(8)
            .padding(.vertical, 4)

        case .divider:
            Divider().padding(.vertical, 12)
        }
    }
    
    @ViewBuilder
    private func equationBlockView(_ eq: URPEquation) -> some View {
        VStack(spacing: 8) {
            Text(LaTeXRenderer.render(eq.math))
                .font(.system(.title3, design: .serif))
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.03))
                .cornerRadius(8)

            HStack {
                Text("Equation \(eq.title)")
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("(\(eq.id))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)

            if let varBlock = document.variablesBlocks.first(where: { $0.forEquation == eq.id }) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Variables:")
                        .font(.system(.caption, design: .serif))
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    ForEach(varBlock.variables) { variable in
                        HStack(alignment: .top) {
                            Text(LaTeXRenderer.render(variable.symbol))
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                                .frame(width: 80, alignment: .leading)
                            Text(variable.definition)
                                .font(.system(.caption, design: .serif))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.02))
                .cornerRadius(6)
            }
        }
        .padding(.vertical, 8)
    }

    /// Parses a `[URP-EQ:id]`, `[URP-CLAIM:id]`, or `[URP-CODE:id]` placeholder line.
    private func parsePlaceholder(_ line: String) -> (kind: String, id: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("[URP-"), trimmed.hasSuffix("]") else { return nil }
        let inner = String(trimmed.dropFirst().dropLast()) // "URP-EQ:id"
        guard let colon = inner.firstIndex(of: ":") else { return nil }
        let kind = String(inner[..<colon])
        let id = String(inner[inner.index(after: colon)...])
        guard ["URP-EQ", "URP-CLAIM", "URP-CODE"].contains(kind), !id.isEmpty else { return nil }
        return (kind, id)
    }
    
    @ViewBuilder
    private func codeBlockView(_ code: URPCodeBlock) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(code.language.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if code.executable {
                    Text("EXECUTABLE")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.12))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.05))
            
            Divider()
            
            Text(code.code)
                .font(.system(.body, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.02))
            
            Divider()
            
            HStack {
                Text(code.title)
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("ID: \(code.id)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.01))
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .padding(.vertical, 8)
    }
    
    // Helper to parse a markdown string into blocks
    private func parseBody(_ text: String) -> [RenderBlock] {
        var blocks: [RenderBlock] = []
        let lines = text.components(separatedBy: .newlines)

        var currentParagraphLines: [String] = []
        var inTable = false
        var tableHeaders: [String] = []
        var tableRows: [[String]] = []

        func flushParagraph() {
            let pText = currentParagraphLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !pText.isEmpty {
                blocks.append(.paragraph(pText))
            }
            currentParagraphLines = []
        }

        func flushTable() {
            if !tableHeaders.isEmpty || !tableRows.isEmpty {
                blocks.append(.table(headers: tableHeaders, rows: tableRows))
            }
            tableHeaders = []
            tableRows = []
            inTable = false
        }

        var idx = 0
        while idx < lines.count {
            let line = lines[idx]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if inTable { flushTable() }
                flushParagraph()
                idx += 1
                continue
            }

            // Structured-block placeholders, e.g. [URP-EQ:eq-1], [URP-CLAIM:claim-1], [URP-CODE:diag-1]
            if let (kind, blockId) = parsePlaceholder(trimmed) {
                flushParagraph()
                if inTable { flushTable() }
                switch kind {
                case "URP-EQ":
                    if let eq = document.equations.first(where: { $0.id == blockId }) {
                        blocks.append(.equationBlock(eq))
                    }
                case "URP-CLAIM":
                    if let claim = document.claims.first(where: { $0.id == blockId }) {
                        blocks.append(.claimBlock(claim))
                    }
                case "URP-CODE":
                    if let code = document.codeBlocks.first(where: { $0.id == blockId }) {
                        blocks.append(.codeBlock(code))
                    }
                default:
                    break
                }
                idx += 1
                continue
            }

            // Divider
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                if inTable { flushTable() }
                blocks.append(.divider)
                idx += 1
                continue
            }

            // Headers (## … ### …)
            if trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ") {
                flushParagraph()
                if inTable { flushTable() }
                let hashCount = trimmed.prefix(while: { $0 == "#" }).count
                let body = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                let level = min(hashCount, 3)
                blocks.append(.header(level: level, text: String(body)))
                idx += 1
                continue
            }

            // Blockquote
            if trimmed.hasPrefix("> ") {
                flushParagraph()
                if inTable { flushTable() }
                blocks.append(.blockquote(text: String(trimmed.dropFirst(2))))
                idx += 1
                continue
            }

            // Bullet list gather
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flushParagraph()
                if inTable { flushTable() }
                var items: [String] = []
                while idx < lines.count {
                    let lt = lines[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                    if lt.hasPrefix("- ") || lt.hasPrefix("* ") {
                        items.append(String(lt.dropFirst(2)))
                    } else if lt.isEmpty {
                        // allow blank lines inside the list? Simple greedy — break on blank to keep blocks crisp.
                        break
                    } else { break }
                    idx += 1
                }
                if !items.isEmpty { blocks.append(.bulletList(items: items)) }
                continue
            }

            // Numbered list
            if trimmed.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
                flushParagraph()
                if inTable { flushTable() }
                var items: [String] = []
                while idx < lines.count {
                    let lt = lines[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                    if lt.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
                        let dot = lt.range(of: ". ")!
                        items.append(String(lt[dot.upperBound...]))
                    } else { break }
                    idx += 1
                }
                if !items.isEmpty { blocks.append(.numberedList(items: items)) }
                continue
            }

            // Legacy fallback triggers for inline equation/claim/code references.
            if trimmed.contains("claim-") || trimmed.contains("<claim") {
                flushParagraph()
                if inTable { flushTable() }

                for claim in document.claims {
                    if trimmed.contains(claim.id) {
                        blocks.append(.claimBlock(claim))
                    }
                }
                idx += 1
                continue
            }

            if trimmed.contains("eq-") || trimmed.contains("<variables") {
                flushParagraph()
                if inTable { flushTable() }

                for eq in document.equations {
                    if trimmed.contains(eq.id) {
                        blocks.append(.equationBlock(eq))
                    }
                }
                idx += 1
                continue
            }

            if trimmed.contains("code-") || trimmed.contains("diag-") || trimmed.contains("arcmark") {
                flushParagraph()
                if inTable { flushTable() }

                for code in document.codeBlocks {
                    if trimmed.contains(code.id) {
                        blocks.append(.codeBlock(code))
                    }
                }
                idx += 1
                continue
            }

            // Check for image syntax: ![alt](path)
            if trimmed.hasPrefix("![") && trimmed.contains("](") && trimmed.hasSuffix(")") {
                flushParagraph()
                if inTable { flushTable() }

                let parts = trimmed.components(separatedBy: "](")
                if parts.count >= 2 {
                    let alt = parts[0].dropFirst(2)
                    let path = parts[1].dropLast()
                    blocks.append(.image(alt: String(alt), path: String(path)))
                }
                idx += 1
                continue
            }

            // Check for table structure
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                flushParagraph()
                inTable = true

                let cells = trimmed.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }

                if cells.first?.contains("---") == true {
                    idx += 1
                    continue
                }

                if tableHeaders.isEmpty {
                    tableHeaders = cells
                } else {
                    tableRows.append(cells)
                }
                idx += 1
                continue
            }

            // Normal paragraph line
            if inTable { flushTable() }
            currentParagraphLines.append(line)
            idx += 1
        }

        if inTable { flushTable() }
        flushParagraph()

        return blocks
    }

    private func inlineMarkdown(_ s: String) -> AttributedString {
        var result = AttributedString()
        var bold = false
        var italic = false
        var code = false
        var i = s.startIndex
        while i < s.endIndex {
            if s[i...].hasPrefix("**") {
                bold.toggle()
                i = s.index(i, offsetBy: 2)
                continue
            }
            if s[i...].hasPrefix("\\(") {
                let start = s.index(i, offsetBy: 2)
                if let end = s[start...].range(of: "\\)") {
                    let latex = String(s[start..<end.lowerBound])
                    result += LaTeXRenderer.render(latex)
                    i = end.upperBound
                    continue
                }
            }
            if s[i...].hasPrefix("$") {
                let start = s.index(i, offsetBy: 1)
                if let end = s[start...].range(of: "$") {
                    let latex = String(s[start..<end.lowerBound])
                    result += LaTeXRenderer.render(latex)
                    i = end.upperBound
                    continue
                }
            }
            let ch = s[i]
            if ch == "*" && !code {
                italic.toggle()
                i = s.index(after: i)
                continue
            }
            if ch == "`" {
                code.toggle()
                i = s.index(after: i)
                continue
            }
            var piece = AttributedString(String(ch))
            #if canImport(SwiftUI)
            if code {
                piece.font = .custom("Menlo", size: 14)
                piece.foregroundColor = Color.accentColor
            } else if bold {
                piece.font = .system(size: 16, weight: .bold, design: .serif)
            } else if italic {
                piece.font = .system(size: 16, weight: .regular, design: .serif).italic()
            } else {
                piece.font = .system(size: 16, design: .serif)
                piece.foregroundColor = .primary
            }
            #endif
            result += piece
            i = s.index(after: i)
        }
        return result
    }
}
