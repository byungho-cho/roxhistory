"""Build/check same-name PDF copies without modifying the PPTX originals."""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import unicodedata
import xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import ZipFile

from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "presentations/pdf-manifest.json"
NS = {"p": "http://schemas.openxmlformats.org/presentationml/2006/main",
      "a": "http://schemas.openxmlformats.org/drawingml/2006/main",
      "r": "http://schemas.openxmlformats.org/package/2006/relationships"}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources():
    result = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT,
                            check=True, capture_output=True).stdout.decode("utf-8")
    return sorted(ROOT / name for name in result.split("\0")
                  if name.lower().endswith(".pptx"))


def normalize(text):
    return "".join(c for c in unicodedata.normalize("NFKC", text) if c.isalnum())


def pptx_info(source):
    with ZipFile(source) as package:
        presentation = ET.fromstring(package.read("ppt/presentation.xml"))
        size = presentation.find("p:sldSz", NS)
        relations = ET.fromstring(package.read("ppt/_rels/presentation.xml.rels"))
        targets = {rel.attrib["Id"]: rel.attrib["Target"] for rel in relations}
        paragraphs = []
        for slide in presentation.findall("p:sldIdLst/p:sldId", NS):
            rid = slide.attrib["{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"]
            target = targets[rid]
            name = target.lstrip("/") if target.startswith("/") else "ppt/" + target
            tree = ET.fromstring(package.read(name))
            paragraphs.append([normalize("".join(p.itertext()))
                               for p in tree.findall(".//a:p", NS)])
        return int(size.attrib["cx"]), int(size.attrib["cy"]), paragraphs


def validate(source, pdf):
    width, height, paragraphs = pptx_info(source)
    reader = PdfReader(pdf)
    if reader.is_encrypted or len(reader.pages) != len(paragraphs):
        raise ValueError(f"{pdf.name}: slide/page count mismatch or encrypted PDF")
    for number, (page, texts) in enumerate(zip(reader.pages, paragraphs), 1):
        actual = float(page.mediabox.width) / float(page.mediabox.height)
        if abs(actual - width / height) > 0.01:
            raise ValueError(f"{pdf.name} page {number}: slide proportions changed")
        extracted = normalize(page.extract_text() or "")
        # Ignore one-character labels; check every visible paragraph, including tables.
        missing = [text for text in texts if len(text) > 1 and text not in extracted]
        if missing:
            raise ValueError(f"{pdf.name} page {number}: missing text: {missing[:3]}")
    return len(reader.pages)


def build():
    office = shutil.which("libreoffice") or shutil.which("soffice")
    if not office:
        raise RuntimeError("LibreOffice is required to build PDFs")
    entries = []
    pending = []
    with tempfile.TemporaryDirectory(prefix="roxhistory-pdf-") as temp:
        temp = Path(temp)
        for index, source in enumerate(sources()):
            output = temp / str(index)
            output.mkdir()
            profile = (temp / f"profile-{index}").as_uri()
            subprocess.run([office, f"-env:UserInstallation={profile}", "--headless",
                            "--convert-to", 'pdf:impress_pdf_Export:{"ExportHiddenSlides":{"type":"boolean","value":"true"}}',
                            "--outdir", str(output), str(source)], check=True, timeout=180)
            staged = output / source.with_suffix(".pdf").name
            if not staged.is_file():
                raise RuntimeError(f"No PDF produced for {source.name}")
            pages = validate(source, staged)
            target = source.with_suffix(".pdf")
            entries.append({"source": source.relative_to(ROOT).as_posix(),
                            "pdf": target.relative_to(ROOT).as_posix(),
                            "source_sha256": digest(source), "pdf_sha256": digest(staged),
                            "pages": pages})
            pending.append((staged, target))
        if not entries:
            raise RuntimeError("No tracked PPTX originals found")
        # Copy only after every conversion has passed validation.
        for staged, target in pending:
            shutil.copyfile(staged, target)
        MANIFEST.parent.mkdir(parents=True, exist_ok=True)
        MANIFEST.write_text(json.dumps({"schema_version": 1, "files": entries},
                                      ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    check()


def check():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 1:
        raise ValueError("Unsupported PDF manifest schema")
    expected = {source.relative_to(ROOT).as_posix() for source in sources()}
    entries = manifest["files"]
    if len(entries) != len(expected) or {e["source"] for e in entries} != expected:
        raise ValueError("PPTX list changed: rebuild the PDF copies and manifest")
    for entry in entries:
        source = ROOT / entry["source"]
        target = source.with_suffix(".pdf")
        if entry["pdf"] != target.relative_to(ROOT).as_posix():
            raise ValueError("PDF must use the original PPTX basename and directory")
        if digest(source) != entry["source_sha256"] or digest(target) != entry["pdf_sha256"]:
            raise ValueError(f"{source.name}: stale or modified PDF pair; run build")
        if validate(source, target) != entry["pages"]:
            raise ValueError(f"{target.name}: page count differs from the manifest")
        print(f"PASS {entry['source']} -> {entry['pdf']} ({entry['pages']} pages)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["build", "check"])
    args = parser.parse_args()
    {"build": build, "check": check}[args.command]()
