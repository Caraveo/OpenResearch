import SwiftUI
import AppKit

/// A "foco"-style rich inline editor for URP paper sections with live preview toggle.
public struct FocoSectionEditor: View {
    @Binding var text: String
    var placeholder: String
    var field: ContentView.Field
    @FocusState.Binding var focusedField: ContentView.Field?

    @State private var slashVisible = false
    @State private var slashAnchor: String.Index?
    @State private var dismissToken = UUID()

    public init(
        text: Binding<String>,
        placeholder: String,
        field: ContentView.Field,
        focusedField: FocusState<ContentView.Field?>.Binding
    ) {
        self._text = text
        self.placeholder = placeholder
        self.field = field
        self._focusedField = focusedField
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                // TextEditor is kept in the hierarchy at all times to prevent FocusState binding breaks
                TextEditor(text: $text)
                    .font(.system(.body, design: .serif))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(8)
                    .focused($focusedField, equals: field)
                    .opacity(focusedField == field ? 1 : 0)
                    .frame(minHeight: focusedField == field ? 120 : 0)
                    .onChange(of: text) { (_, newValue) in
                        detectSlash(change: newValue)
                    }

                if text.isEmpty && focusedField == field && !slashVisible {
                    Text(placeholder)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.tertiary)
                        .allowsHitTesting(false)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                }

