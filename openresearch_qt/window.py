"""Qt Widgets workspaces and shared WebEngine publishing pipeline."""
import json
import re
import struct
import uuid
from html import escape
from pathlib import Path
from shlex import quote
from urllib.parse import unquote, urlsplit

from PySide6.QtCore import QByteArray, QBuffer, QIODevice, QMarginsF, QProcess, QSize, Qt, QTimer, QUrl
from PySide6.QtGui import (
    QAction, QDesktopServices, QFontDatabase, QIcon, QImageReader, QKeySequence, QPageLayout,
    QPageSize, QPixmap, QTextCursor,
)
from PySide6.QtPrintSupport import QPrintDialog, QPrinter
from PySide6.QtWebEngineCore import (
    QWebEnginePage, QWebEngineProfile, QWebEngineUrlScheme, QWebEngineUrlSchemeHandler,
)
from PySide6.QtWebEngineWidgets import QWebEngineView
from PySide6.QtWidgets import (
    QApplication, QCheckBox, QComboBox, QCompleter, QDialog, QDialogButtonBox, QFileDialog, QFormLayout, QHBoxLayout,
    QHeaderView, QLabel, QLineEdit, QListWidget, QMainWindow, QMenu, QMessageBox,
    QPlainTextEdit, QPushButton, QScrollArea, QSplitter, QStackedWidget, QTabWidget,
    QTableWidget, QTableWidgetItem, QTextEdit, QVBoxLayout, QWidget,
)

from .paper import BLOCK, HEADER, PAPER_FIELDS, TYPES, Paper, attributes, safe_path, template, validate
from .render import ROOT, html_document, mime

FORMATS = {"PDF": "pdf", "HTML": "html", "LaTeX": "tex", "Markdown": "md",
           "Word": "docx", "EPUB": "epub"}
APP_NAMES = {"writer": "OpenWriter", "paper": "OpenPaper", "developer": "OpenDeveloper"}
STATUS = ("concept", "proposal", "experiment", "draft", "preprint", "reviewed", "replicated",
          "production-validated", "published")
SNIPPETS = {
    "Header": "## Heading\n", "Subheader": "### Heading\n",
    "LaTeX equation": '$$\nx = a + b\n$$\n{{#eq-{id} title="Equation"}}\n',
    "Image": None, "Table": "| Column A | Column B | Column C |\n| --- | --- | --- |\n"
    "| 1 | alpha | note |\n| 2 | beta | note |\n| 3 | gamma | note |\n",
    "Bullet list": "- Item\n- Item\n- Item\n", "Numbered list": "1. Item\n2. Item\n3. Item\n",
    "Blockquote": "> Quote\n", "Code block": '```python\n\n```\n{{#code-{id} title="Code Block"}}\n',
    "Arcmark diagram": '```arcmark\nnodes:\n  A: Node A\n  B: Node B\nlinks:\n  A -> B\n```\n'
    '{{#diag-{id} title="Topology"}}\n',
    "Variables": '<variables for="eq-new">\n  <variable symbol="$x$">definition</variable>\n</variables>\n',
    "Claim": None, "Inline code": "`code`", "Divider": "---\n",
    "Inline math": "$x = a + b$", "Link": "[label](https://example.org)", "Dimension": None,
}


def register_scheme():
    scheme = QWebEngineUrlScheme(b"urp")
    scheme.setSyntax(QWebEngineUrlScheme.Syntax.Host)
    flags = QWebEngineUrlScheme.Flag
    scheme.setFlags(flags.SecureScheme | flags.CorsEnabled | flags.FetchApiAllowed)
    QWebEngineUrlScheme.registerScheme(scheme)


class PaperResources(QWebEngineUrlSchemeHandler):
    def __init__(self, parent):
        super().__init__(parent)
        self.page = b""
        self.assets = {}
        self.vendor = {}

    def requestStarted(self, request):
        path = request.requestUrl().path().lstrip("/")
        if path == "index.html":
            data = self.page
        elif path.startswith("assets/"):
            data = self.assets.get(path.removeprefix("assets/"))
        elif path == "dimension.js" or path.startswith("vendor/"):
            try:
                if path not in self.vendor:
                    self.vendor[path] = (ROOT / safe_path(path)).read_bytes()
                data = self.vendor[path]
            except (ValueError, OSError):
                data = None
        else:
            data = None
        if data is None:
            request.fail(request.Error.UrlNotFound)
            return
        buffer = QBuffer(request)
        buffer.setData(QByteArray(data))
        buffer.open(QIODevice.OpenModeFlag.ReadOnly)
        request.reply(mime(path).encode(), buffer)


