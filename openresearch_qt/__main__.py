"""Desktop launchers and URP publishing commands."""
import argparse
import sys
from pathlib import Path

from .paper import Paper, validate


def main():
    parser = argparse.ArgumentParser(prog="openresearch")
    commands = parser.add_subparsers(dest="command", required=True)
    for mode in ("writer", "paper", "developer"):
        commands.add_parser(mode).add_argument("file", nargs="?")
    commands.add_parser("validate").add_argument("file")
    package = commands.add_parser("package")
    package.add_argument("file")
    package.add_argument("output")
    build = commands.add_parser("build")
    build.add_argument("file")
    build.add_argument("output")
    build.add_argument("--format", choices=("html", "md", "markdown", "tex", "latex", "doc", "docx", "epub", "pdf"))
    args = parser.parse_args()
    try:
        if args.command in ("writer", "paper", "developer"):
            from PySide6.QtWidgets import QApplication

            from .window import APP_NAMES, Window, register_scheme

            app_name = APP_NAMES[args.command]
            register_scheme()
            QApplication.setApplicationName(app_name)
            QApplication.setDesktopFileName(f"org.openresearch.{app_name}")
            app = QApplication([sys.argv[0]])
            window = Window(args.command, args.file)
            window.show()
            return app.exec()

        paper = Paper.from_file(args.file)
        if args.command == "validate":
            issues = validate(paper)
            for code, severity, location, message in issues:
                print(f"{code} {severity} [{location}] {message}")
            if not issues:
                print("Spec conforming.")
            return int(any(severity == "Error" for _, severity, _, _ in issues))
        if args.command == "package":
            paper.save(args.output)
            return 0

        from .render import export_html, export_markdown, pandoc_export

        output = Path(args.output)
        kind = args.format or output.suffix.removeprefix(".").lower()
        kind = {"doc": "docx", "markdown": "md", "latex": "tex"}.get(kind, kind)
        if kind == "html":
            export_html(paper, output)
        elif kind == "md":
            export_markdown(paper, output)
        elif kind in ("epub", "docx", "tex"):
            pandoc_export(paper, output, kind)
        elif kind == "pdf":
            return print_pdf(paper, output)
        else:
            parser.error(f"Unknown output format: {kind}")
        return 0
    except Exception as error:
        print(f"OpenResearch: {error}", file=sys.stderr)
        return 1


def print_pdf(paper, output):
    from PySide6.QtCore import QTimer
    from PySide6.QtWidgets import QApplication

    from .window import Preview, register_scheme

    register_scheme()
    app = QApplication([sys.argv[0]])
    preview = Preview(None)
    preview.loadFinished.connect(lambda ok: preview.save_pdf(output.absolute()) if ok else app.exit(1))
    preview.pdfPrintingFinished.connect(lambda path, ok: app.exit(0 if ok else 1))
    QTimer.singleShot(45000, lambda: app.exit(1))
    preview.show_paper(paper, interactive=False)
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
