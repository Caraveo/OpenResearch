import Foundation

public enum URPSeverity: String, Codable {
    case error = "Error"
    case warning = "Warning"
}

public struct URPValidationIssue: Identifiable, Equatable {
    public var id: String { code + message }
    public var code: String
    public var message: String
    public var severity: URPSeverity
    public var location: String?
}

public struct URPValidator {
    public static func validate(_ document: URPDocument) -> [URPValidationIssue] {
        var issues: [URPValidationIssue] = []
        
        // URP001: Missing document title
        if document.manifest.paper.title.isEmpty {
            issues.append(URPValidationIssue(
                code: "URP001",
                message: "Missing document title in the manifest.",
                severity: .error,
                location: "Manifest"
            ))
        }
        
        // Check sections
        let sectionTitles = document.sections.map { $0.title.lowercased() }
        
        // URP002: Missing abstract
        if !sectionTitles.contains(where: { $0.contains("abstract") }) {
            issues.append(URPValidationIssue(
                code: "URP002",
                message: "Missing abstract section.",
                severity: .error,
                location: "Sections"
            ))
        }
        
        // Missing Problem Section (Required Minimal Section)
        if !sectionTitles.contains(where: { $0.contains("problem") || $0.contains("research question") || $0.contains("thesis") }) {
            issues.append(URPValidationIssue(
                code: "URP002-Problem",
                message: "Missing required 'Problem' or 'Research Question' section.",
                severity: .error,
                location: "Sections"
            ))
        }
        
        // Missing Methodology Section (Required Minimal Section)
        if !sectionTitles.contains(where: { $0.lowercased().contains("methodology") }) {
            issues.append(URPValidationIssue(
                code: "URP002-Methodology",
                message: "Missing required 'Methodology' section.",
                severity: .error,
                location: "Sections"
            ))
        }

        // Missing Architecture Section (Required Minimal Section)
        if !sectionTitles.contains(where: { $0.lowercased().contains("architecture") }) {
            issues.append(URPValidationIssue(
                code: "URP002-Architecture",
                message: "Missing required 'Architecture' section.",
                severity: .error,
                location: "Sections"
            ))
        }
        
        // Missing Conclusion Section (Required Minimal Section)
        if !sectionTitles.contains(where: { $0.contains("conclusion") }) {
            issues.append(URPValidationIssue(
                code: "URP002-Conclusion",
                message: "Missing required 'Conclusion' section.",
                severity: .error,
                location: "Sections"
            ))
        }
        
        // URP003: Missing references section
        if !sectionTitles.contains(where: { $0.contains("reference") }) {
            issues.append(URPValidationIssue(
                code: "URP003",
                message: "Missing references section.",
                severity: .warning,
                location: "Sections"
            ))
        }
        
        // URP014: Required limitation section missing
        if !sectionTitles.contains(where: { $0.contains("limitation") }) {
            issues.append(URPValidationIssue(
                code: "URP014",
                message: "Required limitation section is missing.",
                severity: .warning,
                location: "Sections"
            ))
        }
        
        // URP012: Unsupported URP version
        let version = document.manifest.urp
        if version != "0.1" {
            issues.append(URPValidationIssue(
                code: "URP012",
                message: "Unsupported URP version '\(version)'. Supported version is '0.1'.",
                severity: .warning,
                location: "Manifest"
            ))
        }
        
        // URP007: Duplicate identifier & URP008: Reference checks
        var ids: Set<String> = []
        for claim in document.claims {
            if !ids.insert(claim.id).inserted {
                issues.append(URPValidationIssue(
                    code: "URP007",
                    message: "Duplicate claim identifier: '\(claim.id)'.",
                    severity: .error,
                    location: "Claims (\(claim.id))"
                ))
            }
        }
        
        for eq in document.equations {
            if !ids.insert(eq.id).inserted {
                issues.append(URPValidationIssue(
                    code: "URP007",
                    message: "Duplicate equation identifier: '\(eq.id)'.",
                    severity: .error,
                    location: "Equations (\(eq.id))"
                ))
            }
        }
        
        for code in document.codeBlocks {
            if !ids.insert(code.id).inserted {
                issues.append(URPValidationIssue(
                    code: "URP007",
                    message: "Duplicate code block identifier: '\(code.id)'.",
                    severity: .error,
                    location: "Code Blocks (\(code.id))"
                ))
            }
        }
        
        // URP008: Formula referenced but not defined
        let refPattern = "@eq-(\\w+)"
        let refRegex = try? NSRegularExpression(pattern: refPattern, options: [])
        let nsString = document.rawContent as NSString
        let matches = refRegex?.matches(in: document.rawContent, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for match in matches {
            let eqId = nsString.substring(with: match.range(at: 1))
            if !document.equations.contains(where: { $0.id == eqId }) {
                issues.append(URPValidationIssue(
                    code: "URP008",
                    message: "Equation reference '@eq-\(eqId)' is not defined.",
                    severity: .warning,
                    location: "Markdown text"
                ))
            }
        }
        
        // URP009: Executable code missing environment
        for code in document.codeBlocks {
            if code.executable && code.environment.isEmpty {
                issues.append(URPValidationIssue(
                    code: "URP009",
                    message: "Executable code block '\(code.id)' does not specify an environment.",
                    severity: .warning,
                    location: "Code Block (\(code.id))"
                ))
            }
        }
        
        // URP006: Image missing alt text
        let imgPattern = "!\\[\\]\\((.*?)\\)"
        let imgRegex = try? NSRegularExpression(pattern: imgPattern, options: [])
        let imgMatches = imgRegex?.matches(in: document.rawContent, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        if !imgMatches.isEmpty {
            issues.append(URPValidationIssue(
                code: "URP006",
                message: "One or more images are missing alt text descriptions.",
                severity: .warning,
                location: "Images"
            ))
        }
        
        // URP016: Media format validation (Accessibility and Standard Conformance)
        let mediaPattern = "\\((.*?\\.(?:mov|gif|mp3|tiff|bmp|wmv|avi|ogg))\\)"
        let mediaRegex = try? NSRegularExpression(pattern: mediaPattern, options: [.caseInsensitive])
        let mediaMatches = mediaRegex?.matches(in: document.rawContent, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        for match in mediaMatches {
            let path = nsString.substring(with: match.range(at: 1))
            issues.append(URPValidationIssue(
                code: "URP016",
                message: "Unsupported media format in path '\(path)'. Conforming extensions are: .svg, .png, .webp, .jpeg, .webm, .mp4, .flac, .wav, .opus.",
                severity: .warning,
                location: "Media asset references"
            ))
        }
        
        // URP017: Heading level hierarchy check (Accessibility Guideline)
        var lastLevel = 0
        for section in document.sections {
            let level = section.level
            if level > lastLevel + 1 && lastLevel > 0 {
                issues.append(URPValidationIssue(
                    code: "URP017",
                    message: "Skipped heading level: from level \(lastLevel) directly to level \(level) in section '\(section.title)'.",
                    severity: .warning,
                    location: "Heading Hierarchy (\(section.title))"
                ))
            }
            lastLevel = level
        }
        
        // URP018: Image size limits (Accessibility and Portability check)
        let imgPattern2 = "!\\[.*?\\]\\((.*?\\.(?:png|jpg|jpeg|webp|svg))\\)"
        let imgRegex2 = try? NSRegularExpression(pattern: imgPattern2, options: [.caseInsensitive])
        let imgMatches2 = imgRegex2?.matches(in: document.rawContent, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        for match in imgMatches2 {
            let imgPath = nsString.substring(with: match.range(at: 1))
            issues.append(URPValidationIssue(
                code: "URP018",
                message: "Image '\(imgPath)' will be compressed using high-quality (85%) targets when packaged. Ensure source file is under the 5MB portability limit.",
                severity: .warning,
                location: "Image Optimization"
            ))
        }
        
        return issues
    }
}
