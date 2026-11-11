#!/usr/bin/env python3
"""Validate this asset-only handoff from any working directory (Python 3 + Pillow)."""
from pathlib import Path
import hashlib,json,sys,xml.etree.ElementTree as ET
from PIL import Image
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[2]
m=json.loads((BASE/'manifest.json').read_text())
errors=[];checked=0;seen={}
def require(condition,message):
 if not condition:errors.append(message)
for a in m['assets']+m['reused']:
 rel=a.get('path',a.get('repo_path')); p=ROOT/rel
 require(p.is_file(),f'Missing {rel}')
 if not p.is_file():continue
 b=p.read_bytes();require(len(b)==a['bytes'],f'Size {rel}');require(hashlib.sha256(b).hexdigest()==a['sha256'],f'Hash {rel}');checked+=1
 if 'format' not in a:continue
 require(a['sha256'] not in seen,f'Duplicate bytes: {rel} and {seen.get(a["sha256"])}');seen[a['sha256']]=rel
 if a['format']=='png':
  im=Image.open(p);im.load();im=im.convert('RGBA')
  require(list(im.size)==a['pixel_size'],f'Pixel size {rel}')
  require(min(im.size)>1,f'Empty export {rel}')
  alpha=im.getchannel('A'); require(alpha.getbbox() is not None,f'No visible pixels {rel}')
  if a['id'] not in ['common/hp-fill-ally','common/hp-fill-enemy']:
   require(alpha.getextrema()[0]==0,f'Missing transparency {rel}')
  if a['id'].endswith('-disabled'):
   pix=im.load();sample=[pix[x,y] for y in range(60,453,4) for x in range(60,453,4) if (x-256)**2+(y-256)**2<195**2 and pix[x,y][3]>200]
   require(all(max(v[:3])-min(v[:3])<=2 for v in sample),f'Disabled interior not gray {rel}')
   rim=[pix[x,y] for y in range(512) for x in range(512) if 225**2<(x-256)**2+(y-256)**2<246**2 and pix[x,y][3]>200]
   require(any(v[0]-v[2]>50 for v in rim),f'Gold rim lost {rel}')
 elif a['format']=='svg':
  xml=ET.fromstring(b);require(xml.tag.endswith('svg'),f'Not SVG {rel}');require('viewBox'in xml.attrib,f'No viewBox {rel}')
  for e in xml.iter():
   require(not e.tag.endswith('script'),f'Script {rel}')
   for key,value in e.attrib.items():
    if key.endswith('href'):require(value.startswith('#'),f'External SVG reference {rel}')
for file in (BASE/'layout').glob('*.json'):json.loads(file.read_text())
for role,rect in m['portrait_regions'].items():
 atlas=Image.open(ROOT/'game/assets/ui/hunting-formation/portraits.png');x,y,w,h=rect
 require(x>=0 and y>=0 and x+w<=atlas.width and y+h<=atlas.height,f'Atlas bounds {role}')
require(len(m['assets'])==37,'Expected 37 latest exports')
print(json.dumps({'checked_asset_references':checked,'png':sum(a['format']=='png'for a in m['assets']),'svg':sum(a['format']=='svg'for a in m['assets']),'errors':errors},ensure_ascii=False,indent=2))
sys.exit(bool(errors))
