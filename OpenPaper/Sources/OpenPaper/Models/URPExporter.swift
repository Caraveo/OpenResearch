import Foundation
import AppKit
import PDFKit
#if canImport(WebKit)
import WebKit
#endif
import UniformTypeIdentifiers

public enum URPExportFormat: String, CaseIterable {
    case html, pdf, latex, markdown, epub, docx
    case tex // alias for latex
    case md  // alias for markdown
    case doc // alias for docx (Word-compatible)

    public var displayName: String {
        switch self {
        case .html: return "HTML Page (.html)"
        case .pdf: return "PDF Document (.pdf)"
        case .latex, .tex: return "LaTeX Source (.tex)"
        case .markdown, .md: return "Markdown (.md)"
        case .epub: return "EPUB Ebook (.epub)"
        case .docx, .doc: return "Word Document (.docx)"
        }
    }

    public var fileExtension: String {
        switch self {
        case .html: return "html"
        case .pdf: return "pdf"
        case .latex, .tex: return "tex"
        case .markdown, .md: return "md"
        case .epub: return "epub"
        case .docx, .doc: return "docx"
        }
    }

    public var utType: UTType? {
        switch self {
        case .html: return .html
        case .pdf: return .pdf
        case .latex, .tex: return UTType(filenameExtension: "tex")
        case .markdown, .md: return UTType(filenameExtension: "md")
        case .epub: return UTType(filenameExtension: "epub")
        case .docx, .doc: return UTType(filenameExtension: "docx")
        }
    }
}

public struct URPExporter {

    // MARK: - HTML ------------------------------------------------------------

    public static func generateHTML(for doc: URPDocument) -> String {
        var html = """
        <!DOCTYPE html>
        <html lang="\(escAttr(doc.manifest.paper.language))">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escContent(doc.manifest.paper.title.isEmpty ? "Untitled Research Paper" : doc.manifest.paper.title))</title>
        <style>
          :root { --ink:#1a1a1a; --muted:#6b6b6b; --rule:#d8d4cc; --paper:#fefcf7; --accent:#a8541f; --card:#f5efe4; }
          * { box-sizing: border-box; }
          html, body { margin:0; padding:0; }
          body {
            background: var(--paper); color: var(--ink);
            font-family: "Iowan Old Style","Palatino Linotype","Book Antiqua",Georgia,"Times New Roman",serif;
            line-height: 1.7; font-size: 17px;
            -webkit-font-smoothing: antialiased;
          }
          main { max-width: 760px; margin: 0 auto; padding: 72px 48px 120px; }
          h1.title { font-size: 38px; line-height:1.15; margin: 0 0 6px; letter-spacing:-0.01em; }
          p.subtitle { font-size: 22px; color: var(--muted); margin: 0 0 28px; font-style: italic; }
          .meta { display:flex; flex-wrap:wrap; gap: 8px 28px; color: var(--muted); font-size: 14px; margin-bottom: 10px; }
          .meta .author { font-weight: 600; color: var(--ink); }
          .license { color: var(--muted); font-size: 13px; margin: 14px 0 40px; }
          .badges { display:flex; gap: 10px; align-items: center; margin: 18px 0 40px; }
          .badge { font-family: ui-rounded,"SF Pro Rounded",system-ui,sans-serif; font-size: 11px; font-weight: 700; letter-spacing: .04em; text-transform: uppercase; padding: 3px 9px; border-radius: 999px; background: rgba(168,84,31,0.12); color: var(--accent); }
          hr { border: 0; border-top: 1px solid var(--rule); margin: 44px 0; }
          h2 { font-size: 26px; margin: 44px 0 14px; letter-spacing:-0.01em; }
          h3 { font-size: 19px; margin: 28px 0 10px; }
          p { margin: 0 0 14px; }
          a { color: var(--accent); }
          blockquote { margin: 16px 0; padding: 12px 18px; border-left: 3px solid var(--accent); background: var(--card); color: #333; }
          table { border-collapse: collapse; width: 100%; margin: 16px 0; font-size: 15px; }
          th, td { border-bottom: 1px solid var(--rule); padding: 8px 10px; text-align: left; }
          th { background: rgba(0,0,0,0.03); font-style: italic; }
          .eq { text-align: center; font-size: 20px; margin: 22px auto; padding: 18px; background: rgba(0,0,0,0.03); border-radius: 10px; }
          .eq .caption { display:block; font-size: 13px; color: var(--muted); margin-top: 8px; font-family: ui-monospace,monospace; }
          .vars { font-size: 14px; color: var(--muted); border-top: 1px dashed var(--rule); padding-top: 10px; margin-top: 10px; }
          .vars .row { display: grid; grid-template-columns: 90px 1fr; gap: 10px; padding: 2px 0; }
          .vars .sym { font-family: ui-monospace,monospace; font-weight: 700; }
          .card { border: 1px solid var(--rule); border-radius: 14px; padding: 18px 20px; margin: 18px 0; background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,0.04); }
          .card .head { display:flex; justify-content: space-between; align-items: center; gap: 12px; margin-bottom: 10px; }
          .card .id { font-family: ui-monospace,monospace; font-size: 12px; color: var(--muted); font-weight: 700; }
          .pill { font-family: ui-rounded,system-ui,sans-serif; font-size: 11px; font-weight: 700; padding: 2px 8px; border-radius: 999px; }
          .pill.empirical { background: rgba(48,164,108,0.15); color: #15895d; }
          .pill.theoretical { background: rgba(38,108,234,0.15); color: #1e5fd1; }
          .pill.design { background: rgba(122,89,255,0.15); color: #6a4ad6; }
          .pill.speculative { background: rgba(220,120,10,0.15); color: #c05e05; }
          .pill.generic { background: rgba(0,0,0,0.08); color: var(--muted); }
          .pill.confidence { background: rgba(0,0,0,0.06); color: var(--muted); }
          .card .src { color: var(--muted); font-size: 13px; margin-top: 8px; }
          pre { background: #1e1e1e; color: #f1f1f1; padding: 14px 16px; border-radius: 10px; overflow-x: auto; font-family: ui-monospace,Menlo,monospace; font-size: 13px; line-height: 1.5; }
          pre.arcmark { background: #faf6ee; color: #333; border: 1px solid var(--rule); }
          .figure { text-align: center; margin: 18px 0; }
          .figure .pl { background: var(--card); border: 1px dashed var(--rule); border-radius: 10px; padding: 40px; color: var(--muted); }
          .figure figcaption { font-size: 13px; color: var(--muted); margin-top: 8px; font-style: italic; }
          .toc { background: rgba(0,0,0,0.02); border-radius: 10px; padding: 16px 22px; margin: 30px 0; }
          .toc h2 { margin: 0 0 8px; font-size: 18px; }
          .toc ol { margin: 0; padding-left: 20px; }
          .toc li { margin: 4px 0; }
          @media print { body { background: #fff; } main { max-width: none; padding: 24px; } .card, .card * { break-inside: avoid; } }
        </style>
        <script>
          window.MathJax = { tex: { inlineMath: [['$','$'],['\\\\(','\\\\)']], displayMath: [['$$','$$'],['\\\\[','\\\\]']] }, svg: { fontCache: 'global' } };
        </script>
        <script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-svg.js" async></script>
        </head>
        <body>
        <main>
        """

        // Title block
        html += "<h1 class=\"title\">\(escContent(doc.manifest.paper.title.isEmpty ? "Untitled Research Paper" : doc.manifest.paper.title))</h1>\n"
        if !doc.manifest.paper.subtitle.isEmpty {
            html += "<p class=\"subtitle\">\(escContent(doc.manifest.paper.subtitle))</p>\n"
        }
        if !doc.manifest.authors.isEmpty {
            html += "<div class=\"meta\">"
            for a in doc.manifest.authors {
                html += "<div><span class=\"author\">\(escContent(a.name))</span>"
                if !a.affiliation.isEmpty { html += " · \(escContent(a.affiliation))" }
                if let orcid = a.orcid, !orcid.isEmpty { html += "<br><span style=\"font-family:ui-monospace,monospace;font-size:11px;color:var(--muted);\">\(escContent(orcid))</span>" }
                html += "</div>"
            }
            html += "</div>\n"
        }
        html += "<div class=\"badges\">"
        if !doc.manifest.paper.status.isEmpty {
            html += "<span class=\"badge\">\(escContent(doc.manifest.paper.status.uppercased()))</span>"
        }
        html += "<span class=\"badge\">URP \(escContent(doc.manifest.urp))</span>"
        html += "<span class=\"badge\">v\(escContent(doc.manifest.paper.version))</span>"
        html += "</div>\n"
        html += "<div class=\"license\">License: \(escContent(doc.manifest.license.text)) · Code: \(escContent(doc.manifest.license.code)) · Data: \(escContent(doc.manifest.license.data))</div>\n<hr>\n"

        // Table of contents
        if !doc.sections.isEmpty {
            html += "<nav class=\"toc\"><h2>Table of Contents</h2><ol>"
            for s in doc.sections where s.level <= 2 {
                let slug = slugify(s.title)
                html += "<li><a href=\"#\(slug)\">\(escContent(s.title))</a></li>"
            }
            html += "</ol></nav>\n"
        }

        // Sections
        for section in doc.sections {
            let slug = slugify(section.title)
            let tag = section.level == 1 ? "h2" : "h3"
            html += "<\(tag) id=\"\(slug)\">\(escContent(section.title.isEmpty ? "Introduction" : section.title))</\(tag)>\n"
            html += htmlBlocksFor(section.body, in: doc)
        }

        html += "\n</main>\n</body>\n</html>\n"
        return html
    }

