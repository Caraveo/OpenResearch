"""URP source, manifest, and package handling shared by all three apps."""
import copy
import os
import re
import tempfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from html import unescape
from pathlib import Path, PurePosixPath
from urllib.parse import unquote
from zipfile import ZIP_DEFLATED, ZipFile, is_zipfile

import yaml

HEADER = re.compile(r"\A\s*<urp\b[^>]*>.*?</urp>", re.S)
BLOCK = re.compile(
    r"(?P<code>^[ \t]*```(?P<lang>[^\n]*)\n(?P<code_body>.*?)^[ \t]*```[ \t]*"
    r"(?:[ \t\n]*\{#(?P<code_id>[^\s}]+)(?P<code_meta>[^}]*)\})?)"
    r"|(?P<equation>\$\$(?P<math>.*?)\$\$"
    r"(?:[ \t\n]*\{#(?P<eq_id>[^\s}]+)(?P<eq_meta>[^}]*)\})?)"
    r"|<(?P<tag>claim|variables|dimension)\b(?P<attrs>[^>]*?)(?:\s*/>|>(?P<body>.*?)</(?P=tag)>)",
    re.M | re.S,
)
HEADING = re.compile(r"^(#{1,6})[ \t]+(.+?)[ \t]*#*[ \t]*$", re.M)
IMAGE = re.compile(r"!\[([^\]]*)\]\((?:<([^>\n]+)>|([^\s)]+))(?:\s+[\"'][^\n]*?[\"'])?\)")
SECTIONS = ("Abstract", "Problem", "Methodology", "Architecture", "Research",
            "Results", "Limitations", "Conclusion", "References")
TYPES = ("white-paper", "technical-paper", "research-proposal", "preprint")
PAPER_FIELDS = ("id", "title", "subtitle", "type", "language", "version", "created", "updated", "status")
SOURCE_NAMES = ("paper.rd.md", "paper.rd", "paper.md")


def attributes(source):
    return {m[1]: unescape(m[3]) for m in re.finditer(r"""([\w-]+)\s*=\s*(["'])(.*?)\2""", source, re.S)}


def safe_path(name):
    path = PurePosixPath(name)
    if not name or path.is_absolute() or ".." in path.parts or "\\" in name or not path.parts:
        raise ValueError(f"Invalid package path: {name}")
    return path.as_posix()


def xml_mapping(element):
    result = {}
    for child in element:
        if child.tag == "author":
            result.setdefault("author", []).append(xml_mapping(child))
        else:
            result[child.tag.replace("-", "_")] = xml_mapping(child) if len(child) else child.text or ""
    return result


