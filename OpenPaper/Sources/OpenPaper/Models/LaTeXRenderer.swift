import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Lightweight LaTeX → AttributedString converter: handles Greek letters, common
/// symbols, sub/superscripts (`_` / `^`), `\frac{a}{b}` `(a/b)`, `\sqrt{x}` `√x`,
/// and braces. Good-enough rendering inside SwiftUI `Text` without WebKit.
public struct LaTeXRenderer {
    public static func render(_ latex: String) -> AttributedString {
        var result = AttributedString()
        var i = latex.startIndex

        while i < latex.endIndex {
            let ch = latex[i]

            // Math/display delimiters $ ... $$ — show as italic markers (drop them).
            if ch == "$" {
                i = latex.index(after: i)
                continue
            }

            if ch == "\\" {
                let next = latex.index(after: i)
                if next < latex.endIndex, latex[next].isLetter {
                    var j = next
                    while j < latex.endIndex, latex[j].isLetter { j = latex.index(after: j) }
                    let cmd = String(latex[next..<j])

                    // Special multi-arg commands.
                    if cmd == "frac", j < latex.endIndex {
                        let (g1, j1) = readGroup(latex, from: j)
                        let afterj1 = skipSpaces(latex, from: j1)
                        let (g2, j2) = readGroup(latex, from: afterj1)
                        var piece = AttributedString("(")
                        piece += render(g1)
                        piece += AttributedString(" / ")
                        piece += render(g2)
                        piece += AttributedString(")")
                        result += piece
                        i = j2
                        continue
                    }
                    if cmd == "sqrt", j < latex.endIndex {
                        let (g, jg) = readGroup(latex, from: j)
                        result += AttributedString("√")
                        if !g.isEmpty {
                            // Wrap multi-char radicands (esp. those with operators) in parens.
                            let needsParens = g.count > 1 && containsOperator(g)
                            if needsParens { result += AttributedString("(") }
                            result += render(g)
                            if needsParens { result += AttributedString(")") }
                        }
                        i = jg
                        continue
                    }
                    if cmd == "binom", j < latex.endIndex {
                        let (g1, j1) = readGroup(latex, from: j)
                        let afterj1 = skipSpaces(latex, from: j1)
                        let (g2, j2) = readGroup(latex, from: afterj1)
                        var piece = AttributedString("(")
                        piece += render(g1)
                        piece += AttributedString(" ")
                        piece += render(g2)
                        piece += AttributedString(")")
                        result += piece
                        i = j2
                        continue
                    }

                    if let s = symbol(for: cmd) {
                        result += AttributedString(s)
                    } else {
                        // Unknown — render the bare command name.
                        result += AttributedString(cmd)
                    }
                    i = j
                    continue
                } else if next < latex.endIndex {
                    let s = latex[next]
                    if s == "\\" { result += AttributedString("\n") }
                    else if s == "," || s == ";" || s == "!" || s == ":" {
                        // Spacing commands — render as a single space.
                        result += AttributedString(" ")
                    } else {
                        result += AttributedString(String(s))
                    }
                    i = latex.index(after: next)
                    continue
                } else {
                    result += AttributedString("\\")
                    i = next
                    continue
                }
            }

            // Subscript / superscript.
            if ch == "_" || ch == "^" {
                let kind = ch
                let next = latex.index(after: i)
                if next < latex.endIndex {
                    let (token, j) = readGroupOrChar(latex, from: next)
                    if !token.isEmpty {
                        // Wrap multi-char subscript/superscript with operators in parens
                        // (e.g. x^{n+1} reads as x^(n+1), not x⁺¹ alone).
                        let needsParens = token.count > 1 && containsOperator(token)
                        if needsParens { result += AttributedString("(") }
                        var inner = render(token)
                        #if canImport(SwiftUI)
                        inner.font = Font.system(size: 12)
                        inner.baselineOffset = kind == "_" ? -5 : 6
                        #endif
                        result += inner
                        if needsParens { result += AttributedString(")") }
                    }
                    i = j
                    continue
                } else {
                    i = next
                    continue
                }
            }

            // Braces are grouping markers — drop them visually.
            if ch == "{" || ch == "}" || ch == "[" || ch == "]" {
                // Convert \left[ \right] etc. to just [
                i = latex.index(after: i)
                continue
            }

            result += AttributedString(String(ch))
            i = latex.index(after: i)
        }

        // Coalesce multi-spaces and trailing dashes that come from formatting.
        return result
    }