class PaperPage(QWebEnginePage):
    def acceptNavigationRequest(self, url, navigation_type, is_main_frame):
        if url.scheme() == "urp":
            return True
        if navigation_type == self.NavigationType.NavigationTypeLinkClicked and url.scheme() in {"http", "https", "mailto"}:
            QDesktopServices.openUrl(url)
        return False


class Preview(QWebEngineView):
    def __init__(self, parent):
        super().__init__(parent)
        self.profile = QWebEngineProfile(QApplication.instance())
        self.destroyed.connect(self.profile.deleteLater)
        self.resources = PaperResources(self.profile)
        self.profile.installUrlSchemeHandler(b"urp", self.resources)
        self.setPage(PaperPage(self.profile, self))
        self.revision = 0

    def show_paper(self, paper, body=None, fragment=False, interactive=True):
        self.resources.page = html_document(paper, body, interactive, fragment).encode()
        self.resources.assets = paper.assets
        self.revision += 1
        self.load(QUrl(f"urp://paper/index.html?v={self.revision}"))

    def save_pdf(self, path):
        layout = QPageLayout(QPageSize(QPageSize.PageSizeId.A4), QPageLayout.Orientation.Portrait,
                             QMarginsF(1, 1, 1, 1), QPageLayout.Unit.Inch)
        self.printToPdf(str(path), layout)


class SourceEditor(QPlainTextEdit):
    def __init__(self, insert):
        super().__init__()
        self.insert = insert
        self.setFont(QFontDatabase.systemFont(QFontDatabase.SystemFont.FixedFont))
        self.completer = QCompleter(list(SNIPPETS), self)
        self.completer.setWidget(self)
        self.completer.setCaseSensitivity(Qt.CaseSensitivity.CaseInsensitive)
        self.completer.activated.connect(self.complete_snippet)

    def command(self):
        cursor = self.textCursor()
        left = cursor.block().text()[:cursor.positionInBlock()]
        return re.fullmatch(r"\s*/([a-zA-Z ]*)", left)

    def complete_snippet(self, name):
        command = self.command()
        if command:
            self.insert(name, self, len(command[1]) + 1)

    def keyPressEvent(self, event):
        command = self.command()
        if event.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter):
            if command and command[1].strip().lower() == "dimension":
                self.completer.popup().hide()
                self.insert("Dimension", self, len(command[1]) + 1)
                return
        super().keyPressEvent(event)
        command = self.command()
        if command and (event.text().isprintable() or event.key() == Qt.Key.Key_Backspace):
            self.completer.setCompletionPrefix(command[1])
            rect = self.cursorRect()
            rect.setWidth(max(220, self.completer.popup().sizeHintForColumn(0)))
            self.completer.complete(rect)
        elif not command:
            self.completer.popup().hide()

    def show_snippets(self):
        menu = QMenu(self)
        for name in SNIPPETS:
            action = menu.addAction(name if name != "Dimension" else "Dimension (/dimension)")
            action.triggered.connect(lambda checked=False, label=name: self.insert(label, self))
        menu.aboutToHide.connect(menu.deleteLater)
        menu.popup(self.mapToGlobal(self.cursorRect().bottomLeft()))