@dataclass
class Paper:
    source: str = ""
    manifest: dict = field(default_factory=dict)
    assets: dict[str, bytes] = field(default_factory=dict)
    source_name: str = SOURCE_NAMES[0]

    @property
    def metadata(self):
        data = copy.deepcopy(self.manifest)
        match = HEADER.match(self.source)
        if match:
            try:
                root = ET.fromstring(match[0].strip())
            except ET.ParseError:
                return data
            xml = xml_mapping(root)
            xml["urp"] = root.get("version", "0.1")
            if "authors" in xml:
                group = xml["authors"]
                source_authors = group.get("author", []) if isinstance(group, dict) else []
                package_authors = data.get("authors", [])
                xml["authors"] = []
                for author in source_authors:
                    saved = next((item for item in package_authors if item.get("name") == author.get("name")), {})
                    xml["authors"].append({**saved, **author})
            for group, value in xml.items():
                if isinstance(value, dict) and isinstance(data.get(group), dict):
                    data[group].update(value)
                else:
                    data[group] = value
        return data

    @property
    def body(self):
        return HEADER.sub("", self.source, count=1).lstrip("\n")

    @property
    def title(self):
        return str(self.metadata.get("paper", {}).get("title") or "Untitled Paper")

    def set_metadata(self, metadata):
        header = HEADER.match(self.source)
        try:
            root = ET.fromstring(header[0].strip()) if header else ET.Element("urp")
        except ET.ParseError as error:
            raise ValueError("Repair the XML header in source before editing metadata.") from error
        root.set("version", str(metadata.get("urp", "0.1")))
        previous = self.metadata
        for group in ("paper", "license", "reproducibility", "authors"):
            if metadata.get(group) == previous.get(group):
                continue
            node = root.find(group)
            if node is None:
                node = ET.SubElement(root, group)
            values = metadata.get(group, {})
            if group == "authors":
                for author in node.findall("author"):
                    node.remove(author)
                for values_for_author in values:
                    author = ET.SubElement(node, "author")
                    for key, value in values_for_author.items():
                        if isinstance(value, str):
                            ET.SubElement(author, key).text = value
                continue
            for key, value in values.items():
                if isinstance(value, (list, dict)):
                    continue
                target = next((child for child in node if child.tag.replace("-", "_") == key), None)
                if target is None:
                    target = ET.SubElement(node, key)
                target.text = str(value)
        self.manifest = copy.deepcopy(metadata)
        ET.indent(root, "  ")
        self.source = ET.tostring(root, encoding="unicode", short_empty_elements=False) + "\n\n" + self.body

    def headings(self):
        masked = BLOCK.sub(lambda match: re.sub(r"[^\n]", " ", match[0]), self.body)
        return [(len(m[1]), m[2], m.start(), m.end()) for m in HEADING.finditer(masked)]

    @classmethod
    def from_file(cls, path):
        path = Path(path)
        if not is_zipfile(path):
            source = path.read_text(encoding="utf-8-sig")
            paper = cls(source)
            for reference in asset_references(paper.body):
                try:
                    name = safe_path(reference)
                    asset = (path.parent / name).resolve()
                    if asset.is_relative_to(path.parent.resolve()) and asset.is_file():
                        paper.assets[name] = asset.read_bytes()
                except (ValueError, OSError):
                    continue
            return paper
        with ZipFile(path) as archive:
            files = {}
            total = 0
            for entry in archive.infolist():
                if entry.is_dir() or entry.filename.startswith("__MACOSX/"):
                    continue
                name = safe_path(entry.filename)
                total += entry.file_size
                if total > 512 * 1024 * 1024 or name in files:
                    raise ValueError("Package exceeds the size limit or contains duplicate paths.")
                files[name] = archive.read(entry)
        manifest = yaml.safe_load(files.pop("urp.yaml", b"")) or {}
        if not isinstance(manifest, dict):
            raise ValueError("urp.yaml must contain a mapping.")
        for group in ("paper", "license", "reproducibility", "document"):
            if group in manifest and not isinstance(manifest[group], dict):
                raise ValueError(f"Manifest field {group} must contain a mapping.")
        authors = manifest.get("authors", [])
        if not isinstance(authors, list) or any(not isinstance(author, dict) for author in authors):
            raise ValueError("Manifest authors must be a list of mappings.")
        document = manifest.get("document", {})
        candidates = (str(document.get("source", "")), *SOURCE_NAMES) if isinstance(document, dict) else SOURCE_NAMES
        name = next((name for name in candidates if name and name in files), None)
        if name is None:
            raise ValueError("The package does not contain a URP source document.")
        return cls(files.pop(name).decode("utf-8-sig"), manifest, files, name)

    def save(self, path):
        path = Path(path)
        metadata = self.metadata
        metadata.setdefault("urp", "0.1")
        document = metadata.get("document")
        if not isinstance(document, dict):
            document = {}
        metadata["document"] = {**document, "source": self.source_name}
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as temporary:
            staged = Path(temporary.name)
        try:
            with ZipFile(staged, "w", ZIP_DEFLATED) as archive:
                archive.writestr(self.source_name, self.source)
                archive.writestr("urp.yaml", yaml.safe_dump(metadata, sort_keys=False, allow_unicode=True))
                for name, data in self.assets.items():
                    archive.writestr(safe_path(name), data)
            os.replace(staged, path)
        finally:
            staged.unlink(missing_ok=True)


