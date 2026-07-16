import SwiftUI

public struct MarkdownEditorView: View {
    @Binding public var text: String
    
    // Command popup control
    private var showCommands: Bool {
        text.hasSuffix("\\")
    }
    
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
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.04))
            
            Divider()
            
            // Inline commands notification bar when typing \
            if showCommands {
                HStack(spacing: 12) {
                    Text("Insert:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    
                    Group {
                        Button("Claim") { insertTemplate(.claim) }
                        Button("Equation") { insertTemplate(.equation) }
                        Button("Variables") { insertTemplate(.variables) }
                        Button("Arcmark Diagram") { insertTemplate(.diagram) }
                        Button("Table") { insertTemplate(.table) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .font(.caption)
                    .controlSize(.small)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.05))
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: showCommands)
            }
            
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .lineSpacing(4)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .scrollContentBackground(.hidden)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private enum URPType {
        case claim, equation, variables, diagram, table
    }
    
    private func insertTemplate(_ type: URPType) {
        // Remove the trailing backslash
        if text.hasSuffix("\\") {
            text.removeLast()
        }
        
        let template: String
        switch type {
        case .claim:
            template = """
<claim id="claim-new" type="empirical" confidence="moderate">
Write your claim statement here.
</claim>
"""
        case .equation:
            template = """

$$
E = Pt
$$
{#eq-new title="Equation Title"}
"""
        case .variables:
            template = """

<variables for="eq-new">
  <variable symbol="$E$">definition</variable>
</variables>
"""
        case .diagram:
            template = """

```arcmark
nodes:
  A: Node A
  B: Node B
links:
  A -> B
```
{#diag-new title="Diagram Title"}
"""
        case .table:
            template = """

| Header 1 | Header 2 |
|---|---|
| Cell 1 | Cell 2 |
"""
        }
        
        text += template
    }
}