                if focusedField != field {
                    // Rendered live view when not editing
                    VStack(alignment: .leading, spacing: 10) {
                        let blocks = parseBody(text)
                        if blocks.isEmpty {
                            Text(placeholder)
                                .font(.system(.body, design: .serif).italic())
                                .foregroundStyle(.tertiary)
                        } else {
                            ForEach(blocks) { block in
                                renderBlock(block)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField = field
                    }
                    .background(Color.secondary.opacity(0.02))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.08), lineWidth: 1)
                    )
                }
            }
            .background(focusedField == field ? Color.secondary.opacity(0.03) : Color.clear)
            .cornerRadius(8)
            .overlay(alignment: .topLeading) {
                if focusedField == field && slashVisible {
                    SlashMenuView { item in
                        insertItem(item)
                    } onDismiss: {
                        withAnimation(.easeOut(duration: 0.12)) { slashVisible = false }
                        slashAnchor = nil
                    }
                    .padding(.top, 44)
                    .padding(.leading, 18)
                    .zIndex(2)
                    .id(dismissToken)
                }
            }
            
            if focusedField == field {
                HStack {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Block parsing & rendering ---------------------------------

    private enum RenderBlock: Identifiable {
        case paragraph(String)
        case header(level: Int, text: String)
        case bulletList(items: [String])
        case numberedList(items: [String])
        case blockquote(String)
        case image(alt: String, path: String)
        case table(headers: [String], rows: [[String]])
        case divider
        case equation(math: String, title: String, id: String)
        case arcmark(code: String, title: String, id: String)
        case codeBlock(code: String, lang: String, title: String, id: String)
        case claim(body: String, id: String, type: String, confidence: String, sources: String)
        
        var id: String {
            switch self {
            case .paragraph(let t): return "p-\(t.hashValue)"
            case .header(let l, let t): return "h-\(l)-\(t.hashValue)"
            case .bulletList(let i): return "bl-\(i.hashValue)"
            case .numberedList(let i): return "nl-\(i.hashValue)"
            case .blockquote(let t): return "bq-\(t.hashValue)"
            case .image(let a, let p): return "img-\(a)-\(p)"
            case .table(let h, let r): return "tbl-\(h.hashValue)-\(r.hashValue)"
            case .divider: return "div-\(UUID().uuidString)"
            case .equation(let m, let t, let i): return "eq-\(i)-\(m.hashValue)"
            case .arcmark(let c, let t, let i): return "arc-\(i)-\(c.hashValue)"
            case .codeBlock(let c, let l, let t, let i): return "code-\(i)-\(c.hashValue)"
            case .claim(let b, let i, _, _, _): return "claim-\(i)-\(b.hashValue)"
            }
        }
    }

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

            // Divider
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                if inTable { flushTable() }
                blocks.append(.divider)
                idx += 1
                continue
            }

            // Headers
            if trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ") {
                flushParagraph()
                if inTable { flushTable() }
                let hashCount = trimmed.prefix(while: { $0 == "#" }).count
                let body = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                let level = min(hashCount, 3)
                blocks.append(.header(level: level, text: body))
                idx += 1
                continue
            }

            // Blockquote
            if trimmed.hasPrefix("> ") {
                flushParagraph()
                if inTable { flushTable() }
                let body = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                blocks.append(.blockquote(body))
                idx += 1
                continue
            }

            // Bullet list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flushParagraph()
                if inTable { flushTable() }
                var items: [String] = []
                while idx < lines.count {
                    let nextLine = lines[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                    if nextLine.hasPrefix("- ") {
                        items.append(String(nextLine.dropFirst(2)))
                    } else if nextLine.hasPrefix("* ") {
                        items.append(String(nextLine.dropFirst(2)))
                    } else {
                        break
                    }
                    idx += 1
                }
                blocks.append(.bulletList(items: items))
                continue
            }

            // Numbered list
            if trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
                flushParagraph()
                if inTable { flushTable() }
                var items: [String] = []
                while idx < lines.count {
                    let nextLine = lines[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                    if let dotRange = nextLine.range(of: ".") {
                        let prefix = String(nextLine[..<dotRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                        if Int(prefix) != nil {
                            items.append(String(nextLine[dotRange.upperBound...]).trimmingCharacters(in: .whitespaces))
                            idx += 1
                            continue
                        }
                    }
                    break
                }
                blocks.append(.numberedList(items: items))
                continue
            }

            // Equation blocks
            if trimmed.hasPrefix("$$") {
                flushParagraph()
                if inTable { flushTable() }
                var mathLines: [String] = []
                idx += 1
                while idx < lines.count {
                    let next = lines[idx]
                    if next.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("$$") {
                        var caption = ""
                        var id = ""
                        if idx + 1 < lines.count {
                            let capLine = lines[idx + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                            if capLine.hasPrefix("{#") && capLine.hasSuffix("}") {
                                id = String(capLine.dropFirst(2).prefix(while: { $0 != " " }))
                                if let titleRange = capLine.range(of: "title=\"([^\"]+)\"", options: .regularExpression) {
                                    let sub = capLine[titleRange]
                                    caption = String(sub.dropFirst(7).dropLast())
                                }
                                idx += 1
                            }
                        }
                        blocks.append(.equation(math: mathLines.joined(separator: "\n"), title: caption, id: id))
                        break
                    }
                    mathLines.append(next)
                    idx += 1
                }
                idx += 1
                continue
            }

            // Code and arcmark blocks
            if trimmed.hasPrefix("```") {
                flushParagraph()
                if inTable { flushTable() }
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                var codeLines: [String] = []
                idx += 1
                while idx < lines.count {
                    let next = lines[idx]
                    if next.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") {
                        var caption = ""
                        var id = ""
                        if idx + 1 < lines.count {
                            let capLine = lines[idx + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                            if capLine.hasPrefix("{#") && capLine.hasSuffix("}") {
                                id = String(capLine.dropFirst(2).prefix(while: { $0 != " " }))
                                if let titleRange = capLine.range(of: "title=\"([^\"]+)\"", options: .regularExpression) {
                                    let sub = capLine[titleRange]
                                    caption = String(sub.dropFirst(7).dropLast())
                                }
                                idx += 1
                            }
                        }
                        if lang.lowercased() == "arcmark" {
                            blocks.append(.arcmark(code: codeLines.joined(separator: "\n"), title: caption, id: id))
                        } else {
                            blocks.append(.codeBlock(code: codeLines.joined(separator: "\n"), lang: lang, title: caption, id: id))
                        }
                        break
                    }
                    codeLines.append(next)
                    idx += 1
                }
                idx += 1
                continue
            }

            // Claim block
            if trimmed.hasPrefix("<claim") {
                flushParagraph()
                if inTable { flushTable() }
                var id = ""
                var type = ""
                var confidence = ""
                var sources = ""
                if let closeTag = trimmed.firstIndex(of: ">") {
                    let attrs = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closeTag])
                    id = attrValue(attrs, name: "id") ?? ""
                    type = attrValue(attrs, name: "type") ?? ""
                    confidence = attrValue(attrs, name: "confidence") ?? ""
                    sources = attrValue(attrs, name: "sources") ?? ""
                }
                
                var claimLines: [String] = []
                idx += 1
                while idx < lines.count {
                    let next = lines[idx]
                    if next.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("</claim>") {
                        let finalLine = next.trimmingCharacters(in: .whitespacesAndNewlines)
                        let textOnly = finalLine.replacingOccurrences(of: "</claim>", with: "")
                        if !textOnly.isEmpty { claimLines.append(textOnly) }
                        break
                    }
                    claimLines.append(next)
                    idx += 1
                }
                blocks.append(.claim(body: claimLines.joined(separator: "\n"), id: id, type: type, confidence: confidence, sources: sources))
                idx += 1
                continue
            }

            // Table
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                flushParagraph()
                inTable = true
                if trimmed.contains("---") {
                    idx += 1
                    continue
                }
                let cells = trimmed.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                if tableHeaders.isEmpty {
                    tableHeaders = cells
                } else {
                    tableRows.append(cells)
                }
                idx += 1
                continue
            }

            // Image
            if trimmed.hasPrefix("![") && trimmed.contains("](") && trimmed.hasSuffix(")") {
                flushParagraph()
                if inTable { flushTable() }
                if let openBracket = trimmed.firstIndex(of: "["),
                   let closeBracket = trimmed.firstIndex(of: "]"),
                   let openParen = trimmed.firstIndex(of: "("),
                   let closeParen = trimmed.firstIndex(of: ")") {
                    let alt = String(trimmed[trimmed.index(after: openBracket)..<closeBracket])
                    let path = String(trimmed[trimmed.index(after: openParen)..<closeParen])
                    blocks.append(.image(alt: alt, path: path))
                }
                idx += 1
                continue
            }

            currentParagraphLines.append(line)
            idx += 1
        }
        if inTable { flushTable() }
        flushParagraph()
        return blocks
    }

    private func attrValue(_ attrs: String, name: String) -> String? {
        if let range = attrs.range(of: name + "=\"([^\"]+)\"", options: .regularExpression) {
            let matched = attrs[range]
            if let firstQuote = matched.firstIndex(of: "\""), let lastQuote = matched.lastIndex(of: "\"") {
                return String(matched[matched.index(after: firstQuote)..<lastQuote])
            }
        }
        return nil
    }

    @ViewBuilder
    private func renderBlock(_ block: RenderBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(inlineMarkdown(text))
                .font(.system(.body, design: .serif))
                .lineSpacing(6)
                .foregroundStyle(.primary)
                .padding(.vertical, 2)
            
        case .image(let alt, let path):
            VStack(alignment: .center, spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.1))
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("Image: \(path)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    )
                Text(alt)
                    .font(.system(.caption, design: .serif).italic())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            
        case .header(let level, let text):
            Text(text)
                .font(.system(level == 2 ? .headline : .subheadline, design: .serif))
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .padding(.top, 8)
                .padding(.bottom, 2)
            
        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text(inlineMarkdown(item))
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 4)
            
        case .numberedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(0..<items.count, id: \.self) { idx in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(idx + 1).")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(inlineMarkdown(items[idx]))
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 4)
            
        case .blockquote(let text):
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 3)
                    .padding(.trailing, 12)
                Text(inlineMarkdown(text))
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            
        case .table(let headers, let rows):
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ForEach(headers, id: \.self) { h in
                        Text(h)
                            .font(.system(.body, design: .serif).bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.05))
                
                Divider()
                
                ForEach(0..<rows.count, id: \.self) { rIdx in
                    let row = rows[rIdx]
                    HStack {
                        ForEach(0..<row.count, id: \.self) { cIdx in
                            Text(row[cIdx])
                                .font(.system(.body, design: .serif))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 6)
                    if rIdx < rows.count - 1 {
                        Divider()
                    }
                }
            }
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
            .padding(.vertical, 8)
            
        case .divider:
            Divider()
                .padding(.vertical, 12)
                
        case .equation(let math, let title, let id):
            VStack(alignment: .center, spacing: 6) {
                Text(LaTeXRenderer.render(math))
                    .font(.system(.title3, design: .serif))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black.opacity(0.04))
                    .cornerRadius(6)
                if !title.isEmpty || !id.isEmpty {
                    Text("\(title) (\(id))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            
        case .arcmark(let code, let title, let id):
            ArcmarkDiagramView(codeBlock: URPCodeBlock(
                id: id.isEmpty ? "diag-pipeline" : id,
                title: title.isEmpty ? "Topology" : title,
                language: "arcmark",
                executable: false,
                environment: "",
                code: code
            ))
            .frame(maxWidth: .infinity)
            
        case .codeBlock(let code, let lang, let title, let id):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(lang.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !id.isEmpty {
                        Text(id)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                ScrollView(.horizontal) {
                    Text(code)
                        .font(.system(.body, design: .monospaced))
                        .padding(10)
                }
                .background(Color.black.opacity(0.05))
                .cornerRadius(6)
                if !title.isEmpty {
                    Text(title)
                        .font(.caption.italic())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            
        case .claim(let body, let id, let type, let confidence, let sources):
            ClaimCardView(claim: URPClaim(
                id: id,
                type: type,
                confidence: confidence,
                sources: sources,
                body: body
            ))
            .padding(.vertical, 4)
        }
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
                piece.font = .system(size: 15, weight: .bold, design: .serif)
            } else if italic {
                piece.font = .system(size: 15, weight: .regular, design: .serif).italic()
            } else {
                piece.font = .system(size: 15, design: .serif)
                piece.foregroundColor = .primary
            }
            #endif
            result += piece
            i = s.index(after: i)
        }
        return result
    }

    // MARK: Slash detection -------------------------------------------------

    private func detectSlash(change new: String) {
        guard new.contains("/") else {
            if slashVisible { withAnimation { slashVisible = false }; slashAnchor = nil }
            return
        }
        let lines = new.components(separatedBy: "\n")
        var offset = 0
        for line in lines {
            if line == "/" {
                let idx = new.index(new.startIndex, offsetBy: offset)
                slashAnchor = idx
                withAnimation(.easeOut(duration: 0.15)) { slashVisible = true }
                return
            }
            offset += line.count + 1
        }
        if slashVisible { withAnimation { slashVisible = false }; slashAnchor = nil }
    }

    private func insertItem(_ item: SlashItem) {
        guard let anchor = slashAnchor else { return }
        let pre = String(text[..<anchor])
        let post = String(text[text.index(after: anchor)...])
        let snippet = item.snippet
        text = pre + snippet + post
        withAnimation { slashVisible = false }
        self.slashAnchor = nil
        self.dismissToken = UUID()
        focusedField = field
    }
}

