import Foundation

public struct ArcmarkNode: Identifiable, Equatable {
    public var id: String
    public var label: String
}

public struct ArcmarkLink: Identifiable, Equatable {
    public var id: String { "\(source)->\(target)" }
    public var source: String
    public var target: String
}

public struct ArcmarkDiagram: Equatable {
    public var nodes: [ArcmarkNode] = []
    public var links: [ArcmarkLink] = []
}

public struct ArcmarkParser {
    public static func parse(_ text: String) -> ArcmarkDiagram {
        var diagram = ArcmarkDiagram()
        let lines = text.components(separatedBy: .newlines)
        
        var inNodes = false
        var inLinks = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
                continue
            }
            
            if trimmed.lowercased() == "nodes:" {
                inNodes = true
                inLinks = false
                continue
            }
            
            if trimmed.lowercased() == "links:" {
                inNodes = false
                inLinks = true
                continue
            }
            
            if inNodes {
                let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
                if parts.count >= 1 {
                    let id = parts[0].trimmingCharacters(in: .whitespaces)
                    let label = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "") : id
                    diagram.nodes.append(ArcmarkNode(id: id, label: label))
                }
            } else if inLinks {
                if trimmed.contains("->") {
                    let parts = trimmed.components(separatedBy: "->")
                    if parts.count >= 2 {
                        let source = parts[0].trimmingCharacters(in: .whitespaces)
                        let target = parts[1].trimmingCharacters(in: .whitespaces)
                        diagram.links.append(ArcmarkLink(source: source, target: target))
                    }
                } else if trimmed.contains("<->") {
                    let parts = trimmed.components(separatedBy: "<->")
                    if parts.count >= 2 {
                        let source = parts[0].trimmingCharacters(in: .whitespaces)
                        let target = parts[1].trimmingCharacters(in: .whitespaces)
                        diagram.links.append(ArcmarkLink(source: source, target: target))
                        diagram.links.append(ArcmarkLink(source: target, target: source))
                    }
                }
            } else {
                // Fallback: try parsing line directly as a link or a node
                if trimmed.contains("->") {
                    let parts = trimmed.components(separatedBy: "->")
                    if parts.count >= 2 {
                        let src = parts[0].trimmingCharacters(in: .whitespaces)
                        let tgt = parts[1].trimmingCharacters(in: .whitespaces)
                        // Add implicit nodes if they don't exist
                        if !diagram.nodes.contains(where: { $0.id == src }) {
                            diagram.nodes.append(ArcmarkNode(id: src, label: src))
                        }
                        if !diagram.nodes.contains(where: { $0.id == tgt }) {
                            diagram.nodes.append(ArcmarkNode(id: tgt, label: tgt))
                        }
                        diagram.links.append(ArcmarkLink(source: src, target: tgt))
                    }
                }
            }
        }
        
        return diagram
    }
}
