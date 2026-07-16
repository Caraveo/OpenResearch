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
                location: "Title Page"
            ))
        }
        
        // URP002: Missing abstract
        if document.abstract.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(URPValidationIssue(
                code: "URP002",
                message: "Missing abstract content.",
                severity: .error,
                location: "Abstract"
            ))
        }
        
        // URP002-Problem: Missing problem
        if document.problem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(URPValidationIssue(
                code: "URP002-Problem",
                message: "Missing required 'Problem' section content.",
                severity: .error,
                location: "Problem"
            ))
        }
        
        // URP002-Methodology: Missing methodology
        if document.methodology.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(URPValidationIssue(
                code: "URP002-Methodology",
                message: "Missing required 'Methodology' section content.",
                severity: .error,
                location: "Methodology"
            ))
        }

        // URP002-Architecture: Missing architecture
        if document.architecture.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(URPValidationIssue(
                code: "URP002-Architecture",
                message: "Missing required 'Architecture' section content.",
                severity: .error,
                location: "Architecture"
            ))
        }
        
        // URP002-Conclusion: Missing conclusion
        if document.conclusion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(URPValidationIssue(
                code: "URP002-Conclusion",
                message: "Missing required 'Conclusion' section content.",
                severity: .error,
                location: "Conclusion"
            ))
        }
        
        // URP003: Missing references section
        if document.references.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(URPValidationIssue(
                code: "URP003",
                message: "Missing references content.",
                severity: .warning,
                location: "References"
            ))
        }
        
        // URP014: Required limitation section missing
        if document.limitations.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(URPValidationIssue(
                code: "URP014",
                message: "Required limitation section is missing content.",
                severity: .warning,
                location: "Limitations"
            ))
        }
        
        // URP016: Media format validation
        let allContent = document.abstract + " " + document.problem + " " + document.methodology + " " + document.limitations + " " + document.conclusion + " " + document.references
        let mediaPattern = "\\((.*?\\.(?:mov|gif|mp3|tiff|bmp|wmv|avi|ogg))\\)"
        let mediaRegex = try? NSRegularExpression(pattern: mediaPattern, options: [.caseInsensitive])
        let nsString = allContent as NSString
        let mediaMatches = mediaRegex?.matches(in: allContent, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        for match in mediaMatches {
            let path = nsString.substring(with: match.range(at: 1))
            issues.append(URPValidationIssue(
                code: "URP016",
                message: "Unsupported media format in path '\(path)'. Conforming extensions are: .svg, .png, .webp, .jpeg, .webm, .mp4, .flac, .wav, .opus.",
                severity: .warning,
                location: "Media asset references"
            ))
        }
        
        // URP018: Image compression and size limits (Accessibility and Portability check)
        // Set maximum individual image file size at 5MB, recommending high quality compression (85% JPEG or WebP)
        let imgPattern = "!\\[.*?\\]\\((.*?\\.(?:png|jpg|jpeg|webp|svg))\\)"
        let imgRegex = try? NSRegularExpression(pattern: imgPattern, options: [.caseInsensitive])
        let imgMatches = imgRegex?.matches(in: allContent, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        for match in imgMatches {
            let imgPath = nsString.substring(with: match.range(at: 1))
            // Simulating image size check in editor (we check if file exists and its size, or recommend optimization)
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