// MARK: - Menu ---------------------------------------

private struct SlashMenuView: View {
    let onSelect: (SlashItem) -> Void
    let onDismiss: () -> Void

    @State private var hovered: Int? = nil

    private let items: [SlashItem] = [
        SlashItem(name: "Header",            symbol: "textformat.size", snippet: "## \n"),
        SlashItem(name: "Subheader",        symbol: "textformat.size.larger", snippet: "### \n"),
        SlashItem(name: "LaTeX Equation",   symbol: "function", snippet: """
$$
x = a + b
$$
{#eq-\(UUID().uuidString.prefix(6).lowercased()) title="Equation"}

"""),
        SlashItem(name: "Image",            symbol: "photo", snippet: "![alt text](assets/image.webp)\n"),
        SlashItem(name: "Table (3 × 3)",   symbol: "tablecells", snippet: """
| Column A | Column B | Column C |
| --- | --- | --- |
| 1 | alpha | note |
| 2 | beta | note |
| 3 | gamma | note |

"""),
        SlashItem(name: "Bullet List",      symbol: "list.bullet", snippet: "- \n- \n- \n"),
        SlashItem(name: "Numbered List",    symbol: "list.number", snippet: "1. \n2. \n3. \n"),
        SlashItem(name: "Blockquote",       symbol: "text.quote", snippet: "> \n"),
        SlashItem(name: "Code Block",       symbol: "chevron.left.forwardslash.chevron.right", snippet: """
```swift

```
{#code-\(UUID().uuidString.prefix(6).lowercased()) title="Code Block"}

"""),
        SlashItem(name: "Arcmark Diagram",  symbol: "circle.grid.2x2", snippet: """
```arcmark
nodes:
  A: Node A
  B: Node B
links:
  A -> B
```
{#diag-\(UUID().uuidString.prefix(6).lowercased()) title="Topology"}

"""),
        SlashItem(name: "Variables",        symbol: "list.number", snippet: """
<variables for="eq-new">
  <variable symbol="$x$">definition</variable>
</variables>

"""),
        SlashItem(name: "Claim",            symbol: "checkmark.circle", snippet: """
<claim id="claim-\(UUID().uuidString.prefix(6).lowercased())" type="empirical" confidence="moderate" sources="">
Write your claim statement here.
</claim>

"""),
        SlashItem(name: "Inline Code",      symbol: "curlybraces", snippet: "`code`\n"),
        SlashItem(name: "Divider",          symbol: "minus", snippet: "---\n"),
        SlashItem(name: "Inline Math",      symbol: "function", snippet: "$ x = a + b $\n"),
        SlashItem(name: "Link",             symbol: "link", snippet: "[label](https://)\n")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text("foco")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                Text("Insert")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(.caption2, weight: .bold))
                        .padding(4)
                        .clipShape(Circle())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(items.indices, id: \.self) { idx in
                        let item = items[idx]
                        Button {
                            onSelect(item)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: item.symbol)
                                    .frame(width: 18)
                                    .foregroundStyle(.orange)
                                Text(item.name)
                                    .font(.system(size: 12, design: .serif))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(idx == hovered ? Color.secondary.opacity(0.12) : Color.clear)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { h in hovered = h ? idx : hovered }
                    }
                }
            }
            .frame(maxHeight: 280)
            .padding(.bottom, 8)
        }
        .frame(width: 240)
        .background(.regularMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
    }
}

private struct SlashItem {
    let name: String
    let symbol: String
    let snippet: String
}