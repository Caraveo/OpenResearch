import Foundation

public struct URPManifest: Codable, Equatable {
    public var urp: String = "0.1"
    public var paper: PaperInfo = PaperInfo()
    public var authors: [AuthorInfo] = []
    public var license: LicenseInfo = LicenseInfo()
    public var document: DocumentInfo = DocumentInfo()
    public var reproducibility: ReproducibilityInfo = ReproducibilityInfo()
    public var keywords: [String] = []
    public var revisionHistory: [RevisionInfo] = []
    public var funding: [FundingInfo] = []
    public var conflicts: ConflictInfo = ConflictInfo()
    
    public struct PaperInfo: Codable, Equatable {
        public var id: String = ""
        public var title: String = ""
        public var subtitle: String = ""
        public var type: String = "white-paper"
        public var language: String = "en-US"
        public var version: String = "1.0.0"
        public var created: String = ""
        public var updated: String = ""
        public var status: String = "draft"
    }
    
    public struct AuthorInfo: Codable, Equatable, Identifiable {
        public var id: String { name } // Simple unique identifier for UI
        public var authorId: String? = nil
        public var name: String = ""
        public var affiliation: String = ""
        public var roles: [String] = []
        public var orcid: String? = nil
        
        enum CodingKeys: String, CodingKey {
            case authorId = "id"
            case name
            case affiliation
            case roles
            case orcid
        }
    }
    
    public struct LicenseInfo: Codable, Equatable {
        public var text: String = "CC-BY-4.0"
        public var code: String = "MIT"
        public var data: String = "CC-BY-4.0"
    }
    
    public struct DocumentInfo: Codable, Equatable {
        public var source: String = "paper.rd"
        public var bibliography: String = ""
        public var citationStyle: String = "ieee"
        public var numberSections: Bool = true
        public var numberFigures: Bool = true
        public var numberEquations: Bool = true
        
        enum CodingKeys: String, CodingKey {
            case source
            case bibliography
            case citationStyle = "citation_style"
            case numberSections = "number_sections"
            case numberFigures = "number_figures"
            case numberEquations = "number_equations"
        }
    }
    
    public struct ReproducibilityInfo: Codable, Equatable {
        public var level: String = "0"
        public var environment: String = ""
        public var entrypoint: String = ""
        public var expectedRuntime: String = ""
        public var verifiedBy: [VerifierInfo]? = nil
        
        enum CodingKeys: String, CodingKey {
            case level
            case environment
            case entrypoint
            case expectedRuntime = "expected_runtime"
            case verifiedBy = "verified_by"
        }
    }
    
    public struct VerifierInfo: Codable, Equatable, Identifiable {
        public var id: String { name }
        public var name: String = ""
        public var date: String = ""
    }
    
    public struct RevisionInfo: Codable, Equatable, Identifiable {
        public var id: String { version + date }
        public var version: String = ""
        public var date: String = ""
        public var changes: [String] = []
    }
    
    public struct FundingInfo: Codable, Equatable, Identifiable {
        public var id: String { organization + (grant ?? "") }
        public var organization: String = ""
        public var grant: String? = nil
    }
    
    public struct ConflictInfo: Codable, Equatable {
        public var declared: Bool = false
        public var statement: String = ""
    }
}
