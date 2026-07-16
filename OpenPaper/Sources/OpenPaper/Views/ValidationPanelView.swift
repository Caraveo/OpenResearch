import SwiftUI

public struct ValidationPanelView: View {
    public var issues: [URPValidationIssue]
    
    public init(issues: [URPValidationIssue]) {
        self.issues = issues
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Validation Status")
                    .font(.headline)
                Spacer()
                if issues.isEmpty {
                    Label("Conforms to Standard", systemImage: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                } else {
                    let errors = issues.filter { $0.severity == .error }.count
                    let warnings = issues.filter { $0.severity == .warning }.count
                    
                    HStack(spacing: 8) {
                        if errors > 0 {
                            Label("\(errors) Errors", systemImage: "exclamationmark.octagon.fill")
                                .foregroundStyle(.red)
                        }
                        if warnings > 0 {
                            Label("\(warnings) Warnings", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            
            Divider()
            
            if issues.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("No validation issues found.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("This document fully conforms to URP 0.1 spec.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(issues) { issue in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: issue.severity == .error ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(issue.severity == .error ? Color.red : Color.orange)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(issue.code)
                                        .font(.system(.caption, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundStyle(.secondary)
                                    
                                    if let loc = issue.location {
                                        Text("•  \(loc)")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                
                                Text(issue.message)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