def asset_references(body):
    masked = BLOCK.sub(lambda match: match[0] if match["tag"] == "claim" else "", body)
    yield from (unquote(m[2] or m[3]) for m in IMAGE.finditer(masked))
    for match in BLOCK.finditer(body):
        if match["tag"] == "dimension":
            yield attributes(match["attrs"]).get("src", "")


def template(kind="white-paper"):
    paper = Paper("\n\n".join(f"# {title}\n\n" for title in SECTIONS))
    paper.set_metadata({"paper": {"title": "Untitled Paper", "type": kind, "status": "draft",
                                  "version": "1.0.0", "language": "en-US"},
                        "license": {"text": "CC-BY-4.0", "code": "MIT", "data": "CC-BY-4.0"}})
    return paper


def validate(paper):
    issues = []
    metadata = paper.metadata
    def issue(code, message, location, severity="Warning"):
        issues.append((code, severity, location, message))

    if not str(metadata.get("paper", {}).get("title", "")).strip():
        issue("URP001", "Missing document title.", "Manifest", "Error")
    headings = [title.lower() for _, title, _, _ in paper.headings()]
    required = {"Abstract": ("abstract",), "Problem": ("problem", "research question", "thesis"),
                "Methodology": ("methodology",), "Architecture": ("architecture",),
                "Conclusion": ("conclusion",), "References": ("reference",),
                "Limitations": ("limitation",)}
    for name, alternatives in required.items():
        if not any(term in title for title in headings for term in alternatives):
            code = {"Abstract": "URP002", "References": "URP003", "Limitations": "URP014"}.get(name, f"URP002-{name}")
            issue(code, f"Missing {name} section.", "Sections",
                  "Warning" if name in ("References", "Limitations") else "Error")
    if str(metadata.get("urp", "0.1")) != "0.1":
        issue("URP012", f"Unsupported URP version {metadata['urp']}.", "Manifest")
    identifiers, equations = set(), set()
    for block in BLOCK.finditer(paper.body):
        attr = attributes(block["attrs"] or block["code_meta"] or "")
        identifier = block["code_id"] or block["eq_id"] or attr.get("id")
        if identifier:
            if identifier in identifiers:
                issue("URP007", f"Duplicate identifier {identifier}.", identifier, "Error")
            identifiers.add(identifier)
        if block["eq_id"]:
            equations.add(block["eq_id"])
        if block["code"] and attr.get("executable") == "true" and not attr.get("environment"):
            issue("URP009", "Executable code block needs an environment.", identifier or "Code block")
        if block["tag"] == "dimension":
            model = attr.get("src", "")
            if model not in paper.assets or Path(model).suffix.lower() not in {".glb", ".gltf"}:
                issue("DIMENSION", "Missing or unsupported 3D model.", model or "3D model", "Error")
    prose = BLOCK.sub("", paper.body)
    for reference in re.findall(r"@eq-([\w-]+)", prose):
        if reference not in equations and f"eq-{reference}" not in equations:
            issue("URP008", f"Undefined equation reference @eq-{reference}.", "Markdown")
    for alt, bracketed_name, simple_name in IMAGE.findall(prose):
        name = bracketed_name or simple_name
        if not alt.strip():
            issue("URP006", "Image is missing alt text.", name)
        extension = Path(name).suffix.lower()
        if extension in {".png", ".jpg", ".jpeg", ".webp", ".svg"}:
            issue("URP018", "Image portability target is 5 MB.", name)
    for name in re.findall(r"\]\(<?([^\s)>]+)", prose):
        if Path(name).suffix.lower() in {".mov", ".gif", ".mp3", ".tiff", ".bmp", ".wmv", ".avi", ".ogg"}:
            issue("URP016", "Unsupported media format.", name)
    previous = 0
    for level, title, _, _ in paper.headings():
        if previous and level > previous + 1:
            issue("URP017", f"Skipped heading level from {previous} to {level}.", title)
        previous = level
    return issues
