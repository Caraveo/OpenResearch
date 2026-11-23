"""Render a portable paper and prepare source for publishing formats."""
import json
import mimetypes
import re
import shutil
import subprocess
import tempfile
from html import escape, unescape
from pathlib import Path
from urllib.parse import quote, unquote

import markdown
from latex2mathml.converter import convert

from .paper import BLOCK, attributes, safe_path

ROOT = Path(__file__).parent
STYLE = """
body{margin:0;background:#eef1f5;color:#202b38;font:17px/1.65 Georgia,serif}
article{box-sizing:border-box;max-width:930px;margin:24px auto;padding:40px 54px;background:white}
header{border-bottom:2px solid #33617f;margin-bottom:28px}
.subtitle{font-size:1.24em;color:#43576a}
.author{display:inline-block;margin:0 20px 14px 0;font:14px/1.5 system-ui}
small,.caption{color:#43576a;font:14px/1.5 system-ui}
h1,h2,h3,h4{line-height:1.25;color:#16283a}
pre{padding:12px;overflow:auto;background:#eef2f6;font-size:.85em;white-space:pre-wrap}
aside,figure{margin:16px 0;padding:12px 16px;border:1px solid #d0dbe3;background:#f6f9fc}
blockquote{margin-left:0;padding-left:18px;border-left:3px solid #7095ad}
table{border-collapse:collapse;width:100%;margin:12px 0}
th,td{padding:6px 10px;border:1px solid #ccd6e0;text-align:left}
th{background:#edf2f7}
a{color:#215b84} img,svg{max-width:100%;height:auto} svg{display:block;margin:auto}
nav{border-bottom:1px solid #d0dbe3;padding-bottom:18px}
nav a{display:block;width:fit-content}
.dimension button{margin:6px;cursor:pointer}.viewport{height:340px}.viewport canvas{display:block}
.equation{text-align:center;font-size:1.2em}.variables{text-align:left;font-size:.85em}
@media(max-width:620px){article{margin:0;padding:24px}}
@media print{body{background:white}article{padding:0;margin:0;max-width:none}button,.viewport,output{display:none!important}
figure,aside,pre{break-inside:avoid} h1,h2,h3,h4{break-after:avoid}}
"""
CSP = ("default-src 'none'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval'; "
       "style-src 'unsafe-inline'; img-src 'self' data: blob:; media-src 'self'; "
       "connect-src 'self' data: blob:; worker-src 'self' blob:")


def mime(path):
    if path.endswith(".js"):
        return "text/javascript"
    return mimetypes.guess_type(path)[0] or "application/octet-stream"


def math_html(source, display="inline"):
    try:
        return convert(source.strip(), display=display)
    except Exception:
        return f'<code class="math-source">{escape(source.strip())}</code>'


