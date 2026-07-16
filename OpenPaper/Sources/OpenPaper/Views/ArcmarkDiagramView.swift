import SwiftUI

public struct ArcmarkDiagramView: View {
    public var codeBlock: URPCodeBlock
    public let diagram: ArcmarkDiagram
    
    public init(codeBlock: URPCodeBlock) {
        self.codeBlock = codeBlock
        self.diagram = ArcmarkParser.parse(codeBlock.code)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Arcmark Diagram", systemImage: "circle.grid.2x2.fill")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Text("ID: \(codeBlock.id)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            Divider()
            
            if diagram.nodes.isEmpty {
                VStack {
                    Text("Empty Arcmark diagram or invalid syntax.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                GeometryReader { geo in
                    let width = geo.size.width
                    let height = geo.size.height
                    let padding: CGFloat = 60
                    let nodeCount = diagram.nodes.count
                    let spacing = nodeCount > 1 ? (width - (padding * 2)) / CGFloat(nodeCount - 1) : 0
                    
                    let positions = (0..<nodeCount).reduce(into: [String: CGPoint]()) { dict, index in
                        let node = diagram.nodes[index]
                        let x = padding + CGFloat(index) * spacing
                        let y = height * 0.7
                        dict[node.id] = CGPoint(x: x, y: y)
                    }
                    
                    ZStack {
                        // 1. Draw Links (Arcs) - Completely Static
                        ForEach(diagram.links) { link in
                            if let start = positions[link.source], let end = positions[link.target] {
                                Path { path in
                                    path.move(to: start)
                                    let controlX = (start.x + end.x) / 2
                                    let controlY = start.y - abs(start.x - end.x) * 0.5
                                    path.addQuadCurve(to: end, control: CGPoint(x: controlX, y: controlY))
                                }
                                .stroke(
                                    Color.accentColor.opacity(0.4),
                                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                                )
                            }
                        }
                        
                        // 2. Draw Nodes - Completely Static
                        ForEach(0..<nodeCount, id: \.self) { index in
                            let node = diagram.nodes[index]
                            if let pos = positions[node.id] {
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.secondary.opacity(0.3))
                                        .frame(width: 12, height: 12)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                        )
                                        .shadow(radius: 1)
                                    
                                    Text(node.label)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .frame(width: spacing > 0 ? spacing * 0.9 : 100)
                                        .multilineTextAlignment(.center)
                                }
                                .position(x: pos.x, y: pos.y + 12)
                            }
                        }
                    }
                }
                .frame(minHeight: 220)
            }
            
            if !codeBlock.title.isEmpty {
                Divider()
                Text(codeBlock.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .padding(.vertical, 8)
    }
}

public struct ArcmarkDiagramView_Previews: PreviewProvider {
    public static var previews: some View {
        ArcmarkDiagramView(codeBlock: URPCodeBlock(
            id: "diag-sample",
            title: "Sample Arcmark",
            language: "arcmark",
            executable: false,
            environment: "",
            code: "nodes:\n  A: Generation\n  B: Local Grid\n  C: Consumers\nlinks:\n  A -> B\n  B -> C\n  C -> A"
        ))
        .frame(width: 450)
        .padding()
    }
}
