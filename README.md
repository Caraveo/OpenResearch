
<h1 align="center">OpenResearch</h1>

<p align="center">
  <strong>The Universal Research Paper Standard</strong><br>
  <em>We ❤️ research… but research papers are a pain.</em>
</p>

<p align="center">
  <img src="openresearch-mac@3x.png" alt="OpenResearch on macOS" width="220">
</p>

<p align="center">
  <a href="https://github.com/caraveo/OpenResearch/releases/tag/v1.0.0"><img src="https://img.shields.io/badge/release-v1.0.0-success?style=for-the-badge" alt="Release v1.0.0"></a>
  <a href="https://github.com/caraveo/OpenResearch"><img src="https://img.shields.io/badge/platform-macOS%20%7C%20Swift-blue?style=for-the-badge" alt="Platform macOS / Swift"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT%20%2F%20CC--BY--4.0-blue?style=for-the-badge" alt="License"></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/made%20with-Swift-orange?style=for-the-badge" alt="Made with Swift"></a>
  <a href="https://github.com/caraveo/OpenResearch/issues"><img src="https://img.shields.io/badge/issues-welcome-brightgreen?style=for-the-badge" alt="Issues Welcome"></a>
</p>

---

<p align="center">
  <img src="screenshot.png" alt="OpenResearch on macOS" width="720">
</p>

## ✨ Meet OpenResearch

Research should be **beautiful**, **open**, and **effortless**.

We love research — the thrill of discovery, the rigor of method, the joy of a result that holds up. But let's be honest: *publishing* it is a nightmare. Bloated word processors, fragile LaTeX, broken citations, locked-in formats, and reproducibility that quietly evaporates.

**OpenResearch** is the **Universal Research Paper Standard** — a single, open, machine-readable package that treats your paper as living, portable, beautiful source. Feed the specification to your AI and get beauty back.

> **One standard. One package. Every platform. Pure beauty.**

- 📦 **`.rd` packages** — a zipped, platform-agnostic archive of content + metadata
- 🤖 **AI-native** — hand the spec to any model and generate compliant papers instantly
- 🍎 **Native Mac apps** — OpenWriter, OpenPaper & OpenDeveloper, built in Swift
- ♿ **Accessible by design** — built-in conformance & accessibility validation
- 🔓 **Open formats only** — no proprietary lock-in, ever

---

## 🚀 The Apps

| App | What it does | Vibe |
| :--- | :--- | :--- |
| **OpenWriter** | Distraction-free, focus-first editor. Raw markup hidden behind beautiful inline cards. | ✍️ *Write in flow* |
| **OpenPaper** | Read-only viewer with print, PDF, HTML & LaTeX export. | 📖 *Beauty in reading* |
| **OpenDeveloper** | Split-pane power workspace: raw source + live preview + CLI command center. | 🛠️ *For builders* |

The full lifecycle, in one elegant pipeline:

```
OpenDeveloper  ──▶  OpenWriter  ──▶  OpenPaper  ──▶  Vector PDF
```

---

## 📐 The Standard

A **Universal Research Paper (URP)** is a `.rd` ZIP package (MIME `application/vnd.urp+zip`) containing:

```text
[paper-name].rd  (ZIP Container)
├── paper.rd.md      # Structured, human-readable document
└── urp.yaml         # Machine-readable manifest metadata
```

Open, portable, and built to last decades. Every asset is restricted to **open formats only** — `.svg`, `.png`, `.webp`, `.jpeg` for images; `.webm`, `.mp4` for video; `.flac`, `.wav`, `.opus` for audio. No `.tiff`, no `.mov`, no lock-in.

Semantic XML elements (`<urp>`, `<variables>`, `<claim>`) make papers **machine-readable** and **reproducible** — perfect for AI ingestion and automated validation.

---

## ✅ Built-in Validator

Real-time conformance against **18 rules** (URP001–URP018):

- Required metadata & sections (Title, Abstract, References)
- Unique equation & claim identifiers
- Alt-text on every image (accessibility)
- Open-format-only media enforcement
- Heading-hierarchy & asset-size warnings

---

## 📦 Install

OpenResearch ships as a native macOS application suite.

```bash
git clone https://github.com/caraveo/OpenResearch.git
cd OpenResearch
# Open OpenWriter.xcodeproj / OpenPaper.xcodeproj / OpenDeveloper.xcodeproj in Xcode
```

Or grab the latest release:

👉 **[Download v1.0.0](https://github.com/caraveo/OpenResearch/releases/tag/v1.0.0)**

---

## 🤝 Contributing

We ❤️ research and we ❤️ contributors. Issues, ideas, and pull requests are welcome.

## 📜 License

Code under **MIT**. Documentation & papers under **CC-BY-4.0**.

---

<p align="center">
  <em>OpenResearch — feed the specification to your AI and get beauty back.</em>
</p>