    // MARK: - Word (.docx via Word-compatible HTML) --------------------------

    /// A Word-compatible HTML document saved with a `.docx`/`.doc` extension that opens
    /// cleanly in Microsoft Word, Pages, and LibreOffice. Uses Word's HTML import quirks
    /// (XHTML with Word mso namespace pointers) so styled content round-trips reasonably.
    public static func generateWord(for doc: URPDocument) -> String {
        var body = ""

        body += "<h1 style=\"font-size:30pt;font-family:'Times New Roman',serif;margin-bottom:4pt;\">"
        body += escContent(doc.manifest.paper.title.isEmpty ? "Untitled Research Paper" : doc.manifest.paper.title)
        body += "</h1>\n"
        if !doc.manifest.paper.subtitle.isEmpty {
            body += "<p style=\"font-size:16pt;font-style:italic;color:#555555;font-family:'Times New Roman',serif;margin-top:0;\">\(escContent(doc.manifest.paper.subtitle))</p>\n"
        }
        for a in doc.manifest.authors {
            body += "<p style=\"font-size:12pt;font-family:'Times New Roman',serif;margin:2pt 0;\"><b>\(escContent(a.name))</b>"
            if !a.affiliation.isEmpty { body += " — <i>\(escContent(a.affiliation))</i>" }
            if let orcid = a.orcid, !orcid.isEmpty { body += " (ORCID: \(escContent(orcid)))" }
            body += "</p>\n"
        }
        body += "<p style=\"font-size:9pt;color:#777777;font-family:'Times New Roman',serif;\">"
        body += "Status: \(escContent(doc.manifest.paper.status.uppercased())) &nbsp;·&nbsp; Spec: URP \(escContent(doc.manifest.urp)) &nbsp;·&nbsp; License: \(escContent(doc.manifest.license.text))</p>\n"
        body += "<hr style=\"border:0;border-top:1px solid #cccccc;\">\n"

        for section in doc.sections {
            let size = section.level == 1 ? "16pt" : "13pt"
            body += "<h2 style=\"font-size:\(size);font-family:'Times New Roman',serif;margin-top:18pt;\">\(escContent(section.title.isEmpty ? "Introduction" : section.title))</h2>\n"
            body += htmlBlocksFor(section.body, in: doc, wordFriendly: true)
        }

        let html = """
        <html xmlns:o="urn:schemas-microsoft-com:office:office"
              xmlns:w="urn:schemas-microsoft-com:office:word"
              xmlns="http://www.w3.org/TR/REC-html40">
        <head>
        <meta charset="utf-8">
        <title>\(escContent(doc.manifest.paper.title))</title>
        <!--[if gte mso 9]><xml>
          <w:WordDocument><w:View>Print</w:View><w:Zoom>100</w:Zoom><w:DoNotOptimizeForBrowser/></w:WordDocument>
        </xml><![endif]-->
        <style>
          @page Section1 { size: 8.5in 11.0in; margin: 1.0in 1.0in 1.0in 1.0in; }
          div.Section1 { page: Section1; }
          body { font-family: 'Times New Roman', serif; font-size: 12pt; line-height: 1.5; color: #1a1a1a; }
          table { border-collapse: collapse; width: 100%; margin: 10pt 0; }
          td, th { border: 1px solid #999999; padding: 4pt 6pt; }
          th { background: #eeeeee; }
          pre { font-family: 'Courier New', monospace; font-size: 10pt; background: #f4f1ea; padding: 8pt; border: 1px solid #ddd; }
          blockquote { border-left: 3px solid #a8541f; margin: 10pt 0; padding: 6pt 12pt; background: #f7f2e8; color: #333; }
        </style>
        </head>
        <body>
        <div class="Section1">
        \(body)
        </div>
        </body>
        </html>
        """
        return html
    }

    // MARK: - LaTeX -----------------------------------------------------------