class Metadata(QWidget):
    def __init__(self, apply):
        super().__init__()
        self.apply = apply
        self.fields = {}
        self.metadata = {}
        self.pending = False
        layout = QVBoxLayout(self)
        form = QFormLayout()
        layout.addLayout(form)
        groups = {
            "paper": PAPER_FIELDS,
            "license": ("text", "code", "data"),
            "reproducibility": ("level", "environment", "entrypoint", "expected_runtime"),
            "document": ("bibliography", "citation_style", "number_sections", "number_figures", "number_equations"),
        }
        options = {("paper", "type"): TYPES, ("paper", "status"): STATUS,
                   ("reproducibility", "level"): tuple(str(level) for level in range(5))}
        for group, keys in groups.items():
            heading = QLabel(group.title())
            heading.setStyleSheet("font-weight:bold")
            form.addRow(heading)
            for key in keys:
                choices = options.get((group, key))
                if choices:
                    field = QComboBox()
                    field.setEditable(True)
                    field.addItems(choices)
                elif key.startswith("number_"):
                    field = QCheckBox()
                else:
                    field = QLineEdit()
                self.fields[group, key] = field
                form.addRow(key.replace("_", " ").capitalize(), field)
                if isinstance(field, QComboBox):
                    field.currentTextChanged.connect(self.changed)
                elif isinstance(field, QCheckBox):
                    field.toggled.connect(self.changed)
                else:
                    field.textEdited.connect(self.changed)
        self.authors = QTableWidget(0, 5)
        self.authors.setHorizontalHeaderLabels(["Name", "Affiliation", "ORCID", "ID", "Roles"])
        self.authors.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        self.authors.setMinimumHeight(140)
        layout.addWidget(QLabel("Authors"))
        layout.addWidget(self.authors)
        row = QHBoxLayout()
        layout.addLayout(row)
        add = QPushButton("Add author")
        add.clicked.connect(self.add_author)
        remove = QPushButton("Remove author")
        remove.clicked.connect(self.remove_author)
        save = QPushButton("Apply metadata")
        save.clicked.connect(self.commit)
        for button in (add, remove, save):
            row.addWidget(button)
        self.authors.cellChanged.connect(self.changed)

    def changed(self, *_):
        self.pending = True

    def add_author(self):
        self.authors.insertRow(self.authors.rowCount())
        self.changed()

    def remove_author(self):
        row = self.authors.currentRow()
        if row >= 0:
            self.authors.removeRow(row)
            self.changed()

    def load(self, metadata):
        self.metadata = metadata
        for (group, key), field in self.fields.items():
            default = True if key.startswith("number_") else ""
            value = metadata.get(group, {}).get(key, default)
            if isinstance(field, QCheckBox):
                field.setChecked(str(value).lower() not in ("false", "0", "no"))
            elif isinstance(field, QComboBox):
                field.setCurrentText(str(value))
            else:
                field.setText(str(value))
        authors = metadata.get("authors") or []
        self.authors.setRowCount(len(authors))
        for row, author in enumerate(authors):
            for column, key in enumerate(("name", "affiliation", "orcid", "id", "roles")):
                value = author.get(key) or ""
                if isinstance(value, list):
                    value = ", ".join(map(str, value))
                self.authors.setItem(row, column, QTableWidgetItem(str(value)))
        self.pending = False

    def commit(self):
        data = dict(self.metadata)
        for (group, key), field in self.fields.items():
            value = (field.isChecked() if isinstance(field, QCheckBox) else
                     field.currentText() if isinstance(field, QComboBox) else field.text())
            data[group] = {**data.get(group, {}), key: value}
        authors = []
        for row in range(self.authors.rowCount()):
            values = {}
            for column, key in enumerate(("name", "affiliation", "orcid", "id", "roles")):
                item = self.authors.item(row, column)
                if item and item.text():
                    values[key] = item.text()
            if values.get("name"):
                if "roles" in values:
                    values["roles"] = [role.strip() for role in values["roles"].split(",") if role.strip()]
                values.setdefault("id", "author:" + "-".join(values["name"].lower().split()))
                authors.append(values)
        data["authors"] = authors
        if self.apply(data):
            self.pending = False
            self.metadata = data
            return True
        return False


