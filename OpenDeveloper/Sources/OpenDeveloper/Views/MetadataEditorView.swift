import SwiftUI

public struct MetadataEditorView: View {
    @Binding public var manifest: URPManifest
    
    @State private var newAuthorName = ""
    @State private var newAuthorAffiliation = ""
    @State private var newAuthorOrcid = ""
    @State private var newAuthorRole = ""
    
    public init(manifest: Binding<URPManifest>) {
        self._manifest = manifest
    }
    
    public var body: some View {
        Form {
            Section(header: Text("Paper Core Metadata").font(.headline)) {
                TextField("Identifier (ID)", text: $manifest.paper.id)
                TextField("Title", text: $manifest.paper.title)
                TextField("Subtitle", text: $manifest.paper.subtitle)
                
                Picker("Document Type", selection: $manifest.paper.type) {
                    Text("White Paper").tag("white-paper")
                    Text("Technical Paper").tag("technical-paper")
                    Text("Research Proposal").tag("research-proposal")
                    Text("Preprint").tag("preprint")
                }
                
                HStack {
                    TextField("Version", text: $manifest.paper.version)
                    Spacer()
                    Picker("Research Stage / Status", selection: $manifest.paper.status) {
                        Text("Concept").tag("concept")
                        Text("Proposal").tag("proposal")
                        Text("Experiment").tag("experiment")
                        Text("Draft").tag("draft")
                        Text("Preprint").tag("preprint")
                        Text("Reviewed").tag("reviewed")
                        Text("Replicated").tag("replicated")
                        Text("Production Validated").tag("production-validated")
                    }
                }
                
                HStack {
                    TextField("Created Date", text: $manifest.paper.created)
                    TextField("Updated Date", text: $manifest.paper.updated)
                    TextField("Language", text: $manifest.paper.language)
                }
            }
            .padding(.bottom, 10)
            
            Section(header: Text("Authors").font(.headline)) {
                ForEach(manifest.authors) { author in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(author.name)
                                .font(.body)
                                .fontWeight(.semibold)
                            if !author.affiliation.isEmpty {
                                Text(author.affiliation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let orcid = author.orcid, !orcid.isEmpty {
                                Text("ORCID: \(orcid)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(role: .destructive) {
                            manifest.authors.removeAll(where: { $0.id == author.id })
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add New Author")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        TextField("Name", text: $newAuthorName)
                        TextField("Affiliation", text: $newAuthorAffiliation)
                    }
                    HStack {
                        TextField("ORCID (Optional)", text: $newAuthorOrcid)
                        Button(action: addAuthor) {
                            Label("Add", systemImage: "plus")
                        }
                        .disabled(newAuthorName.isEmpty)
                    }
                }
                .padding(.top, 10)
            }
            .padding(.bottom, 10)
            
            Section(header: Text("Licenses").font(.headline)) {
                TextField("Text Content License", text: $manifest.license.text)
                TextField("Code License", text: $manifest.license.code)
                TextField("Data License", text: $manifest.license.data)
            }
            .padding(.bottom, 10)
            
            Section(header: Text("Reproducibility Specification").font(.headline)) {
                Picker("Reproducibility Level", selection: $manifest.reproducibility.level) {
                    Text("Level 0 — Descriptive").tag("0")
                    Text("Level 1 — Inspectable").tag("1")
                    Text("Level 2 — Executable").tag("2")
                    Text("Level 3 — Reproducible").tag("3")
                    Text("Level 4 — Independently Replicated").tag("4")
                }
                
                TextField("Environment File Path (e.g. Dockerfile)", text: $manifest.reproducibility.environment)
                TextField("Entrypoint Script Path (e.g. run.sh)", text: $manifest.reproducibility.entrypoint)
                TextField("Expected Runtime", text: $manifest.reproducibility.expectedRuntime)
            }
        }
        .formStyle(.grouped)
    }
    
    private func addAuthor() {
        let author = URPManifest.AuthorInfo(
            authorId: "author:\(newAuthorName.lowercased().replacingOccurrences(of: " ", with: "-"))",
            name: newAuthorName,
            affiliation: newAuthorAffiliation,
            roles: [],
            orcid: newAuthorOrcid.isEmpty ? nil : newAuthorOrcid
        )
        manifest.authors.append(author)
        newAuthorName = ""
        newAuthorAffiliation = ""
        newAuthorOrcid = ""
    }
}