    public static func generateLaTeX(for doc: URPDocument) -> String {
        var tex = """
        \\documentclass[11pt,a4paper]{article}
        \\usepackage[utf8]{inputenc}
        \\usepackage[T1]{fontenc}
        \\usepackage{lmodern}
        \\usepackage[margin=1in]{geometry}
        \\usepackage{amsmath,amssymb}
        \\usepackage{graphicx}
        \\usepackage{hyperref}
        \\usepackage{listings}
        \\usepackage{xcolor}
        \\usepackage{enumitem}
        \\usepackage{booktabs}
        \\usepackage{array}

        \\lstset{basicstyle=\\ttfamily\\small, breaklines=true, frame=single, framerule=0.4pt, backgroundcolor=\\color{gray!8}, columns=fullflexible, keepspaces=true}

        \\title{\(escLatex(doc.manifest.paper.title.isEmpty ? "Untitled Research Paper" : doc.manifest.paper.title))}
        \\author{\(doc.manifest.authors.map { "\\(escLatex($0.name)) \(affilLatex($0))" }.joined(separator: " \\and "))}
        \\date{\\today}

        \\begin{document}
        \\maketitle

        """
        if !doc.manifest.paper.subtitle.isEmpty {
            tex += "\\begin{abstract}\n\(escLatex(doc.manifest.paper.subtitle))\n\\end{abstract}\n\n"
        }

        for section in doc.sections {
            let cmd = section.level == 1 ? "section" : "subsection"
            tex += "\\\(cmd){\(escLatex(section.title.isEmpty ? "Introduction" : section.title))}\n"
            tex += latexBlocksFor(section.body, in: doc)
            tex += "\n"
        }

        tex += "\n\\end{document}\n"
        return tex
    }

    // MARK: - Markdown --------------------------------------------------------

    public static func generateMarkdown(for doc: URPDocument) -> String {
        var md = ""

        md += "# \(doc.manifest.paper.title.isEmpty ? "Untitled Research Paper" : doc.manifest.paper.title)\n\n"
        if !doc.manifest.paper.subtitle.isEmpty {
            md += "*\(doc.manifest.paper.subtitle)*\n\n"
        }
        for a in doc.manifest.authors {
            md += "**\(a.name)**"
            if !a.affiliation.isEmpty { md += " · \(a.affiliation)" }
            if let orcid = a.orcid, !orcid.isEmpty { md += " · [\(orcid)](https://orcid.org/\(orcid))" }
            md += "  \n"
        }
        md += "\n"
        md += "`status: \(doc.manifest.paper.status.uppercased())` · `URP \(doc.manifest.urp)` · `license: \(doc.manifest.license.text)`\n\n---\n\n"

        if !doc.sections.isEmpty {
            md += "## Table of Contents\n\n"
            for s in doc.sections where s.level <= 2 {
                let indent = s.level == 1 ? "" : "  "
                md += "\(indent)- \(s.title.isEmpty ? "Introduction" : s.title)\n"
            }
            md += "\n"
        }

        for section in doc.sections {
            let hashes = String(repeating: "#", count: min(max(section.level, 1) + 1, 6))
            md += "\(hashes) \(section.title.isEmpty ? "Introduction" : section.title)\n\n"
            md += markdownBlocksFor(section.body, in: doc)
            md += "\n"
        }

        return md
    }

    // MARK: - EPUB ------------------------------------------------------------