class Window(QMainWindow):
    def __init__(self, mode, initial_path=None):
        super().__init__()
        self.mode = mode
        self.app_name = APP_NAMES[mode]
        artwork = {"paper": "OpenPaper.png", "writer": "openresearch-mac@3x.png"}.get(mode)
        if artwork:
            reader = QImageReader(str(ROOT.parent / artwork))
            reader.setScaledSize(QSize(256, 256))
            icon = QIcon(QPixmap.fromImage(reader.read()))
            QApplication.setWindowIcon(icon)
            self.setWindowIcon(icon)
        else:
            icon = QIcon.fromTheme("applications-development")
            QApplication.setWindowIcon(icon)
            self.setWindowIcon(icon)
        self.setWindowTitle(self.app_name)
        self.resize(1180, 800)
        self.paper = Paper()
        self.path = None
        self.dirty = False
        self.exports = []
        self.preview = Preview(self)
        self.timer = QTimer(self, interval=225, singleShot=True)
        self.timer.timeout.connect(self.refresh)
        self.toolbar = self.addToolBar("Document")
        self.toolbar.setMovable(False)
        self.files = self.menuBar().addMenu("&File")
        if mode != "paper":
            new = self.files.addMenu("&New")
            for kind in TYPES:
                new.addAction(kind.replace("-", " ").title(), lambda selected=kind: self.new(selected))
            action = QAction("New", self, shortcut=QKeySequence.StandardKey.New)
            action.triggered.connect(lambda: self.new())
            self.addAction(action)
            self.toolbar.addAction(action)
        self.action("Open…", self.open, QKeySequence.StandardKey.Open)
        if mode != "paper":
            self.action("Save .rd", self.save, QKeySequence.StandardKey.Save)
            self.action("Save As…", lambda: self.save(True), QKeySequence.StandardKey.SaveAs, False)
            self.toolbar.addAction("Insert…", self.insert_menu)
        if mode != "writer":
            publish = self.menuBar().addMenu("&Publish")
            self.print_action = self.action("Print…", self.print_paper, QKeySequence.StandardKey.Print, menu=publish)
            self.pdf_action = self.action("Save PDF…", lambda: self.export("pdf"), menu=publish)
            self.format_actions = [self.action(f"Export {label}…", lambda ext=ext: self.export(ext),
                                               toolbar=False, menu=publish)
                                   for label, ext in FORMATS.items() if ext != "pdf"]
        if mode == "developer":
            self.build_developer()
        elif mode == "writer":
            self.build_writer()
        else:
            welcome = QWidget()
            layout = QVBoxLayout(welcome)
            layout.addStretch()
            label = QLabel("Open an OpenResearch paper")
            label.setAlignment(Qt.AlignmentFlag.AlignCenter)
            label.setStyleSheet("font-size:24px")
            layout.addWidget(label)
            button = QPushButton("Select .rd File")
            button.clicked.connect(self.open)
            layout.addWidget(button, alignment=Qt.AlignmentFlag.AlignHCenter)
            layout.addStretch()
            self.reader = QStackedWidget()
            self.reader.addWidget(welcome)
            self.reader.addWidget(self.preview)
            self.setCentralWidget(self.reader)
        if mode == "developer":
            sample = Path(__file__).resolve().parents[1] / "paper.rd"
            if sample.is_file():
                self.set_paper(Paper.from_file(sample))
            else:
                self.set_paper(template())
        elif mode == "writer":
            self.set_paper(template())
        else:
            self.refresh()
        if initial_path:
            self.load(initial_path)

    def action(self, label, slot, shortcut=None, toolbar=True, menu=None):
        action = QAction(label, self)
        if shortcut is not None:
            action.setShortcut(shortcut)
        action.triggered.connect(lambda: slot())
        (menu or self.files).addAction(action)
        if toolbar:
            self.toolbar.addAction(action)
        return action

    def build_developer(self):
        self.tabs = QTabWidget()
        self.setCentralWidget(self.tabs)
        split = QSplitter()
        self.editor_tabs = QTabWidget()
        self.editor = SourceEditor(self.insert_snippet)
        self.editor.textChanged.connect(self.source_changed)
        self.editor_tabs.addTab(self.editor, "foco Source")
        self.metadata_tab = self.metadata_scroll()
        self.editor_tabs.addTab(self.metadata_tab, "Metadata GUI")
        self.editor_tabs.currentChanged.connect(self.developer_tab_changed)
        split.addWidget(self.editor_tabs)
        split.addWidget(self.preview)
        split.setSizes([510, 670])
        self.tabs.addTab(split, "Write & Preview")
        self.validation = QTableWidget(0, 4)
        self.validation.setHorizontalHeaderLabels(["Rule", "Severity", "Location", "Message"])
        self.validation.horizontalHeader().setStretchLastSection(True)
        self.validation.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self.tabs.addTab(self.validation, "Validate")
        export = QWidget()
        layout = QVBoxLayout(export)
        row = QHBoxLayout()
        self.formats = QComboBox()
        for name, extension in FORMATS.items():
            self.formats.addItem(name, extension)
        row.addWidget(self.formats)
        for name, callback in (("Validate", self.log_validation),
                               ("Build", lambda: self.export(self.formats.currentData())),
                               ("Package .rd", lambda: self.save(True))):
            button = QPushButton(name)
            button.clicked.connect(callback)
            row.addWidget(button)
        layout.addLayout(row)
        self.console = QPlainTextEdit()
        self.console.setReadOnly(True)
        self.console.setFont(QFontDatabase.systemFont(QFontDatabase.SystemFont.FixedFont))
        layout.addWidget(self.console)
        self.tabs.addTab(export, "Build & Export")

    def metadata_scroll(self):
        self.metadata = Metadata(self.apply_metadata)
        scroll = QScrollArea()
        scroll.setWidget(self.metadata)
        scroll.setWidgetResizable(True)
        return scroll

    def build_writer(self):
        self.writer_tabs = QTabWidget()
        self.setCentralWidget(self.writer_tabs)
        split = QSplitter()
        self.outline = QListWidget()
        self.outline.setAccessibleName("Table of contents")
        self.outline.currentRowChanged.connect(self.select_section)
        split.addWidget(self.outline)
        focus = QWidget()
        layout = QVBoxLayout(focus)
        bar = QHBoxLayout()
        layout.addLayout(bar)
        self.section_label = QLabel()
        self.section_label.setStyleSheet("font-size:20px;font-weight:bold")
        bar.addWidget(self.section_label, 1)
        self.edit_section = QPushButton("Edit section")
        self.edit_section.clicked.connect(self.toggle_edit_section)
        bar.addWidget(self.edit_section)
        self.edit_claim = QPushButton("Edit claim")
        self.edit_claim.clicked.connect(self.edit_section_claim)
        bar.addWidget(self.edit_claim)
        add_section = QPushButton("Add section")
        add_section.clicked.connect(self.add_section)
        bar.addWidget(add_section)
        self.section_stack = QStackedWidget()
        self.section_stack.addWidget(self.preview)
        self.editor = SourceEditor(self.insert_snippet)
        self.editor.textChanged.connect(self.section_changed)
        self.section_stack.addWidget(self.editor)
        layout.addWidget(self.section_stack)
        split.addWidget(focus)
        split.setSizes([230, 950])
        self.writer_tabs.addTab(split, "Write")
        self.writer_tabs.addTab(self.metadata_scroll(), "Paper details")
        self.writer_tabs.currentChanged.connect(self.writer_tab_changed)
        self.section_index = -1
        self.section_start = self.section_end = 0

    def developer_tab_changed(self, index):
        if index == 1:
            if not self.metadata.pending:
                self.metadata.load(self.paper.metadata)
        elif self.metadata.pending:
            self.metadata.commit()

    def writer_tab_changed(self, index):
        if index == 1:
            if not self.metadata.pending:
                self.metadata.load(self.paper.metadata)
        elif self.metadata.pending:
            self.metadata.commit()

    def set_paper(self, paper, path=None):
        self.paper, self.path, self.dirty = paper, path, False
        if self.mode == "developer":
            self.set_editor(paper.source)
            self.metadata.load(paper.metadata)
        elif self.mode == "writer":
            self.metadata.load(paper.metadata)
            self.build_outline(0)
        else:
            self.reader.setCurrentIndex(1)
        self.refresh()

    def set_editor(self, text):
        self.editor.blockSignals(True)
        self.editor.setPlainText(text)
        self.editor.blockSignals(False)

    def build_outline(self, row):
        self.headings = self.paper.headings()
        self.outline.blockSignals(True)
        self.outline.clear()
        if not self.headings or self.paper.body[:self.headings[0][2]].strip():
            self.headings.insert(0, (0, "Opening text", 0, 0))
        for level, title, _, _ in self.headings:
            self.outline.addItem("  " * max(0, level - 1) + title)
        row = max(0, min(row, len(self.headings) - 1))
        self.outline.setCurrentRow(row)
        self.outline.blockSignals(False)
        self.select_section(row)

    def select_section(self, row):
        if row < 0:
            return
        self.section_index = row
        _, title, _, start = self.headings[row]
        end = self.headings[row + 1][2] if row + 1 < len(self.headings) else len(self.paper.body)
        self.section_start, self.section_end = start, end
        section = self.paper.body[start:end].strip("\n")
        self.section_label.setTextFormat(Qt.TextFormat.PlainText)
        self.section_label.setText(title)
        self.edit_claim.setVisible(any(match["tag"] == "claim" for match in BLOCK.finditer(section)))
        self.set_editor(section)
        self.section_stack.setCurrentIndex(0)
        self.edit_section.setText("Edit section")
        self.preview.show_paper(self.paper, section, fragment=True)

    def toggle_edit_section(self):
        if self.section_stack.currentIndex():
            self.build_outline(self.section_index)
        else:
            self.section_stack.setCurrentIndex(1)
            self.edit_section.setText("Done")
            self.editor.setFocus()

    def section_changed(self):
        self.replace_section(self.editor.toPlainText())
        self.timer.start()

    def replace_section(self, content):
        body = self.paper.body
        header = HEADER.match(self.paper.source)
        prefix = header[0].strip() + "\n\n" if header else ""
        section = ("\n\n" if self.section_start else "") + content.strip("\n") + "\n\n"
        self.paper.source = prefix + body[:self.section_start] + section + body[self.section_end:]
        delta = len(section) - (self.section_end - self.section_start)
        self.section_end += delta
        self.headings = [(level, title, start + delta, end + delta) if row > self.section_index
                         else (level, title, start, end)
                         for row, (level, title, start, end) in enumerate(self.headings)]
        self.dirty = True

    def edit_section_claim(self):
        source = self.paper.body[self.section_start:self.section_end]
        claims = [match for match in BLOCK.finditer(source) if match["tag"] == "claim"]
        if not claims:
            return
        selected = claims[0]
        if len(claims) > 1:
            menu = QMenu(self)
            options = {menu.addAction(attributes(claim["attrs"]).get("id", f"Claim {index}")): claim
                       for index, claim in enumerate(claims, 1)}
            selected = options.get(menu.exec(self.edit_claim.mapToGlobal(self.edit_claim.rect().bottomLeft())))
            menu.deleteLater()
            if selected is None:
                return
        snippet = self.claim_dialog(uuid.uuid4().hex[:8], selected)
        if snippet is not None:
            self.replace_section(source[:selected.start()] + snippet.strip() + source[selected.end():])
            self.build_outline(self.section_index)
            self.refresh()

    def add_section(self):
        dialog = QDialog(self)
        dialog.setWindowTitle("Add section")
        form = QFormLayout(dialog)
        title = QLineEdit()
        form.addRow("Heading", title)
        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        buttons.accepted.connect(dialog.accept)
        buttons.rejected.connect(dialog.reject)
        form.addRow(buttons)
        if dialog.exec() and title.text().strip():
            self.paper.source = self.paper.source.rstrip() + f"\n\n# {title.text().strip()}\n\n"
            self.dirty = True
            self.build_outline(len(self.paper.headings()) + 1)
            self.refresh()

    def source_changed(self):
        self.paper.source = self.editor.toPlainText()
        self.dirty = True
        self.timer.start()

    def apply_metadata(self, metadata):
        try:
            self.paper.set_metadata(metadata)
        except ValueError as error:
            self.error(error)
            return False
        self.dirty = True
        if self.mode == "developer":
            self.set_editor(self.paper.source)
        else:
            self.build_outline(self.section_index)
        self.refresh()
        return True

    def refresh(self):
        label = self.path.name if self.path else self.paper.title
        self.setWindowTitle(f"{label}{' *' if self.dirty else ''} — {self.app_name}")
        active = self.mode != "paper" or self.path is not None
        if self.mode != "writer":
            for action in [self.print_action, self.pdf_action, *self.format_actions]:
                action.setEnabled(active)
            if active:
                self.preview.show_paper(self.paper)
        if self.mode == "developer":
            issues = validate(self.paper)
            self.validation.setRowCount(len(issues))
            for row, issue in enumerate(issues):
                for column, value in enumerate(issue):
                    self.validation.setItem(row, column, QTableWidgetItem(value))
            self.validation.resizeColumnsToContents()
            self.statusBar().showMessage(f"{len(issues)} validation alerts" if issues else "Spec conforming")

    def ask_save(self):
        if not self.dirty and (self.mode == "paper" or not self.metadata.pending):
            return True
        buttons = QMessageBox.StandardButton
        answer = QMessageBox.question(self, self.app_name, "Save changes to this paper?",
                                      buttons.Save | buttons.Discard | buttons.Cancel, buttons.Save)
        return answer == buttons.Discard or (answer == buttons.Save and self.save())

    def closeEvent(self, event):
        if self.exports or not self.ask_save():
            event.ignore()
        else:
            event.accept()

    def new(self, kind="white-paper"):
        if self.ask_save():
            self.set_paper(template(kind))

    def open(self):
        if not self.ask_save():
            return
        filters = "URP packages (*.rd);;URP source (*.rd.md *.md);;All files (*)"
        path, _ = QFileDialog.getOpenFileName(self, "Open paper", str(self.path or ""), filters)
        if path:
            self.load(path)

    def load(self, path):
        try:
            self.set_paper(Paper.from_file(path), Path(path))
        except Exception as error:
            self.error(error)

    def filename(self, ext):
        slug = re.sub(r"[^\w-]+", "-", self.paper.title.lower()).strip("-") or "paper"
        return f"{slug}.{ext}"

    def save(self, save_as=False):
        if self.metadata.pending and not self.metadata.commit():
            return False
        path = self.path
        if save_as or not path or path.suffix.lower() != ".rd":
            value, _ = QFileDialog.getSaveFileName(self, "Save URP package",
                                                  self.filename("rd"), "URP package (*.rd)")
            if not value:
                return False
            path = Path(value if value.lower().endswith(".rd") else value + ".rd")
        try:
            self.paper.save(path)
        except Exception as error:
            self.error(error)
            return False
        self.path, self.dirty = path, False
        self.refresh()
        self.log(f"$ urp package {quote(str(path))}\nPackage saved.")
        self.statusBar().showMessage(f"Saved {path.name}", 4000)
        return True

    def log(self, text):
        if self.mode == "developer":
            self.console.appendPlainText(text)

    def log_validation(self):
        result = validate(self.paper)
        self.log(f"$ urp validate {quote(self.paper.source_name)}\n" +
                 ("\n".join(f"{code} {severity} [{location}] {message}" for code, severity, location, message in result)
                  if result else "Spec conforming."))

    def error(self, error):
        self.log(str(error))
        QMessageBox.critical(self, self.app_name, str(error))

    def insert_menu(self):
        if self.mode == "developer":
            self.tabs.setCurrentIndex(0)
            self.editor_tabs.setCurrentIndex(0)
        else:
            self.writer_tabs.setCurrentIndex(0)
            if not self.section_stack.currentIndex():
                self.toggle_edit_section()
        self.editor.show_snippets()

    def insert_snippet(self, name, editor, command_length=None):
        cursor = editor.textCursor()
        if command_length is None:
            left = cursor.block().text()[:cursor.positionInBlock()]
            command_length = 1 if left.endswith("/") else 0
        identifier = uuid.uuid4().hex[:8]
        try:
            if name == "Dimension":
                snippet = self.attach_model(identifier)
            elif name == "Image":
                snippet = self.attach_image()
            elif name == "Claim":
                snippet = self.claim_dialog(identifier)
            else:
                snippet = SNIPPETS[name].format(id=identifier)
        except (OSError, ValueError, struct.error) as error:
            self.error(error)
            return
        if snippet is None:
            return
        cursor.movePosition(QTextCursor.MoveOperation.Left, QTextCursor.MoveMode.KeepAnchor, command_length)
        cursor.insertText(snippet)
        editor.setTextCursor(cursor)
        editor.setFocus()

    def attach_image(self):
        path, _ = QFileDialog.getOpenFileName(self, "Attach image", "",
                                             "Images (*.png *.jpeg *.jpg *.webp *.svg)")
        if not path:
            return None
        file = Path(path)
        name = f"images/{uuid.uuid4().hex[:8]}-{file.name}"
        self.paper.assets[name] = file.read_bytes()
        return f"\n![{file.stem.replace('[', '').replace(']', '')}](<{name}>)\n"

    def attach_model(self, identifier):
        path, _ = QFileDialog.getOpenFileName(self, "Attach 3D model", "", "glTF model (*.glb *.gltf)")
        if not path:
            return None
        file = Path(path)
        data = file.read_bytes()
        if file.suffix.lower() == ".glb":
            magic, version, length, chunk_size, chunk_kind = struct.unpack_from("<4sIIII", data)
            if magic != b"glTF" or version != 2 or length != len(data) or chunk_kind != 0x4E4F534A:
                raise ValueError("Select a valid glTF 2.0 binary model.")
            model = json.loads(data[20:20 + chunk_size])
        else:
            model = json.loads(data.decode("utf-8-sig"))
        if not isinstance(model, dict) or str(model.get("asset", {}).get("version", "")) != "2.0":
            raise ValueError("Select a valid glTF 2.0 model.")
        directory = f"models/{identifier}"
        filename = f"model{file.suffix.lower()}"
        name = f"{directory}/{filename}"
        assets = {name: data}
        for item in [*model.get("buffers", []), *model.get("images", [])]:
            uri = item.get("uri")
            if not uri or uri.startswith("data:"):
                continue
            parsed = urlsplit(uri)
            if parsed.scheme or parsed.netloc or parsed.query or parsed.fragment:
                raise ValueError("Model textures and buffers must be local files.")
            relative = safe_path(unquote(parsed.path))
            if relative == filename:
                raise ValueError("A model sidecar has the same filename as the model.")
            sidecar = (file.parent / relative).resolve()
            if not sidecar.is_relative_to(file.parent.resolve()) or not sidecar.is_file():
                raise ValueError(f"Missing model sidecar: {relative}")
            assets[f"{directory}/{relative}"] = sidecar.read_bytes()
        self.paper.assets.update(assets)
        return f'\n\n<dimension id="model-{identifier}" src="{name}" title="{escape(file.stem)}" />\n\n'

    def claim_dialog(self, identifier, current=None):
        dialog = QDialog(self)
        dialog.setWindowTitle("Edit claim" if current else "Insert claim")
        form = QFormLayout(dialog)
        existing = attributes(current["attrs"]) if current else {}
        fields = {
            "id": QLineEdit(existing.get("id", f"claim-{identifier}")),
            "type": QComboBox(), "confidence": QComboBox(),
            "sources": QLineEdit(existing.get("sources", "")),
        }
        fields["type"].addItems(["empirical", "theoretical", "design", "speculative"])
        fields["confidence"].addItems(["moderate", "low", "high"])
        for key, field in fields.items():
            if isinstance(field, QComboBox):
                field.setEditable(True)
                field.setCurrentText(existing.get(key, field.currentText()))
            form.addRow(key.capitalize(), field)
        body = QTextEdit(current["body"].strip() if current else "")
        body.setAcceptRichText(False)
        form.addRow("Statement", body)
        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        form.addRow(buttons)
        buttons.accepted.connect(dialog.accept)
        buttons.rejected.connect(dialog.reject)
        if not dialog.exec():
            return None
        values = " ".join(f'{key}="{escape(field.currentText() if isinstance(field, QComboBox) else field.text())}"'
                          for key, field in fields.items())
        return f"\n\n<claim {values}>\n{body.toPlainText()}\n</claim>\n\n"

    def print_paper(self):
        if self.mode == "developer" and self.metadata.pending and not self.metadata.commit():
            return
        printer = QPrinter(QPrinter.PrinterMode.HighResolution)
        if QPrintDialog(printer, self).exec():
            self.run_print(printer=printer)

    def run_print(self, path=None, printer=None):
        preview = Preview(self)
        job = (preview, printer)
        self.exports.append(job)

        def finish(success):
            self.exports.remove(job)
            preview.deleteLater()
            if success:
                self.log(f"Created {path}" if path else "Print job submitted.")
                self.statusBar().showMessage(f"Saved {Path(path).name}" if path else "Print job submitted.", 5000)
            else:
                self.error("Could not print the paper or create its PDF.")

        def loaded(ok):
            if not ok:
                finish(False)
            elif path:
                preview.pdfPrintingFinished.connect(lambda filename, success: finish(success))
                preview.save_pdf(path)
            else:
                preview.printFinished.connect(finish)
                preview.print(printer)

        preview.loadFinished.connect(loaded)
        preview.show_paper(self.paper, interactive=False)

    def export(self, ext):
        if self.mode == "developer" and self.metadata.pending and not self.metadata.commit():
            return
        path, _ = QFileDialog.getSaveFileName(self, "Export paper", self.filename(ext), f"{ext.upper()} (*.{ext})")
        if not path:
            return
        if not path.lower().endswith(f".{ext}"):
            path += f".{ext}"
        self.log(f"$ urp build {quote(self.paper.source_name)} --format {ext}")
        if ext == "pdf":
            self.run_print(path=path)
            return
        from .render import export_html, export_markdown
        if ext in ("html", "md"):
            try:
                if ext == "html":
                    export_html(self.paper, path)
                else:
                    export_markdown(self.paper, path)
                self.log(f"Created {path}")
                self.statusBar().showMessage(f"Saved {Path(path).name}", 5000)
            except OSError as error:
                self.error(error)
            return
        self.start_export_process(path, ext)

    def start_export_process(self, path, ext):
        import sys
        import tempfile

        temporary = tempfile.TemporaryDirectory()
        snapshot = Path(temporary.name) / "paper.rd"
        try:
            self.paper.save(snapshot)
        except OSError as error:
            temporary.cleanup()
            self.error(error)
            return
        process = QProcess(self)
        job = (process, temporary)
        self.exports.append(job)

        def done(ok):
            self.exports.remove(job)
            error = bytes(process.readAllStandardError()).decode(errors="replace").strip()
            process.deleteLater()
            temporary.cleanup()
            if ok:
                self.log(f"Created {path}")
                self.statusBar().showMessage(f"Saved {Path(path).name}", 5000)
            else:
                self.error(error or "Could not run the export process.")

        process.finished.connect(lambda code, status: done(code == 0))
        process.errorOccurred.connect(lambda error: done(False) if error == QProcess.ProcessError.FailedToStart else None)
        process.start(sys.executable, ["-m", "openresearch_qt", "build", str(snapshot), path, "--format", ext])