def arcmark(source, kind="svg"):
    nodes, links = {}, []
    section = ""
    for line in source.splitlines():
        line = line.strip()
        if not line or line.startswith(("#", "//")):
            continue
        if line.lower() in ("nodes:", "links:"):
            section = line[:-1].lower()
            continue
        if "->" in line:
            left, arrow, right = re.split(r"(<->|->)", line, maxsplit=1)
            left, right = left.strip(), right.strip()
            links.append((left, arrow, right))
            nodes.setdefault(left, left)
            nodes.setdefault(right, right)
        elif section == "nodes":
            identifier, _, label = line.partition(":")
            nodes[identifier.strip()] = label.strip().strip("\"'") or identifier.strip()
    if not nodes or not shutil.which("dot"):
        return None
    ids = {node: f"n{i}" for i, node in enumerate(nodes)}
    dot = ["digraph G {", "node [shape=box style=rounded];"]
    for node, label in nodes.items():
        dot.append(f"{ids[node]} [label={json.dumps(label, ensure_ascii=False)}];")
    for left, arrow, right in links:
        direction = " [dir=both]" if arrow == "<->" else ""
        dot.append(f"{ids[left]} -> {ids[right]}{direction};")
    try:
        return subprocess.run(["dot", f"-T{kind}"], input="\n".join([*dot, "}"]).encode(),
                              capture_output=True, check=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return None


def asset_url(path):
    try:
        return "assets/" + quote(safe_path(path))
    except ValueError:
        return ""


def prose(source):
    # Markdown source is untrusted. Preserve angle-bracket link destinations.
    destinations = []
    def preserve(match):
        destinations.append(match[1])
        return f"](URPDESTINATION{len(destinations) - 1}END"

    source = re.sub(r"\]\(<([^>\n]+)>", preserve, source)
    source = re.sub(r"<(?=[!/?A-Za-z])", "&lt;", source)
    source = re.sub(r"(`[^`\n]*`)|(?<![\\$])\$([^$\n]+)\$(?!\$)|\\\(([^\n]+?)\\\)",
                    lambda m: m[1] or math_html(m[2] or m[3]), source)
    result = markdown.markdown(source, extensions=["tables", "fenced_code", "sane_lists", "footnotes"])
    result = re.sub(r'URPDESTINATION(\d+)END',
                    lambda m: escape(destinations[int(m[1])]) if int(m[1]) < len(destinations) else m[0], result)
    result = re.sub(r'(<img\b[^>]*?\bsrc=")([^"]*)',
                    lambda m: m[1] + escape(asset_url(unquote(unescape(m[2])))), result)
    result = re.sub(r'href="([^"]*)"', lambda m: m[0] if m[1].startswith(("https://", "http://", "mailto:", "#")) else 'href="#"', result)
    return result


def render_body(source, numbers=True, interactive=True):
    variables = {}
    for block in BLOCK.finditer(source):
        if block["tag"] == "variables":
            target = attributes(block["attrs"]).get("for", "")
            variables.setdefault(target, []).extend(
                (attributes(m[1]).get("symbol", ""), m[2])
                for m in re.finditer(r"<variable\b([^>]*)>(.*?)</variable>", block["body"], re.S))
    cursor = 0
    output = []
    equation = 0
    for block in BLOCK.finditer(source):
        output.append(prose(source[cursor:block.start()]))
        cursor = block.end()
        meta = attributes(block["attrs"] or block["code_meta"] or block["eq_meta"] or "")
        title = escape(meta.get("title", ""))
        identifier = escape(block["eq_id"] or block["code_id"] or meta.get("id", ""))
        if block["equation"]:
            equation += 1
            number = f" ({equation})" if numbers else ""
            definitions = "".join(f"<dt>{prose(symbol)}</dt><dd>{prose(definition)}</dd>"
                                  for symbol, definition in variables.get(block["eq_id"], []))
            output.append(f'<figure class="equation" id="{identifier}">{math_html(block["math"], "block")}'
                          f'<figcaption class="caption">{title or "Equation"}{number}</figcaption>'
                          f'<dl class="variables">{definitions}</dl></figure>')
        elif block["code"]:
            language = block["lang"].strip().split(maxsplit=1)
            language = language[0] if language else "text"
            body = block["code_body"]
            diagram = arcmark(body) if language.lower() == "arcmark" else None
            if diagram and b"<svg" in diagram:
                content = diagram[diagram.index(b"<svg"):].decode()
            else:
                content = f"<pre><code>{escape(body)}</code></pre>"
            environment = escape(meta.get("environment", ""))
            label = f"{title or escape(language)}"
            if meta.get("executable") == "true":
                label += " · Executable"
            if environment:
                label += f" · {environment}"
            output.append(f'<figure id="{identifier}"><figcaption class="caption">{label}</figcaption>{content}</figure>')
        elif block["tag"] == "claim":
            detail = " · ".join(escape(meta[key]) for key in ("id", "type", "confidence", "sources") if meta.get(key))
            output.append(f'<aside id="{identifier}"><strong>Claim</strong><br><small>{detail}</small>'
                          f'{prose(block["body"])}</aside>')
        elif block["tag"] == "dimension":
            path = meta.get("src", "")
            url = escape(asset_url(path))
            label = title or escape(Path(path).name) or "3D model"
            controls = ('<button class="load-model">View 3D model</button><button class="frame" hidden>Frame</button>'
                        '<button class="spin" aria-pressed="false" hidden>Rotate</button>'
                        '<div class="viewport" hidden></div><output aria-live="polite"></output>') if interactive and url else ""
            output.append(f'<figure class="dimension" id="{identifier}" data-model="{url}">'
                          f'<figcaption><strong>{label}</strong> · 3D model</figcaption>{controls}</figure>')
    output.append(prose(source[cursor:]))
    return "".join(output)


def html_document(paper, body=None, interactive=True, fragment=False):
    metadata = paper.metadata
    info = metadata.get("paper", {})
    english = str(info.get("language", "en"))
    header = ""
    if not fragment:
        authors = []
        for author in metadata.get("authors") or []:
            label = "<br>".join(escape(str(author.get(key))) for key in ("name", "affiliation") if author.get(key))
            if author.get("orcid"):
                orcid = str(author["orcid"])
                label += f'<br><a href="https://orcid.org/{quote(orcid, safe="")}">{escape(orcid)}</a>'
            authors.append(f'<div class="author">{label}</div>')
        details = [escape(str(info[key])) for key in ("type", "version", "status", "created", "updated") if info.get(key)]
        details.append(f"URP {escape(str(metadata.get('urp', '0.1')))}")
        details.extend(f"{key.title()} {escape(str(value))}" for key, value in metadata.get("license", {}).items() if value)
        subtitle = escape(str(info.get("subtitle", "")))
        header = (f"<header><h1>{escape(paper.title)}</h1>"
                  f'<div class="subtitle">{subtitle}</div><p><small>{" · ".join(details)}</small></p>'
                  f'{"".join(authors)}</header>')
    scripts = ""
    if interactive:
        imports = json.dumps({"imports": {"three": "./vendor/build/three.module.js",
                                          "three/addons/": "./vendor/examples/jsm/"}})
        scripts = f'<script type="importmap">{imports}</script><script type="module" src="./dimension.js"></script>'
    source = paper.body if body is None else body
    document = metadata.get("document", {})
    numbers = str(document.get("number_equations", True)).lower() != "false"
    content = render_body(source, numbers, interactive)
    if not fragment:
        outline = []
        def add_heading(match):
            level = int(match[1])
            identifier = f"section-{len(outline) + 1}"
            label = re.sub(r"<[^>]+>", "", match[2])
            outline.append(f'<a href="#{identifier}" style="margin-left:{(level - 1) * 18}px">{label}</a>')
            return f'<h{level} id="{identifier}">{match[2]}</h{level}>'

        content = re.sub(r"<h([1-6])>(.*?)</h\1>", add_heading, content, flags=re.S)
        if outline:
            header += '<nav aria-label="Table of contents"><strong>Table of contents</strong>' + "".join(outline) + "</nav>"
    return (f'<!doctype html><html lang="{escape(english)}"><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<meta http-equiv="Content-Security-Policy" content="{CSP}">'
            f'<title>{escape(paper.title)}</title><style>{STYLE}</style>{scripts}'
            f'<article>{header}{content}</article></html>')


def export_source(paper, diagram=None):
    meta = paper.metadata
    info = meta.get("paper", {})
    head = f"# {paper.title}\n\n"
    if info.get("subtitle"):
        head += f"*{info['subtitle']}*\n\n"
    for author in meta.get("authors") or []:
        head += " · ".join(str(author[key]) for key in ("name", "affiliation", "orcid") if author.get(key)) + "\n\n"
    rights = meta.get("license", {})
    head += f"URP {meta.get('urp', '0.1')} · {info.get('status', 'draft')}"
    if rights.get("text"):
        head += f" · {rights['text']}"
    head += "\n\n"

    def convert_block(block):
        attrs = attributes(block["attrs"] or block["code_meta"] or block["eq_meta"] or "")
        title = attrs.get("title", "")
        if block["equation"]:
            return f"\n\n$$\n{block['math'].strip()}\n$$\n\n{title}\n\n"
        if block["code"]:
            if diagram is not None and block["lang"].strip().lower() == "arcmark":
                image = diagram(block["code_body"])
                if image:
                    return f"\n\n![{title or 'Architecture diagram'}]({image})\n\n"
            return f"\n\n{title}\n\n```{block['lang']}\n{block['code_body']}```\n\n"
        if block["tag"] == "dimension":
            return f"\n\n**3D model** · {title or attrs.get('src', '')}\n\n"
        if block["tag"] == "claim":
            details = " · ".join(attrs[key] for key in ("id", "type", "confidence", "sources") if attrs.get(key))
            return f"\n\n**Claim** · {details}\n\n{block['body'].strip()}\n\n"
        definition = re.sub(r"<variable\b([^>]*)>(.*?)</variable>",
                            lambda m: f"- {attributes(m[1]).get('symbol', '')} — {m[2]}\n",
                            block["body"], flags=re.S)
        return f"\n\n{definition.strip()}\n\n"

    return head + BLOCK.sub(convert_block, paper.body)


def write_assets(directory, assets):
    for name, content in assets.items():
        target = directory / safe_path(name)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)