    public static func generateEPUB(for doc: URPDocument) throws -> Data {
        let fm = FileManager.default
        let workDir = fm.temporaryDirectory.appendingPathComponent("urp-epub-\(UUID().uuidString)")
        try fm.createDirectory(at: workDir, withIntermediateDirectories: true)

        defer { try? fm.removeItem(at: workDir) }

        // mimetype (stored, uncompressed)
        try "application/epub+zip".write(
            to: workDir.appendingPathComponent("mimetype"),
            atomically: true, encoding: .utf8)

        let metaInf = workDir.appendingPathComponent("META-INF")
        try fm.createDirectory(at: metaInf, withIntermediateDirectories: true)
        let container = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        try container.write(to: metaInf.appendingPathComponent("container.xml"), atomically: true, encoding: .utf8)

        let oebps = workDir.appendingPathComponent("OEBPS")
        try fm.createDirectory(at: oebps, withIntermediateDirectories: true)

        let paperXhtml = epubXHTML(for: doc)
        try paperXhtml.write(to: oebps.appendingPathComponent("paper.xhtml"), atomically: true, encoding: .utf8)

        try epubCSS.write(to: oebps.appendingPathComponent("style.css"), atomically: true, encoding: .utf8)

        let navXhtml = epubNav(for: doc)
        try navXhtml.write(to: oebps.appendingPathComponent("nav.xhtml"), atomically: true, encoding: .utf8)

        let contentOpf = epubOPF(for: doc)
        try contentOpf.write(to: oebps.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)

        // Zip into a Data buffer.
        let tempZip = fm.temporaryDirectory.appendingPathComponent("urp-\(UUID().uuidString).epub")
        if fm.fileExists(atPath: tempZip.path) { try fm.removeItem(at: tempZip) }
        guard ZipHelper.zipEpub(directoryPath: workDir.path, to: tempZip.path) else {
            throw NSError(domain: "URPExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to pack EPUB archive."])
        }
        let data = try Data(contentsOf: tempZip)
        try? fm.removeItem(at: tempZip)
        return data
    }

    private static let epubCSS: String = """
    body { font-family: "Iowan Old Style","Palatino Linotype","Book Antiqua",Georgia,serif; line-height: 1.7; margin: 5%; color: #1a1a1a; }
    h1 { font-size: 1.8em; line-height: 1.2; }
    h2 { font-size: 1.35em; margin-top: 1.5em; }
    h3 { font-size: 1.12em; margin-top: 1.2em; }
    .subtitle { color: #555; font-style: italic; }
    .meta { font-size: 0.9em; color: #555; }
    .badge { font-size: 0.7em; font-weight: bold; letter-spacing: 0.04em; text-transform: uppercase; color: #a8541f; }
    blockquote { border-left: 3px solid #a8541f; padding: 0.4em 0.8em; margin: 0.8em 0; background: #f5efe4; color: #333; }
    pre { font-family: monospace; font-size: 0.82em; background: #f4f1ea; padding: 0.6em; white-space: pre-wrap; }
    .eq { text-align: center; margin: 1em 0; }
    .card { border: 1px solid #d8d4cc; border-radius: 8px; padding: 0.8em 1em; margin: 0.8em 0; background: #fff; }
    .pill { font-size: 0.65em; font-weight: bold; padding: 0.1em 0.5em; border-radius: 999px; background: rgba(0,0,0,0.08); color: #555; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #bbb; padding: 0.3em 0.5em; }
    """

    private static func epubXHTML(for doc: URPDocument) -> String {
        var body = ""
        body += "<h1>\(escContent(doc.manifest.paper.title.isEmpty ? "Untitled Research Paper" : doc.manifest.paper.title))</h1>\n"
        if !doc.manifest.paper.subtitle.isEmpty { body += "<p class=\"subtitle\">\(escContent(doc.manifest.paper.subtitle))</p>\n" }
        body += "<div class=\"meta\">"
        for a in doc.manifest.authors {
            body += "<p><b>\(escContent(a.name))</b>"
            if !a.affiliation.isEmpty { body += " — \(escContent(a.affiliation))" }
            body += "</p>"
        }
        body += "<p class=\"badge\">\(escContent(doc.manifest.paper.status.uppercased())) · URP \(escContent(doc.manifest.urp)) · License: \(escContent(doc.manifest.license.text))</p>"
        body += "</div>\n"

        for section in doc.sections {
            let tag = section.level == 1 ? "h2" : "h3"
            body += "<\(tag) id=\"\(slugify(section.title))\">\(escContent(section.title.isEmpty ? "Introduction" : section.title))</\(tag)>\n"
            body += epubBlocksFor(section.body, in: doc)
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="\(escAttr(doc.manifest.paper.language))">
        <head><meta charset="utf-8"/><title>\(escContent(doc.manifest.paper.title))</title><link rel="stylesheet" type="text/css" href="style.css"/></head>
        <body>\(body)</body>
        </html>
        """
    }

    private static func epubNav(for doc: URPDocument) -> String {
        var items = ""
        if doc.sections.isEmpty {
            items = "<li><a href=\"paper.xhtml\">Full Paper</a></li>"
        } else {
            for s in doc.sections where s.level <= 2 {
                let indent = s.level == 1 ? "" : "  "
                items += "\(indent)<li><a href=\"paper.xhtml#\(slugify(s.title))\">\(escContent(s.title.isEmpty ? "Introduction" : s.title))</a></li>\n"
            }
        }
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="en">
        <head><meta charset="utf-8"/><title>Contents</title><link rel="stylesheet" type="text/css" href="style.css"/></head>
        <body>
        <nav epub:type="toc"><h1>Table of Contents</h1><ol>\(items)</ol></nav>
        </body>
        </html>
        """
    }

    private static func epubOPF(for doc: URPDocument) -> String {
        let uid = doc.manifest.paper.id.isEmpty ? "urn:urp:\(UUID().uuidString)" : escAttr(doc.manifest.paper.id)
        let title = escContent(doc.manifest.paper.title.isEmpty ? "Untitled Research Paper" : doc.manifest.paper.title)
        let authorsXml = doc.manifest.authors.map { "<dc:creator id=\"author-\(escAttr($0.name))\">\(escContent($0.name))</dc:creator>" }.joined(separator: "\n    ")

        let manifest = """
        <item id="css" href="style.css" media-type="text/css"/>
        <item id="paper" href="paper.xhtml" media-type="application/xhtml+xml"/>
        <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
        """

        let spine = """
        <itemref idref="paper" linear="yes"/>
        """

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid" xml:lang="\(escAttr(doc.manifest.paper.language))">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="bookid">\(uid)</dc:identifier>
            <dc:title>\(title)</dc:title>
            <dc:language>\(escContent(doc.manifest.paper.language))</dc:language>
            <dc:date>\(currentDate(iso8601: true))</dc:date>
            <dc:rights>License: \(escContent(doc.manifest.license.text))</dc:rights>
            \(authorsXml)
          </metadata>
          <manifest>\(manifest)</manifest>
          <spine>\(spine)</spine>
        </package>
        """
    }

    // MARK: - Per-format body block rendering ----------------------------

    private static func htmlBlocksFor(_ text: String, in doc: URPDocument, wordFriendly: Bool = false) -> String {
        var out = ""
        for block in linearize(text, in: doc) {
            switch block {
            case .paragraph(let p):
                out += "<p>\(inlineMarkdownToHtml(p))</p>\n"
            case .image(let alt, let path):
                if wordFriendly {
                    out += "<div class=\"figure\" style=\"text-align:center;margin:10pt 0;\"><div style=\"border:1px dashed #ccc;padding:24pt;background:#f5efe4;color:#888;font-family:sans-serif;\">[Image: \(escContent(path))]</div><div style=\"font-size:10pt;color:#666;font-style:italic;margin-top:4pt;\">\(escContent(alt))</div></div>\n"
                } else {
                    out += "<figure class=\"figure\"><div class=\"pl\">[Image not bundled: \(escContent(path))]</div><figcaption>\(escContent(alt))</figcaption></figure>\n"
                }
            case .table(let headers, let rows):
                out += "<table><thead><tr>"
                for h in headers { out += "<th>\(escContent(h))</th>" }
                out += "</tr></thead><tbody>"
                for r in rows {
                    out += "<tr>"
                    for c in r { out += "<td>\(escContent(c))</td>" }
                    out += "</tr>"
                }
                out += "</tbody></table>\n"
            case .equation(let eq):
                out += "<div class=\"eq\">\n$$\(eq.math)$$\n<span class=\"caption\">\(escContent(eq.title)) · (\(escContent(eq.id)))</span>"
                if let vb = doc.variablesBlocks.first(where: { $0.forEquation == eq.id }), !vb.variables.isEmpty {
                    out += "<div class=\"vars\">"
                    for v in vb.variables {
                        out += "<div class=\"row\"><span class=\"sym\">\(escContent(v.symbol))</span><span>— \(escContent(v.definition))</span></div>"
                    }
                    out += "</div>"
                }
                out += "</div>\n"
            case .claim(let c):
                let typeClass = typeClassFor(c.type)
                out += "<div class=\"card\"><div class=\"head\"><span class=\"id\">\(escContent(c.id))</span><span>"
                out += "<span class=\"pill \(typeClass)\">\(escContent(c.type.uppercased()))</span> "
                out += "<span class=\"pill confidence\">\(escContent(c.confidence))</span>"
                out += "</span></div>\n"
                out += "<p>\(escContent(c.body))</p>\n"
                if !c.sources.isEmpty { out += "<div class=\"src\">Sources: \(escContent(c.sources))</div>\n" }
                out += "</div>\n"
            case .code(let code):
                let cls = code.language.lowercased() == "arcmark" ? "arcmark" : ""
                out += "<pre class=\"\(cls)\"><code>\(escContent(code.code))</code></pre>\n"
                out += "<p style=\"font-size:12px;color:var(--muted);\">\(escContent(code.title)) · (\(escContent(code.id)))</p>\n"
            }
        }
        return out
    }

    private static func latexBlocksFor(_ text: String, in doc: URPDocument) -> String {
        var out = ""
        for block in linearize(text, in: doc) {
            switch block {
            case .paragraph(let p):
                out += "\(escLatex(p))\n\n"
            case .image(let alt, let path):
                out += "\\begin{figure}[h]\n\\centering\n\\fbox{\\parbox{0.7\\linewidth}{\\centering [Image: \(escLatex(path))]}}\n\\caption{\(escLatex(alt))}\n\\end{figure}\n\n"
            case .table(let headers, let rows):
                out += "\\begin{center}\n\\begin{tabular}{ \(String(repeating: "l ", count: headers.count))}\n\\toprule\n"
                out += headers.map { escLatex($0) }.joined(separator: " & ") + " \\\\\n\\midrule\n"
                for r in rows {
                    out += r.map { escLatex($0) }.joined(separator: " & ") + " \\\\\n"
                }
                out += "\\bottomrule\n\\end{tabular}\n\\end{center}\n\n"
            case .equation(let eq):
                out += "\\begin{equation}\n\(eq.math)\n\\label{eq:\(escLatex(eq.id))}\n\\end{equation}\n"
                out += "\\textit{\(escLatex(eq.title))} \\\\\n\n"
            case .claim(let c):
                out += "\\begin{quote}\n\\textbf{Claim \(escLatex(c.id))} (\\textit{\(escLatex(c.type))}, \(escLatex(c.confidence))): \(escLatex(c.body))"
                if !c.sources.isEmpty { out += " \\\\ \\textit{Sources: \(escLatex(c.sources))}" }
                out += "\n\\end{quote}\n\n"
            case .code(let code):
                out += "\\begin{lstlisting}[caption=\(escLatex(code.title))]\n\(code.code)\n\\end{lstlisting}\n\n"
            }
        }
        return out
    }

    private static func markdownBlocksFor(_ text: String, in doc: URPDocument) -> String {
        var out = ""
        for block in linearize(text, in: doc) {
            switch block {
            case .paragraph(let p):
                out += "\(p)\n\n"
            case .image(let alt, let path):
                out += "![\(alt)](\(path))\n\n"
            case .table(let headers, let rows):
                out += "| " + headers.joined(separator: " | ") + " |\n"
                out += "|" + String(repeating: " --- |", count: headers.count) + "\n"
                for r in rows { out += "| " + r.joined(separator: " | ") + " |\n" }
                out += "\n"
            case .equation(let eq):
                out += "$$\n\(eq.math)\n$$\n{#\(eq.id) title=\"\(eq.title)\"}\n\n"
            case .claim(let c):
                out += "<claim id=\"\(c.id)\" type=\"\(c.type)\" confidence=\"\(c.confidence)\" sources=\"\(c.sources)\">\n\(c.body)\n</claim>\n\n"
            case .code(let code):
                out += "```\(code.language)\n\(code.code)\n```\n{#\(code.id) title=\"\(code.title)\"}\n\n"
            }
        }
        return out
    }

    private static func epubBlocksFor(_ text: String, in doc: URPDocument) -> String {
        var out = ""
        for block in linearize(text, in: doc) {
            switch block {
            case .paragraph(let p):
                out += "<p>\(inlineMarkdownToHtml(p))</p>\n"
            case .image(let alt, let path):
                out += "<div class=\"figure\" style=\"text-align:center;\"><p style=\"border:1px dashed #ccc;padding:1em;color:#888;\">[Image: \(escContent(path))]</p><p style=\"font-size:0.8em;color:#666;font-style:italic;\(escContent(alt))</p></div>\n"
            case .table(let headers, let rows):
                out += "<table><thead><tr>"
                for h in headers { out += "<th>\(escContent(h))</th>" }
                out += "</tr></thead><tbody>"
                for r in rows { out += "<tr>" + r.map { "<td>\(escContent($0))</td>" }.joined() + "</tr>" }
                out += "</tbody></table>\n"
            case .equation(let eq):
                out += "<div class=\"eq\">\(escContent(eq.math))<div style=\"font-size:0.7em;color:#666;\">\(escContent(eq.title)) · (\(escContent(eq.id)))</div></div>\n"
            case .claim(let c):
                out += "<div class=\"card\"><p><b>\(escContent(c.id))</b> <span class=\"pill\">\(escContent(c.type))</span> <span class=\"pill\">\(escContent(c.confidence))</span></p><p>\(escContent(c.body))</p>"
                if !c.sources.isEmpty { out += "<p style=\"font-size:0.8em;color:#666;\">Sources: \(escContent(c.sources))</p>" }
                out += "</div>\n"
            case .code(let code):
                out += "<pre><code>\(escContent(code.code))</code></pre>\n"
            }
        }
        return out
    }

    // MARK: - Linearizer (shared by every format) -----------------------

    private enum LinearBlock {
        case paragraph(String)
        case image(alt: String, path: String)
        case table(headers: [String], rows: [[String]])
        case equation(URPEquation)
        case claim(URPClaim)
        case code(URPCodeBlock)
    }

    private static func linearize(_ text: String, in doc: URPDocument) -> [LinearBlock] {
        var blocks: [LinearBlock] = []
        let lines = text.components(separatedBy: .newlines)

        var paragraph: [String] = []
        var inTable = false
        var headers: [String] = []
        var rows: [[String]] = []

        func flushParagraph() {
            let j = paragraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !j.isEmpty { blocks.append(.paragraph(j)) }
            paragraph = []
        }
        func flushTable() {
            if !headers.isEmpty || !rows.isEmpty { blocks.append(.table(headers: headers, rows: rows)) }
            headers = []; rows = []; inTable = false
        }

        for line in lines {
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty {
                if inTable { flushTable() }
                flushParagraph()
                continue
            }

            // reference triggers for structured blocks
            if t.contains("<claim") || t.contains("claim-") {
                flushParagraph(); if inTable { flushTable() }
                for c in doc.claims where t.contains(c.id) { blocks.append(.claim(c)) }
                continue
            }
            if t.contains("$$") || t.contains("eq-") || t.contains("<variables") {
                flushParagraph(); if inTable { flushTable() }
                for e in doc.equations where t.contains(e.id) { blocks.append(.equation(e)) }
                continue
            }
            if t.contains("```") || t.contains("diag-") || t.contains("arcmark") || t.contains("code-") {
                flushParagraph(); if inTable { flushTable() }
                for c in doc.codeBlocks where t.contains(c.id) { blocks.append(.code(c)) }
                continue
            }

            // image
            if t.hasPrefix("![") && t.contains("](") && t.hasSuffix(")") {
                flushParagraph(); if inTable { flushTable() }
                let parts = t.components(separatedBy: "](")
                if parts.count >= 2 {
                    let alt = String(parts[0].dropFirst(2))
                    let path = String(parts[1].dropLast())
                    blocks.append(.image(alt: alt, path: path))
                }
                continue
            }

            // table
            if t.hasPrefix("|") && t.hasSuffix("|") {
                flushParagraph()
                inTable = true
                let cells = t.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                if cells.first?.contains("---") == true { continue }
                if headers.isEmpty { headers = cells } else { rows.append(cells) }
                continue
            }

            if inTable { flushTable() }
            paragraph.append(line)
        }

        if inTable { flushTable() }
        flushParagraph()
        return blocks
    }

    // MARK: - Helpers ----------------------------------------------

    private static func typeClassFor(_ type: String) -> String {
        switch type.lowercased() {
        case "empirical": return "empirical"
        case "theoretical": return "theoretical"
        case "design": return "design"
        case "speculative": return "speculative"
        default: return "generic"
        }
    }

    private static func affilLatex(_ a: URPManifest.AuthorInfo) -> String {
        var s = ""
        if !a.affiliation.isEmpty { s = "\\thanks{\(escLatex(a.affiliation))}" }
        if let orcid = a.orcid, !orcid.isEmpty { s += " \\thanks{ORCID: \(escLatex(orcid))}" }
        return s
    }

    private static func slugify(_ s: String) -> String {
        let base = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.alphanumerics
        var out = ""
        for ch in base.unicodeScalars {
            out += allowed.contains(ch) ? String(ch) : "-"
        }
        while out.contains("--") { out = out.replacingOccurrences(of: "--", with: "-") }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static func currentDate(iso8601: Bool) -> String {
        if iso8601 {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f.string(from: Date())
        }
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: Date())
    }

    private static func escContent(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
    private static func escAttr(_ s: String) -> String {
        escContent(s).replacingOccurrences(of: "\"", with: "&quot;")
    }
    private static func escLatex(_ s: String) -> String {
        var r = s
        for (sym, esc) in [("\\","\\textbackslash{}"),("%","\\%"),("$","\\$"),("&","\\&"),("#","\\#"),("_","\\_"),("{","\\{"),("}","\\}"),("~","\\textasciitilde{}"),("^","\\textasciicircum{}")] {
            if sym == "\\" {
                r = r.replacingOccurrences(of: "\\", with: esc)
            } else {
                r = r.replacingOccurrences(of: sym, with: esc)
            }
        }
        return r
    }

    private static func inlineMarkdownToHtml(_ s: String) -> String {
        var r = escContent(s)
        // images
        let imgPattern = "!\\[(.*?)\\]\\((.*?)\\)"
        if let re = try? NSRegularExpression(pattern: imgPattern) {
            let ns = r as NSString
            let mutable = NSMutableString(string: r)
            var delta = 0
            for m in re.matches(in: r, range: NSRange(location: 0, length: ns.length)).reversed() {
                let alt = ns.substring(with: m.range(at: 1))
                let path = ns.substring(with: m.range(at: 2))
                let replacement = "<img src=\"\(escAttr(path))\" alt=\"\(escAttr(alt))\" style=\"max-width:100%;\">"
                mutable.replaceCharacters(in: m.range, with: replacement)
                delta += 0
            }
            r = mutable as String
        }
        // links
        let linkPattern = "\\[(.*?)\\]\\((.*?)\\)"
        if let re = try? NSRegularExpression(pattern: linkPattern) {
            let ns = r as NSString
            let mutable = NSMutableString(string: r)
            for m in re.matches(in: r, range: NSRange(location: 0, length: ns.length)).reversed() {
                let text = ns.substring(with: m.range(at: 1))
                let url = ns.substring(with: m.range(at: 2))
                let replacement = "<a href=\"\(escAttr(url))\">\(escContent(text))</a>"
                mutable.replaceCharacters(in: m.range, with: replacement)
            }
            r = mutable as String
        }
        // bold then italic
        r = r.replacingOccurrences(of: "**", with: "<strong>").replacingOccurrences(of: "__", with: "<strong>")
        // crude pairing for bold and italic: toggle on each occurrence
        r = toggleTags(r, token: "<strong>", close: "</strong>")
        r = r.replacingOccurrences(of: "*", with: "<em>") // leftover single *
        r = toggleTags(r, token: "<em>", close: "</em>")
        return r
    }

    // Toggle alternating occurrences of token to open/close pairs.
    private static func toggleTags(_ s: String, token: String, close: String) -> String {
        var out = ""
        var open = true
        var i = s.startIndex
        while i < s.endIndex {
            if s[i...].hasPrefix(token) {
                out += open ? token : close
                open.toggle()
                i = s.index(i, offsetBy: token.count)
            } else {
                out.append(s[i])
                i = s.index(after: i)
            }
        }
        return out
    }

    // MARK: - PDF via PDFKit --------------------------------------

    /// Renders the document into a multi-page PDF using native PDFKit + NSAttributedString.
    /// Synchronous and reliable — no WebKit lifecycle issues. Completion fires on main.
    public static func generatePDF(
        for doc: URPDocument,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let attrString = generateAttributedPaper(for: doc)
                let data = try renderPDF(from: attrString)
                DispatchQueue.main.async { completion(.success(data)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    /// Builds the paper as a styled `NSAttributedString` — title, authors,
    /// sections, equations (as rendered unicode via LaTeXRenderer), claims,
    /// code blocks, tables, lists, blockquotes, images placeholders.
    static func generateAttributedPaper(for doc: URPDocument) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let bodyFont = NSFont(name: "Times New Roman", size: 12) ?? NSFont.systemFont(ofSize: 12)
        let titleFont = (NSFont(name: "Times New Roman", size: 26) ?? NSFont.systemFont(ofSize: 26)).bold()
        let h2Font = (NSFont(name: "Times New Roman", size: 18) ?? NSFont.systemFont(ofSize: 18)).bold()
        let h3Font = (NSFont(name: "Times New Roman", size: 14) ?? NSFont.systemFont(ofSize: 14)).bold()
        let captionFont = NSFont.systemFont(ofSize: 10)
        let monoFont = NSFont(name: "Menlo", size: 10) ?? NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = .left
        paraStyle.lineSpacing = 4
        paraStyle.paragraphSpacing = 10
        
        let centerStyle = NSMutableParagraphStyle()
        centerStyle.alignment = .center
        centerStyle.lineSpacing = 6
        centerStyle.paragraphSpacing = 10
        
        let h2Style = NSMutableParagraphStyle()
        h2Style.alignment = .left
        h2Style.paragraphSpacingBefore = 18
        h2Style.paragraphSpacing = 8

        func append(_ str: String, font: NSFont, color: NSColor = .black, para: NSParagraphStyle = paraStyle, align: NSTextAlignment? = nil) {
            let style = align == .center ? centerStyle : para
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: color, .paragraphStyle: style
            ]
            result.append(NSAttributedString(string: str, attributes: attrs))
        }

        func appendLineBreak() { result.append(NSAttributedString(string: "\n")) }

        // Title
        append(doc.manifest.paper.title.isEmpty ? "Untitled Research Paper" : doc.manifest.paper.title,
               font: titleFont, align: .center)
        appendLineBreak()
        if !doc.manifest.paper.subtitle.isEmpty {
            append(doc.manifest.paper.subtitle + "\n",
                   font: bodyFont.italic() ?? bodyFont, color: .darkGray, align: .center)
        }
        for a in doc.manifest.authors {
            append(a.name, font: bodyFont.bold(), align: .center)
            if !a.affiliation.isEmpty {
                append("  ·  " + a.affiliation, font: bodyFont, color: .darkGray, align: .center)
            }
            appendLineBreak()
        }
        append("Status: \(doc.manifest.paper.status.uppercased())  ·  URP \(doc.manifest.urp)  ·  License: \(doc.manifest.license.text)\n",
               font: captionFont, color: .gray, align: .center)
        appendLineBreak()

        // Each section
        for section in doc.sections {
            if section.title.isEmpty {
                if !section.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    renderBodyInline(section.body, into: result, doc: doc,
                                     bodyFont: bodyFont, h3Font: h3Font, monoFont: monoFont, captionFont: captionFont, paraStyle: paraStyle)
                }
                continue
            }
            let title = "§ \(section.title)\n"
            append(title, font: h2Font, para: h2Style)
            renderBodyInline(section.body, into: result, doc: doc,
                             bodyFont: bodyFont, h3Font: h3Font, monoFont: monoFont, captionFont: captionFont, paraStyle: paraStyle)
        }
        return result
    }

    private static func renderInlineMarkdown(_ s: String, baseFont: NSFont, paraStyle: NSParagraphStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var bold = false
        var italic = false
        var code = false
        var i = s.startIndex
        
        while i < s.endIndex {
            if s[i...].hasPrefix("**") {
                bold.toggle()
                i = s.index(i, offsetBy: 2)
                continue
            }
            if s[i...].hasPrefix("\\(") {
                let start = s.index(i, offsetBy: 2)
                if let end = s[start...].range(of: "\\)") {
                    let latex = String(s[start..<end.lowerBound])
                    let attrLatex = LaTeXRenderer.render(latex)
                    let nsAttr = NSMutableAttributedString(attrLatex)
                    nsAttr.addAttribute(.paragraphStyle, value: paraStyle, range: NSRange(location: 0, length: nsAttr.length))
                    result.append(nsAttr)
                    i = end.upperBound
                    continue
                }
            }
            if s[i...].hasPrefix("$") {
                let start = s.index(i, offsetBy: 1)
                if let end = s[start...].range(of: "$") {
                    let latex = String(s[start..<end.lowerBound])
                    let attrLatex = LaTeXRenderer.render(latex)
                    let nsAttr = NSMutableAttributedString(attrLatex)
                    nsAttr.addAttribute(.paragraphStyle, value: paraStyle, range: NSRange(location: 0, length: nsAttr.length))
                    result.append(nsAttr)
                    i = end.upperBound
                    continue
                }
            }
            let ch = s[i]
            if ch == "*" && !code {
                italic.toggle()
                i = s.index(after: i)
                continue
            }
            if ch == "`" {
                code.toggle()
                i = s.index(after: i)
                continue
            }
            
            var font = baseFont
            var color = NSColor.black
            if code {
                font = NSFont(name: "Menlo", size: baseFont.pointSize - 1) ?? NSFont.monospacedSystemFont(ofSize: baseFont.pointSize - 1, weight: .regular)
                color = .orange
            } else if bold && italic {
                font = baseFont.bold().italic()
            } else if bold {
                font = baseFont.bold()
            } else if italic {
                font = baseFont.italic()
            }
            
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: color, .paragraphStyle: paraStyle
            ]
            result.append(NSAttributedString(string: String(ch), attributes: attrs))
            i = s.index(after: i)
        }
        return result
    }

    /// Renders a section body string (may contain markdown + URP block placeholders)
    /// into the given mutable attributed string.
    private static func renderBodyInline(_ text: String, into result: NSMutableAttributedString,
                                         doc: URPDocument,
                                         bodyFont: NSFont, h3Font: NSFont, monoFont: NSFont,
                                         captionFont: NSFont, paraStyle: NSMutableParagraphStyle) {
        let lines = text.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { i += 1; continue }

            // Structured block placeholder
            if t.hasPrefix("[URP-EQ:") && t.hasSuffix("]") {
                let id = String(t.dropFirst("[URP-EQ:".count).dropLast())
                if let eq = doc.equations.first(where: { $0.id == id }) {
                    let rendered = LaTeXRenderer.render(eq.math)
                    let nsAtt = NSMutableAttributedString(rendered)
                    let big = bodyFont.withSize(bodyFont.pointSize + 4)
                    nsAtt.addAttribute(.font, value: big, range: NSRange(location: 0, length: nsAtt.length))
                    let centered = NSMutableParagraphStyle(); centered.alignment = .center; centered.lineSpacing = 6
                    nsAtt.addAttribute(.paragraphStyle, value: centered, range: NSRange(location: 0, length: nsAtt.length))
                    result.append(nsAtt)
                    result.append(NSAttributedString(string: "\n\(eq.title)  ·  (\(eq.id))\n\n",
                        attributes: [.font: captionFont, .foregroundColor: NSColor.gray, .paragraphStyle: paraStyle]))
                    if let vb = doc.variablesBlocks.first(where: { $0.forEquation == id }), !vb.variables.isEmpty {
                        result.append(NSAttributedString(string: "Variables:\n",
                            attributes: [.font: captionFont.bold(), .paragraphStyle: paraStyle]))
                        for v in vb.variables {
                            result.append(NSAttributedString(string: "  \(v.symbol)  —  \(v.definition)\n",
                                attributes: [.font: captionFont, .paragraphStyle: paraStyle]))
                        }
                        result.append(NSAttributedString(string: "\n", attributes: [:]))
                    }
                }
                i += 1; continue
            }
            if t.hasPrefix("[URP-CLAIM:") && t.hasSuffix("]") {
                let id = String(t.dropFirst("[URP-CLAIM:".count).dropLast())
                if let c = doc.claims.first(where: { $0.id == id }) {
                    result.append(NSAttributedString(string: "CLAIM \(c.id) [\(c.type) / \(c.confidence)]\n",
                        attributes: [.font: captionFont.bold(), .foregroundColor: NSColor.systemPurple, .paragraphStyle: paraStyle]))
                    result.append(NSAttributedString(string: "\(c.body)\n",
                        attributes: [.font: bodyFont, .paragraphStyle: paraStyle]))
                    if !c.sources.isEmpty {
                        result.append(NSAttributedString(string: "Sources: \(c.sources)\n\n",
                            attributes: [.font: captionFont, .foregroundColor: NSColor.gray, .paragraphStyle: paraStyle]))
                    } else {
                        result.append(NSAttributedString(string: "\n", attributes: [:]))
                    }
                }
                i += 1; continue
            }
            if t.hasPrefix("[URP-CODE:") && t.hasSuffix("]") {
                let id = String(t.dropFirst("[URP-CODE:".count).dropLast())
                if let c = doc.codeBlocks.first(where: { $0.id == id }) {
                    let code = "\(c.language.uppercased())\n\(c.code)\n"
                    result.append(NSAttributedString(string: code,
                        attributes: [.font: monoFont, .foregroundColor: NSColor.darkGray, .paragraphStyle: paraStyle]))
                    result.append(NSAttributedString(string: "\(c.title)  ·  (\(c.id))\n\n",
                        attributes: [.font: captionFont, .foregroundColor: NSColor.gray, .paragraphStyle: paraStyle]))
                }
                i += 1; continue
            }

            // Image
            if t.hasPrefix("![") && t.contains("](") && t.hasSuffix(")") {
                let parts = t.components(separatedBy: "](")
                if parts.count >= 2 {
                    let alt = String(parts[0].dropFirst(2))
                    let path = String(parts[1].dropLast())
                    result.append(NSAttributedString(string: "[ Image: \(path) ]\n\(alt)\n\n",
                        attributes: [.font: captionFont, .foregroundColor: NSColor.gray, .paragraphStyle: paraStyle]))
                }
                i += 1; continue
            }

            // Header
            let h3Style = NSMutableParagraphStyle()
            h3Style.paragraphSpacingBefore = 14
            h3Style.paragraphSpacing = 6
            if t.hasPrefix("### ") {
                result.append(NSAttributedString(string: String(t.dropFirst(4)) + "\n",
                    attributes: [.font: h3Font, .paragraphStyle: h3Style]))
                i += 1; continue
            }
            if t.hasPrefix("## ") {
                result.append(NSAttributedString(string: String(t.dropFirst(3)) + "\n",
                    attributes: [.font: h3Font, .paragraphStyle: h3Style]))
                i += 1; continue
            }

            // Divider
            if t == "---" {
                result.append(NSAttributedString(string: "———\n", attributes: [.font: bodyFont, .paragraphStyle: paraStyle]))
                i += 1; continue
            }

            // Blockquote
            if t.hasPrefix("> ") {
                result.append(NSAttributedString(string: "  \(String(t.dropFirst(2)))\n",
                    attributes: [.font: bodyFont.italic(), .foregroundColor: NSColor.darkGray, .paragraphStyle: paraStyle]))
                i += 1; continue
            }

            // Bullet list (consecutive lines starting with "- ")
            if t.hasPrefix("- ") {
                var items: [String] = []
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("- ") {
                    items.append(String(lines[i].trimmingCharacters(in: .whitespacesAndNewlines).dropFirst(2)))
                    i += 1
                }
                for item in items {
                    result.append(NSAttributedString(string: "  •  ", attributes: [.font: bodyFont, .paragraphStyle: paraStyle]))
                    result.append(renderInlineMarkdown(item, baseFont: bodyFont, paraStyle: paraStyle))
                    result.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: paraStyle]))
                }
                continue
            }

            // Numbered list
            if t.range(of: #"^\d+\\. "#, options: .regularExpression) != nil {
                var items: [String] = []
                while i < lines.count {
                    let trimmed = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.range(of: #"^\d+\\. "#, options: .regularExpression) == nil { break }
                    let dot = trimmed.range(of: ". ")!
                    items.append(String(trimmed[dot.upperBound...]))
                    i += 1
                }
                for (idx, item) in items.enumerated() {
                    result.append(NSAttributedString(string: "  \(idx + 1).  ", attributes: [.font: bodyFont, .paragraphStyle: paraStyle]))
                    result.append(renderInlineMarkdown(item, baseFont: bodyFont, paraStyle: paraStyle))
                    result.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: paraStyle]))
                }
                continue
            }

            // Table: gather consecutive lines starting with |
            if t.hasPrefix("|") && t.hasSuffix("|") {
                var rows: [[String]] = []
                while i < lines.count, let lt = Optional(lines[i].trimmingCharacters(in: .whitespacesAndNewlines)),
                      lt.hasPrefix("|"), lt.hasSuffix("|") {
                    if lt.contains("---") { i += 1; continue }
                    let cells = lt.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                    rows.append(cells)
                    i += 1
                }
                if !rows.isEmpty {
                    let cols = rows[0].count
                    let headerCells = rows[0]
                    result.append(NSAttributedString(string: headerCells.joined(separator: "    ") + "\n", attributes: [.font: bodyFont.bold(), .paragraphStyle: paraStyle]))
                    result.append(NSAttributedString(string: String(repeating: "——    ", count: cols) + "\n", attributes: [.font: bodyFont, .paragraphStyle: paraStyle]))
                    for r in rows.dropFirst() {
                        result.append(NSAttributedString(string: r.joined(separator: "    ") + "\n", attributes: [.font: bodyFont, .paragraphStyle: paraStyle]))
                    }
                }
                continue
            }

            // Plain paragraph
            let nsAtt = renderInlineMarkdown(t, baseFont: bodyFont, paraStyle: paraStyle)
            result.append(nsAtt)
            result.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: paraStyle]))
            i += 1
        }
    }

    /// Renders an NSAttributedString into a multi-page PDF using NSView.dataWithPDF.
    public static func renderPDF(from attr: NSAttributedString) throws -> Data {
        let pageWidth: CGFloat = 612 - 72 * 2  // US Letter minus margins
        let pageHeight: CGFloat = 792 - 72 * 2
        let storage = NSTextStorage(attributedString: attr)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: CGSize(width: pageWidth, height: CGFloat.greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)

        let textView = FlippedTextView(frame: CGRect(x: 0, y: 0, width: pageWidth, height: 1000), textContainer: container)
        textView.isSelectable = true
        textView.isEditable = false
        textView.drawsBackground = true
        textView.backgroundColor = .white

        // Force the layout to complete synchronously.
        layout.ensureLayout(for: container)
        let usedRect = layout.usedRect(for: container)
        let totalHeight = usedRect.height
        let totalPages = max(1, Int((totalHeight / pageHeight).rounded(.up)))

        // Resize text view to the full content height so dataWithPDF captures everything.
        textView.frame = NSRect(x: 0, y: 0, width: pageWidth, height: totalHeight)

        // Each call to dataWithPDF(inside:) captures a sub-region as vector PDF data
        // and returns an independent PDFdocument (not a rasterized image).
        var pages: [Data] = []
        for pageIndex in 0..<totalPages {
            let originY = CGFloat(pageIndex) * pageHeight
            let clipRect = NSRect(x: 0, y: originY, width: pageWidth, height: pageHeight)
            let pageData = textView.dataWithPDF(inside: clipRect)
            if !pageData.isEmpty { pages.append(pageData) }
        }

        guard !pages.isEmpty else {
            throw NSError(domain: "URPExporter", code: 5, userInfo: [NSLocalizedDescriptionKey: "PDF render produced no output."])
        }

        // Merge the per-page PDF Data into one multi-page PDFDocument, set the media box
        // to US Letter with margins, and return as a single Data blob.
        let merged = PDFDocument()
        for pageData in pages {
            if let pagePdf = PDFDocument(data: pageData), let page = pagePdf.page(at: 0) {
                page.setBounds(NSRect(x: 0, y: 0, width: 612, height: 792), for: .mediaBox)
                merged.insert(page, at: merged.pageCount)
            }
        }
        guard let result = merged.dataRepresentation() else {
            throw NSError(domain: "URPExporter", code: 5, userInfo: [NSLocalizedDescriptionKey: "PDF render produced no output."])
        }
        return result
    }
}

/// A flipped NSTextView subclass so y=0 is at the top and pagination math is straightforward.
final class FlippedTextView: NSTextView {
    override var isFlipped: Bool { true }
}

// MARK: - NSFont helpers ----------------------------------------------

private extension NSFont {
    func bold() -> NSFont {
        NSFontManager.shared.convert(self, toHaveTrait: .boldFontMask)
    }
    func italic() -> NSFont {
        NSFontManager.shared.convert(self, toHaveTrait: .italicFontMask)
    }
    func withSize(_ size: CGFloat) -> NSFont {
        NSFontManager.shared.convert(self, toSize: size)
    }
}

private extension NSAttributedString {
    convenience init(_ attr: AttributedString) {
        self.init(attributedString: (try? NSAttributedString(attr, including: \.appKit)) ?? NSAttributedString(string: String(attr.characters)))
    }
}