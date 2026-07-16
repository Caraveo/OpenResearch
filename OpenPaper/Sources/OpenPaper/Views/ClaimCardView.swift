import SwiftUI

public struct ClaimCardView: View {
    public var claim: URPClaim
    
    public init(claim: URPClaim) {
        self.claim = claim
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(claim.id)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(claim.type.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(typeColor.opacity(0.15))
                    .foregroundStyle(typeColor)
                    .clipShape(Capsule())
                
                if !claim.confidence.isEmpty {
                    Text(claim.confidence)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }
            }
            
            Text(claim.body)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(4)
            
            if !claim.sources.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.caption2)
                    Text("Sources: \(claim.sources)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(typeColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var typeColor: Color {
        switch claim.type.lowercased() {
        case "empirical": return .green
        case "theoretical": return .blue
        case "derived": return .teal
        case "observational": return .indigo
        case "speculative": return .orange
        case "normative": return .pink
        case "design": return .purple
        default: return .secondary
        }
    }
}