def export_html(paper, path):
    path = Path(path)
    resources = path.with_name(path.name + ".files")
    resources.mkdir(exist_ok=True)
    write_assets(resources / "assets", paper.assets)
    shutil.copytree(ROOT / "vendor", resources / "vendor", dirs_exist_ok=True)
    shutil.copyfile(ROOT / "dimension.js", resources / "dimension.js")
    page = html_document(paper)
    prefix = quote(resources.name) + "/"
    for prefixless in ('./vendor/', './dimension.js', '"assets/'):
        page = page.replace(prefixless, ('"' if prefixless.startswith('"') else './') + prefix + prefixless.lstrip('./"'))
    path.write_text(page, encoding="utf-8")


def export_markdown(paper, path):
    path = Path(path)
    source = export_source(paper)
    assets = path.with_name(path.name + ".files")
    # Preserve models and their relative buffers/textures alongside the source.
    referenced = {name for name in paper.assets if name.startswith(("images/", "models/"))}
    from .paper import asset_references

    referenced.update(name for name in asset_references(paper.body) if name in paper.assets)
    if referenced:
        write_assets(assets, {name: paper.assets[name] for name in referenced})
        for name in sorted(referenced, key=len, reverse=True):
            source = source.replace(f"]({name})", f"](<{assets.name}/{name}>)")
            source = source.replace(f"](<{name}>)", f"](<{assets.name}/{name}>)")
    path.write_text(source, encoding="utf-8")


