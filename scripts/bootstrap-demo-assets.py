"""One-time asset transfer; CI commits original bytes and removes this helper."""
from pathlib import Path
from urllib.request import urlopen
import hashlib, json
assets = [
  {
    "path": "game/assets/figma/20204.png",
    "url": "https://www.figma.com/api/mcp/asset/a024d989-584c-42fd-ad8c-5c817affce8e/20204.png"
  },
  {
    "path": "game/assets/figma/98398.png",
    "url": "https://www.figma.com/api/mcp/asset/a024d989-584c-42fd-ad8c-5c817affce8e/98398.png"
  },
  {
    "path": "game/assets/figma/0e5b8.png",
    "url": "https://www.figma.com/api/mcp/asset/a995fa45-c693-4bec-a316-9f4a26ae6780/0e5b8.png"
  },
  {
    "path": "game/assets/figma/3eebe.png",
    "url": "https://www.figma.com/api/mcp/asset/c668d944-5efa-4066-8c9c-9623531dcd8d/3eebe.png"
  },
  {
    "path": "game/assets/figma/fbe0a.svg",
    "url": "https://www.figma.com/api/mcp/asset/a995fa45-c693-4bec-a316-9f4a26ae6780/fbe0a.svg"
  },
  {
    "path": "game/assets/figma/0fa22.svg",
    "url": "https://www.figma.com/api/mcp/asset/a995fa45-c693-4bec-a316-9f4a26ae6780/0fa22.svg"
  },
  {
    "path": "game/assets/figma/d3b84.svg",
    "url": "https://www.figma.com/api/mcp/asset/a995fa45-c693-4bec-a316-9f4a26ae6780/d3b84.svg"
  },
  {
    "path": "game/assets/figma/fac42.svg",
    "url": "https://www.figma.com/api/mcp/asset/a409abac-47ed-40c8-8b35-000e6cb660f5/fac42.svg"
  },
  {
    "path": "game/assets/figma/ba95c.svg",
    "url": "https://www.figma.com/api/mcp/asset/c668d944-5efa-4066-8c9c-9623531dcd8d/ba95c.svg"
  },
  {
    "path": "game/assets/figma/2a735.svg",
    "url": "https://www.figma.com/api/mcp/asset/fb6ce0bd-2a7e-4adf-950b-46191e37410e/2a735.svg"
  },
  {
    "path": "game/assets/figma/4c704.svg",
    "url": "https://www.figma.com/api/mcp/asset/fb6ce0bd-2a7e-4adf-950b-46191e37410e/4c704.svg"
  },
  {
    "path": "game/assets/figma/02422.svg",
    "url": "https://www.figma.com/api/mcp/asset/fb6ce0bd-2a7e-4adf-950b-46191e37410e/02422.svg"
  },
  {
    "path": "game/assets/figma/f1627.svg",
    "url": "https://www.figma.com/api/mcp/asset/fb6ce0bd-2a7e-4adf-950b-46191e37410e/f1627.svg"
  },
  {
    "path": "game/assets/figma/75484.svg",
    "url": "https://www.figma.com/api/mcp/asset/fb6ce0bd-2a7e-4adf-950b-46191e37410e/75484.svg"
  }
]
assets += [
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