    private static func readGroup(_ s: String, from idx: String.Index) -> (String, String.Index) {
        var j = idx
        while j < s.endIndex, s[j].isWhitespace { j = s.index(after: j) }
        if j >= s.endIndex { return ("", j) }
        if s[j] == "{" {
            var depth = 1
            j = s.index(after: j)
            var content = ""
            while j < s.endIndex {
                if s[j] == "{" { depth += 1; content.append("{"); j = s.index(after: j); continue }
                if s[j] == "}" {
                    depth -= 1
                    if depth == 0 { return (content, s.index(after: j)) }
                    content.append("}")
                    j = s.index(after: j)
                    continue
                }
                content.append(s[j])
                j = s.index(after: j)
            }
            return (content, j)
        }
        return (String(s[j]), s.index(after: j))
    }

    private static func readGroupOrChar(_ s: String, from idx: String.Index) -> (String, String.Index) {
        if idx >= s.endIndex { return ("", idx) }
        if s[idx] == "{" { return readGroup(s, from: idx) }
        return (String(s[idx]), s.index(after: idx))
    }

    private static func skipSpaces(_ s: String, from idx: String.Index) -> String.Index {
        var j = idx
        while j < s.endIndex, s[j].isWhitespace { j = s.index(after: j) }
        return j
    }

    /// True if `s` contains any operator character (so we know to parenthesize).
    private static func containsOperator(_ s: String) -> Bool {
        s.rangeOfCharacter(from: CharacterSet(charactersIn: "+-=<>·*/")) != nil
    }

    private static let symbols: [String: String] = [
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ",
        "epsilon": "ε", "varepsilon": "ε", "zeta": "ζ", "eta": "η",
        "theta": "θ", "vartheta": "ϑ", "iota": "ι", "kappa": "κ",
        "lambda": "λ", "mu": "μ", "nu": "ν", "xi": "ξ",
        "pi": "π", "varpi": "ϖ", "rho": "ρ", "varrho": "ϱ",
        "sigma": "σ", "varsigma": "ς", "tau": "τ", "upsilon": "υ",
        "phi": "φ", "varphi": "ϕ", "chi": "χ", "psi": "ψ",
        "omega": "ω", "Omega": "Ω", "Gamma": "Γ", "Delta": "Δ",
        "Theta": "Θ", "Lambda": "Λ", "Xi": "Ξ", "Pi": "Π",
        "Sigma": "Σ", "Phi": "Φ", "Psi": "Ψ",
        "sum": "∑", "prod": "∏", "int": "∫", "oint": "∮", "iint": "∬", "iiint": "∭",
        "infty": "∞", "partial": "∂", "nabla": "∇",
        "pm": "±", "mp": "∓", "times": "×", "div": "÷",
        "cdot": "·", "ldots": "…", "cdots": "⋯", "vdots": "⋮", "ddots": "⋱",
        "leq": "≤", "geq": "≥", "neq": "≠", "approx": "≈", "equiv": "≡", "sim": "∼",
        "in": "∈", "notin": "∉", "subset": "⊂", "supset": "⊃",
        "subseteq": "⊆", "supseteq": "⊇", "emptyset": "∅", "cap": "∩", "cup": "∪",
        "forall": "∀", "exists": "∃", "nexists": "∄",
        "to": "→", "rightarrow": "→", "leftarrow": "←",
        "Rightarrow": "⇒", "Leftarrow": "⇐", "Leftrightarrow": "⇔",
        "leftrightarrow": "↔", "mapsto": "↦",
        "langle": "⟨", "rangle": "⟩", "lceil": "⌈", "rceil": "⌉",
        "lfloor": "⌊", "rfloor": "⌋",
        "cos": "cos", "sin": "sin", "tan": "tan", "cot": "cot",
        "sec": "sec", "csc": "csc", "log": "log", "ln": "ln", "exp": "exp",
        "max": "max", "min": "min", "arg": "arg", "lim": "lim",
        "sup": "sup", "inf": "inf", "dim": "dim", "ker": "ker",
        "deg": "°", "circ": "∘", "hbar": "ℏ", "ell": "ℓ",
        "quad": " ", "qquad": "  ",
        "textbackslash": "\\",
        "Re": "ℜ", "Im": "ℑ", "aleph": "ℵ",
        "perp": "⊥", "parallel": "∥", "angle": "∠",
        "star": "⋆", "ast": "∗", "dagger": "†", "ddagger": "‡", "bullet": "•",
        "Box": "□", "square": "□", "diamond": "⋄", "Diamond": "⋄",
        "left": "", "right": "", "displaystyle": "", "limits": "", "normalsize": "",
        "textbf": "", "textit": "", "mathbf": "", "mathit": "",
        "operatorname": "", "boldsymbol": "", "text": "", "mathcal": "", "mathbb": "",
        "mathrm": "", "mathsf": "", "mathtt": "",
    ]

    private static func symbol(for cmd: String) -> String? {
        if let s = symbols[cmd] { return s }
        return nil
    }
}