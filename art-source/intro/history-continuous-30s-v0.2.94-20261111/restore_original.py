from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parent
manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
name = manifest["original_name"]
output = root / name
if output.exists():
    raise SystemExit("Output already exists; no file was overwritten.")
parts = sorted((item for item in manifest["files"] if item["name"].startswith(name + ".part")), key=lambda item: item["name"])
if len(parts) != 6:
    raise SystemExit("Expected exactly six original parts.")
data = bytearray()
for item in parts:
    chunk = (root / item["name"]).read_bytes()
    if len(chunk) != item["size"] or hashlib.sha256(chunk).hexdigest() != item["sha256"]:
        raise SystemExit("Part verification failed: " + item["name"])
    data.extend(chunk)
if len(data) != manifest["original_size"] or hashlib.sha256(data).hexdigest() != manifest["original_sha256"]:
    raise SystemExit("Original verification failed.")
with output.open("xb") as handle:
    handle.write(data)
print("Verified original restored:", output)
print("SHA-256:", manifest["original_sha256"])
