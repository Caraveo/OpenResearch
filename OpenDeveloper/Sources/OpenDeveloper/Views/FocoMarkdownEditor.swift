import SwiftUI
import AppKit

/// "foco"-style markdown editor for OpenDeveloper.
///
/// Self-contained — binds to a single `String` of raw paper.rd.md source and
/// manages its own focus state. Typing `/` at the start of a new line summons
/// the same focus insert menu as OpenWriter's FocoSectionEditor (header, latex,
/// image, table, lists, blockquote, code block, arcmark diagram, variables,
/// claim, divider, inline math, link).
public struct FocoMarkdownEditor: View {
    @Binding public var text: String

    @FocusState private var isFocused: Bool
    @State private var slashVisible = false
    @State private var slashAnchor: String.Index?
    @State private var dismissToken = UUID()

    public init(text: Binding<String>) {
        self._text = text
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Editor Toolbar
            HStack {
                Label("Editor Source (paper.rd)", systemImage: "doc.plaintext")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()

                Text("\(text.components(separatedBy: .newlines).count) lines")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text("Type `/` on a new line to insert")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.04))

            Divider()

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .lineSpacing(4)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
                    .focused($isFocused)
                    .onChange(of: text) { (_, new) in
                        detectSlash(change: new)
                    }
                    .overlay(alignment: .topLeading) {
                        if slashVisible {
                            SlashMenu(items: menuItems) { item in
                                insertItem(item)
                            } onDismiss: {
                                withAnimation { slashVisible = false }
                                slashAnchor = nil
                            }
                            .padding(.top, 44)
                            .padding(.leading, 18)
                            .id(dismissToken)
                        }
                    }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .background(Color(nsColor: .textBackgroundColor))
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
                slashAnchor = new.index(new.startIndex, offsetBy: offset)
                withAnimation(.easeOut(duration: 0.15)) { slashVisible = true }
                return
            }
            offset += line.count + 1
        }
        if slashVisible { withAnimation { slashVisible = false }; slashAnchor = nil }
    }

    private func insertItem(_ item: SlashMenuItem) {
        guard let anchor = slashAnchor else { return }
        let pre = String(text[..<anchor])
        let post = String(text[text.index(after: anchor)...])
        text = pre + item.snippet + post
        withAnimation { slashVisible = false }
        slashAnchor = nil
        dismissToken = UUID()
        isFocused = true
    }

    // MARK: Menu items ------------------------------------------------------

    struct SlashMenuItem: Identifiable {
        let id = UUID()
        let name: String
        let symbol: String
        let snippet: String
    }

    private var menuItems: [SlashMenuItem] {
        [
            .init(name: "Header",        symbol: "textformat.size",        snippet: "## \n"),
            .init(name: "Subheader",      symbol: "textformat.size.larger", snippet: "### \n"),
            .init(name: "LaTeX Equation", symbol: "function",               snippet: """
$$
x = a + b
$$
{#eq-\(UUID().uuidString.prefix(6).lowercased()) title="Equation"}

"""),
            .init(name: "Image",          symbol: "photo",                  snippet: "![alt text](assets/image.webp)\n"),
            .init(name: "Table (3 × 3)",  symbol: "tablecells",             snippet: """
| Column A | Column B | Column C |
| --- | --- | --- |
| 1 | alpha | note |
| 2 | beta | note |
| 3 | gamma | note |

"""),
            .init(name: "Bullet List",    symbol: "list.bullet",            snippet: "- \n- \n- \n"),
            .init(name: "Numbered List",  symbol: "list.number",           snippet: "1. \n2. \n3. \n"),
            .init(name: "Blockquote",     symbol: "text.quote",            snippet: "> \n"),
            .init(name: "Code Block",     symbol: "chevron.left.forwardslash.chevron.right", snippet: """
```swift

```
{#code-\(UUID().uuidString.prefix(6).lowercased()) title="Code Block"}

"""),
            .init(name: "Arcmark Diagram",symbol: "circle.grid.2x2",       snippet: """
```arcmark
nodes:
  A: Node A
  B: Node B
links:
  A -> B
```
{#diag-\(UUID().uuidString.prefix(6).lowercased()) title="Topology"}

"""),
            .init(name: "Variables",      symbol: "list.number",            snippet: """
<variables for="eq-new">
  <variable symbol="$x$">definition</variable>
</variables>

"""),
            .init(name: "Claim",          symbol: "checkmark.circle",       snippet: """
<claim id="claim-\(UUID().uuidString.prefix(6).lowercased())" type="empirical" confidence="moderate" sources="">
Write your claim statement here.
</claim>

"""),
            .init(name: "Inline Code",    symbol: "curlybraces",           snippet: "`code`\n"),
            .init(name: "Divider",        symbol: "minus",                 snippet: "---\n"),
            .init(name: "Inline Math",    symbol: "function",             snippet: "$ x = a + b $\n"),
            .init(name: "Link",           symbol: "link",                 snippet: "[label](https://)\n")
        ]
    }

    // MARK: Menu view -------------------------------------------------------

    struct SlashMenu: View {
        let items: [SlashMenuItem]
        let onSelect: (SlashMenuItem) -> Void
        let onDismiss: () -> Void

        @State private var hovered: Int? = nil

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
                            .font(.system(size: 11, weight: .bold))
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
}