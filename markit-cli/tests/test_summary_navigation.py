"""CLI regression tests. Set MARKIT_TEST_BINARY to a built markit executable.

Run: python -m unittest discover -s markit-cli/tests -v
The executable must have its usual assets/ directory beside it.
"""

import copy
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import unittest


class Links(HTMLParser):
    def __init__(self, html):
        super().__init__()
        self.links = []
        self.current = None
        self.feed(html)

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            self.current = [dict(attrs), ""]

    def handle_data(self, text):
        if self.current is not None:
            self.current[1] += text

    def handle_endtag(self, tag):
        if tag == "a" and self.current is not None:
            self.links.append((self.current[0], self.current[1].strip()))
            self.current = None

    def with_class(self, name):
        return [(attrs, text) for attrs, text in self.links if name in attrs.get("class", "").split()]


@unittest.skipUnless(os.environ.get("MARKIT_TEST_BINARY"), "set MARKIT_TEST_BINARY")
class SummaryNavigationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="markit-navigation-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "docs"
        self.output = self.root / "site"
        self.binary = str(Path(os.environ["MARKIT_TEST_BINARY"]).resolve())
        self.config = {
            "title": "Navigation fixture",
            "format": "website",
            "codeBlock": {"enabled": False},
            "website": {"chapter": {"navigation": True}},
            "summary": [
                {"home": True, "label": "首页"},
                {"file": "markit.md", "label": "文档"},
                {"file": "demo.md", "label": "示例", "showDrafts": False},
            ],
            "i18n": {
                "default": "en", "target": "en",
                "summary": {"en": ["Home", "Docs", "Demos <&>"]},
            },
        }
        self.write("markit.md", "- [Guide start](guide/start.md)\n- [Shared](shared.md)\n- [Other Summary](demo.md)\n\n<!-- homepage -->\n\n# Welcome fixture\n")
        self.write("demo.md", "- [Demo start](start.markdown)\n  - [Demo second](deep/second.md)\n- [Shared demo](shared.md)\n- [Draft hidden]()\n  - [Draft child](hidden.md)\n")
        for name, body in {
            "guide/start.md": "# Guide body\n\nGUIDE_UNIQUE_TEXT\n",
            "shared.md": "# Shared body\n\nSHARED_UNIQUE_TEXT\n",
            "start.markdown": "# Demo body\n\nDEMO_UNIQUE_TEXT\n",
            "deep/second.md": "# Second body\n\nSECOND_UNIQUE_TEXT\n",
            "hidden.md": "# Must not render\n",
        }.items():
            self.write(name, body)

    def write(self, name, text):
        path = self.source / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def save_config(self, config=None, name="markit.json"):
        self.write(name, json.dumps(config or self.config, ensure_ascii=False))

    def render(self, success=True, jobs=1, configs=None):
        self.save_config()
        args = [self.binary, "render", "-i", str(self.source), "-o", str(self.output), "--jobs", str(jobs)]
        if configs:
            args += ["--config", ",".join(str(self.source / name) for name in configs)]
        result = subprocess.run(args, text=True, encoding="utf-8", errors="replace", capture_output=True, timeout=90)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def html(self, page, language="en"):
        return (self.output / language / page).read_text(encoding="utf-8")

    def top(self, page):
        return Links(self.html(page)).with_class("top-nav-link")

    def test_menus_own_their_sidebar_and_active_state(self):
        self.render(jobs=2)
        for page, active in [("guide/start.html", "Docs"), ("start.html", "Demos <&>"), ("deep/second.html", "Demos <&>"), ("shared.html", "Docs")]:
            top = self.top(page)
            self.assertEqual([text for _, text in top], ["Home", "Docs", "Demos <&>"])
            self.assertEqual([text for attrs, text in top if "active" in attrs["class"].split()], [active])
        sidebar = Links(self.html("deep/second.html")).with_class("nav-link")
        self.assertIn("Demo start", [text for _, text in sidebar])
        self.assertNotIn("Guide start", [text for _, text in sidebar])
        self.assertNotIn("Draft hidden", self.html("start.html"))
        self.assertFalse((self.output / "en" / "hidden.html").exists())
        self.assertFalse((self.output / "en" / "demo.html").exists())
        self.assertIn("Welcome fixture", self.html("index.html"))

    def test_relative_links_and_chapter_navigation(self):
        self.render()
        top = self.top("deep/second.html")
        self.assertEqual([attrs["href"] for attrs, _ in top], ["../index.html", "../guide/start.html", "../start.html"])
        chapter = Links(self.html("deep/second.html")).with_class("chapter-nav-prev")
        self.assertEqual(chapter[0][0]["href"], "../start.html")
        self.assertIn("Demo start", chapter[0][1])

    def test_locale_fallback_and_null_slot(self):
        self.config["i18n"]["summary"]["en"] = [None, "Translated docs", None]
        self.render()
        self.assertEqual([text for _, text in self.top("start.html")], ["首页", "Translated docs", "示例"])
        del self.config["i18n"]["summary"]["en"]
        self.render()
        self.assertEqual([text for _, text in self.top("start.html")], ["首页", "文档", "示例"])

    def test_no_custom_homepage_still_has_menus(self):
        self.write("markit.md", "# Guides\n\n- [Guide start](guide/start.md)\n")
        self.render()
        self.assertEqual(len(self.top("start.html")), 3)
        self.assertIn('url=guide/start.html', self.html("index.html"))

    def test_hidden_home_keeps_translation_slot(self):
        self.config["summary"][0]["home"] = False
        self.render()
        self.assertEqual([text for _, text in self.top("start.html")], ["Docs", "Demos <&>"])
        self.assertIn('url=guide/start.html', self.html("index.html"))
        self.assertNotIn("Welcome fixture", self.html("index.html"))

    def test_missing_summary_does_not_scan_unlisted_files(self):
        self.config["summary"][2]["file"] = "missing.md"
        log = self.render(success=False)
        self.assertIn("missing.md", log)
        self.assertFalse((self.output / "en" / "hidden.html").exists())

    def test_invalid_and_legacy_configuration_is_rejected(self):
        base = copy.deepcopy(self.config)
        changes = [
            {"summary": {"file": "markit.md"}},
            {"nav": []},
            {"summary": [{"home": True}, {"home": False}, {"file": "markit.md"}]},
            {"summary": [{"file": "markit.md"}, {"file": "./markit.md"}]},
            {"summary": [{"home": True, "file": "markit.md"}]},
            {"summary": [{"file": "markit.md", "showDrafts": "false"}]},
            {"i18n": {"summary": {"en": ["Only one"]}}},
            {"i18n": {"summary": {"en": ["Home", 3, "Demos"]}}},
            {"i18n": {"home": "Old home"}},
        ]
        for change in changes:
            with self.subTest(change=change):
                self.config = copy.deepcopy(base)
                self.config.update(change)
                self.render(success=False)

    def test_multilanguage_labels_and_paths(self):
        self.save_config(name="markit.en.json")
        chinese = copy.deepcopy(self.config)
        chinese["i18n"]["default"] = "zh"
        chinese["i18n"]["target"] = "zh"
        self.save_config(chinese, "markit.zh.json")
        self.render(configs=["markit.en.json", "markit.zh.json"])
        self.assertIn("Demos &lt;&amp;&gt;", self.html("start.html", "en"))
        top = Links(self.html("deep/second.html", "zh")).with_class("top-nav-link")
        self.assertEqual([text for _, text in top], ["首页", "文档", "示例"])
        self.assertEqual(top[2][0]["href"], "../start.html")

    def test_merged_markdown_keeps_menu_order_and_deduplicates(self):
        self.config["format"] = "markdown"
        self.render(jobs=2)
        merged = (self.output / "en" / "merged.md").read_text(encoding="utf-8")
        self.assertEqual(merged.count("SHARED_UNIQUE_TEXT"), 1)
        self.assertLess(merged.index("GUIDE_UNIQUE_TEXT"), merged.index("DEMO_UNIQUE_TEXT"))
        self.assertNotIn("Must not render", merged)

    def test_summary_watch_and_config_reload(self):
        self.save_config()
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        log = open(self.root / "serve.log", "w", encoding="utf-8")
        process = subprocess.Popen([self.binary, "serve", "-i", str(self.source), "-o", str(self.output), "--port", str(port)], stdout=log, stderr=subprocess.STDOUT)
        def stop():
            process.terminate()
            try:
                process.wait(timeout=8)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=8)
            log.close()
        self.addCleanup(stop)
        def wait_for(predicate):
            deadline = time.monotonic() + 35
            while time.monotonic() < deadline:
                self.assertIsNone(process.poll(), (self.root / "serve.log").read_text(encoding="utf-8"))
                try:
                    if predicate():
                        return
                except (FileNotFoundError, IndexError):
                    pass
                time.sleep(0.2)
            self.fail((self.root / "serve.log").read_text(encoding="utf-8"))
        wait_for(lambda: (self.output / "en" / "deep/second.html").exists())
        # Allow the server to attach its watcher after its initial render.
        def ready():
            with socket.socket() as sock:
                return sock.connect_ex(("127.0.0.1", port)) == 0
        wait_for(ready)
        self.write("demo.md", "- [Changed demo title](start.markdown)\n- [Demo second](deep/second.md)\n")
        wait_for(lambda: "Changed demo title" in self.html("deep/second.html"))
        self.write("replacement.md", "- [Replacement entry](deep/second.md)\n- [Demo start](start.markdown)\n")
        self.config["summary"][2]["file"] = "replacement.md"
        self.save_config()
        wait_for(lambda: "Replacement entry" in self.html("start.html"))
        self.write("replacement.md", "- [Updated replacement](deep/second.md)\n- [Demo start](start.markdown)\n")
        wait_for(lambda: "Updated replacement" in self.html("start.html"))


if __name__ == "__main__":
    unittest.main()
