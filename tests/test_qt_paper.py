import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile

from openresearch_qt.paper import Paper, template, validate
from openresearch_qt.render import html_document


class PaperTests(unittest.TestCase):
    def test_existing_sample_round_trips(self):
        original = Paper.from_file(Path(__file__).resolve().parents[1] / "paper.rd")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "copy.rd"
            original.save(path)
            copy = Paper.from_file(path)
        self.assertEqual(copy.source, original.source)
        self.assertEqual(copy.title, original.title)
        self.assertEqual(validate(copy), validate(original))
        self.assertIn("Reproducibility Index", html_document(copy))

    def test_glTF_and_sidecars_round_trip(self):
        paper = template()
        paper.source += '\n<dimension id="model-a" src="models/a/model.gltf" title="Model" />\n'
        assets = {"models/a/model.gltf": b"{}", "models/a/mesh.bin": b"mesh"}
        paper.assets.update(assets)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "model.rd"
            paper.save(path)
            loaded = Paper.from_file(path)
        self.assertEqual(loaded.assets, assets)
        self.assertIn('data-model="assets/models/a/model.gltf"', html_document(loaded))
        self.assertNotIn("View 3D model", html_document(loaded, interactive=False))
        self.assertEqual(validate(loaded), [])

    def test_rejects_archive_paths_outside_package(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "invalid.rd"
            with ZipFile(path, "w") as archive:
                archive.writestr("paper.rd.md", "# Abstract")
                archive.writestr("../outside", b"data")
            with self.assertRaisesRegex(ValueError, "Invalid package path"):
                Paper.from_file(path)

    def test_metadata_edit_preserves_custom_header_and_author_roles(self):
        paper = Paper('<urp version="0.1"><custom>Preserve</custom><authors><author>'
                      '<name>Author</name></author></authors></urp>\n\n# Abstract',
                      {"authors": [{"name": "Author", "roles": ["writing"]}]})
        metadata = paper.metadata
        metadata["paper"] = {"title": "A & B < C"}
        paper.set_metadata(metadata)
        self.assertEqual(paper.title, "A & B < C")
        self.assertIn("<custom>Preserve</custom>", paper.source)
        self.assertEqual(paper.metadata["authors"][0]["roles"], ["writing"])

    def test_inline_math_images_and_urps_inside_code(self):
        paper = Paper('\\(x+y\\) ![Image](<images/my image.png>)\n\n'
                      '```xml\n# No heading\n<dimension src="unattached.glb"/>\n```\n\n'
                      '# Real heading\n\n$$x^2$$ {#eq-x}')
        html = html_document(paper)
        self.assertIn("assets/images/my%20image.png", html)
        self.assertEqual(html.count("<math"), 2)
        self.assertIn('id="eq-x"', html)
        self.assertEqual([heading[1] for heading in paper.headings()], ["Real heading"])
        self.assertNotIn("data-model=", html)


if __name__ == "__main__":
    unittest.main()
