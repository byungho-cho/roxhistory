"""Persist the Korean font once. Original Figma texture files must be restored separately."""
from pathlib import Path
from urllib.request import urlopen
import hashlib, json
assets=[
 {"path":"game/assets/fonts/NotoSansKR.ttf","url":"https://raw.githubusercontent.com/google/fonts/main/ofl/notosanskr/NotoSansKR%5Bwght%5D.ttf"},
 {"path":"game/assets/fonts/OFL.txt","url":"https://raw.githubusercontent.com/google/fonts/main/ofl/notosanskr/OFL.txt"}
]
manifest=[]
for item in assets:
 p=Path(item["path"]); p.parent.mkdir(parents=True,exist_ok=True)
 if not p.exists():
  with urlopen(item["url"],timeout=120) as response: p.write_bytes(response.read())
 if p.stat().st_size==0: raise RuntimeError(f"Empty asset: {p}")
 manifest.append({"path":str(p),"bytes":p.stat().st_size,"sha256":hashlib.sha256(p.read_bytes()).hexdigest()})
Path("game/assets/manifest.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
