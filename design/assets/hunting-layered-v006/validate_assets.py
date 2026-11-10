from pathlib import Path
import hashlib, json, xml.etree.ElementTree as ET
from PIL import Image
root=Path(__file__).resolve().parent
repo=root.parents[2]
m=json.loads((root/'asset-manifest.json').read_text())
for e in m['files']:
 p=root/e['path'];b=p.read_bytes()
 assert b and len(b)==e['bytes'],e['path']
 assert hashlib.sha256(b).hexdigest()==e['sha256'],e['path']
 if p.suffix=='.png':
  with Image.open(p) as im:
   im.load();assert list(im.size)==e['pixels'],e['path']
 elif p.suffix=='.svg':ET.fromstring(b)
 elif p.suffix=='.json':json.loads(b)
a=json.loads((root/'asset-bindings.json').read_text())
for e in a['resources']:
 p=repo/e['repo_path'];b=p.read_bytes()
 assert hashlib.sha1(b).hexdigest()==e['figma_image_hash'],e['repo_path']
 assert hashlib.sha256(b).hexdigest()==e['sha256'],e['repo_path']
for e in a['image_layers']:assert (repo/e['repo_path']).is_file(),e['repo_path']
for kind in ['preparation','battle']:
 j=json.loads((root/'layout'/f'{kind}.json').read_text());s=j['scene']
 assert [s['width'],s['height']]==[1920,1080]
 if kind=='battle':
  def flatten(n):
   yield n
   for c in n.get('children',[]):yield from flatten(c)
  nodes=list(flatten(s));ids={n['id'] for n in nodes}
  assert '2139:180'in ids and '2139:175'in ids
  assert '2133:844'not in ids,'Obsolete duplicate party HP fill'
  assert not any(n.get('characters')=='사냥대'for n in nodes)
print(json.dumps({'files_verified':len(m['files']),'image_layers_resolved':len(a['image_layers']),'source_images_verified':len(a['resources']),'game_tests':'not_run_asset_only'},ensure_ascii=False))