def pandoc_export(paper, path, kind):
    executable = shutil.which("pandoc")
    if not executable:
        raise ValueError("Install Pandoc to export LaTeX, DOCX, or EPUB.")
    with tempfile.TemporaryDirectory() as work:
        root = Path(work)
        write_assets(root, paper.assets)
        result = root / f"document.{kind}"
        source = root / "document.md"
        diagrams = {}

        def render_diagram(code):
            image = arcmark(code, "png")
            if image:
                name = f"urp-diagrams/arcmark-{len(diagrams) + 1}.png"
                diagrams[name] = image
                return name
            return None

        content = export_source(paper, render_diagram)
        write_assets(root, diagrams)
        source.write_text(content, encoding="utf-8")
        target = {"tex": "latex", "docx": "docx", "epub": "epub3"}[kind]
        command = [executable, "--from=markdown-raw_html", f"--to={target}", "--standalone",
                   "--resource-path=.", "--metadata", f"pagetitle={paper.title}",
                   "--output", str(result), str(source)]
        complete = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=90)
        if complete.returncode:
            raise ValueError(complete.stderr.strip() or "Pandoc export failed.")
        output = Path(path)
        generated = result.read_bytes()
        if kind == "tex" and (diagrams or paper.assets):
            resources = output.with_name(output.name + ".files")
            write_assets(resources, {**paper.assets, **diagrams})
            graphic_paths = re.compile(rb"(\\includegraphics(?:\[[^\]]*\])?\{)([^}]+)(\})")
            generated = graphic_paths.sub(lambda m: m[1] + resources.name.encode() + b"/" + m[2] + m[3],
                                          generated)
        output.write_bytes(generated)
