"""Insert the already-designed concept slide while preserving the existing deck."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import copy
import xml.etree.ElementTree as ET
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
P = "http://schemas.openxmlformats.org/presentationml/2006/main"
A = "http://schemas.openxmlformats.org/drawingml/2006/main"
R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
PKG = "http://schemas.openxmlformats.org/package/2006/relationships"
CT = "http://schemas.openxmlformats.org/package/2006/content-types"
NS = {"p":P,"a":A,"r":R,"pkg":PKG}
for prefix, uri in [("p",P),("a",A),("r",R)]:
    ET.register_namespace(prefix, uri)

def xml(value):
    return ET.tostring(value,encoding="utf-8",xml_declaration=True)

def named_text(data, name, value):
    tree = ET.fromstring(data)
    for shape in tree.findall(".//p:sp",NS):
        props = shape.find("p:nvSpPr/p:cNvPr",NS)
        if props is not None and props.get("name") == name:
            texts = shape.findall(".//a:t",NS)
            if not texts:
                raise ValueError("Missing text in " + name)
            texts[0].text = value
            for text in texts[1:]:
                text.text = ""
            return xml(tree)
    raise ValueError("Named text shape not found: " + name)

def text_shape(parent, ident, name, value, x, y, width, height, size, color, bold=False):
    shape=ET.SubElement(parent,"{"+P+"}sp")
    nv=ET.SubElement(shape,"{"+P+"}nvSpPr")
    ET.SubElement(nv,"{"+P+"}cNvPr",id=str(ident),name=name)
    ET.SubElement(nv,"{"+P+"}cNvSpPr",txBox="1")
    ET.SubElement(nv,"{"+P+"}nvPr")
    props=ET.SubElement(shape,"{"+P+"}spPr")
    transform=ET.SubElement(props,"{"+A+"}xfrm")
    ET.SubElement(transform,"{"+A+"}off",x=str(round(x*9525)),y=str(round(y*9525)))
    ET.SubElement(transform,"{"+A+"}ext",cx=str(round(width*9525)),cy=str(round(height*9525)))
    geom=ET.SubElement(props,"{"+A+"}prstGeom",prst="rect")
    ET.SubElement(geom,"{"+A+"}avLst")
    ET.SubElement(props,"{"+A+"}noFill")
    line=ET.SubElement(props,"{"+A+"}ln")
    ET.SubElement(line,"{"+A+"}noFill")
    body=ET.SubElement(shape,"{"+P+"}txBody")
    ET.SubElement(body,"{"+A+"}bodyPr",wrap="square",lIns="0",rIns="0",tIns="0",bIns="0",anchor="t")
    ET.SubElement(body,"{"+A+"}lstStyle")
    paragraph=ET.SubElement(body,"{"+A+"}p")
    run=ET.SubElement(paragraph,"{"+A+"}r")
    attrs={"lang":"ko-KR","sz":str(round(size*75))}
    if bold: attrs["b"]="1"
    rpr=ET.SubElement(run,"{"+A+"}rPr",attrs)
    fill=ET.SubElement(rpr,"{"+A+"}solidFill")
    ET.SubElement(fill,"{"+A+"}srgbClr",val=color)
    ET.SubElement(rpr,"{"+A+"}latin",typeface="Malgun Gothic")
    ET.SubElement(rpr,"{"+A+"}ea",typeface="Malgun Gothic")
    ET.SubElement(run,"{"+A+"}t").text=value
    ET.SubElement(paragraph,"{"+A+"}endParaRPr",lang="ko-KR",sz=str(round(size*75)))
    return shape

target=ROOT/"presentations/RoxHistory_Overview_v0.1.pptx"
asset=ROOT/"assets/visual-direction-1-enhanced.png"
with ZipFile(target) as archive:
    parts={item.filename:archive.read(item.filename) for item in archive.infolist()}
presentation=ET.fromstring(parts["ppt/presentation.xml"])
slide_ids=presentation.find("p:sldIdLst",NS)
if "ppt/media/visual-direction-1-enhanced.png" in parts:
    if len(slide_ids)!=11: raise ValueError("Existing enhanced deck has unexpected slide count")
    print("Concept slide already inserted; preserving existing file")
    raise SystemExit(0)
if len(slide_ids)!=10: raise ValueError("Expected the 10-slide source deck")
slide_size=presentation.find("p:sldSz",NS)
assert (int(slide_size.get("cx")),int(slide_size.get("cy")))==(12192000,6858000)
relations=ET.fromstring(parts["ppt/_rels/presentation.xml.rels"])
rel_map={r.get("Id"):r.get("Target") for r in relations}
last_target=rel_map[slide_ids[-1].get("{"+R+"}id")]
previous_last="ppt/"+last_target if not last_target.startswith("/") else last_target.lstrip("/")
nine_target=rel_map[slide_ids[8].get("{"+R+"}id")]
previous_nine="ppt/"+nine_target if not nine_target.startswith("/") else nine_target.lstrip("/")
parts[previous_nine]=named_text(parts[previous_nine],"title","기본 비주얼 방향")
parts[previous_nine]=named_text(parts[previous_nine],"subtitle","1안의 아기자기한 2.5D를 전체 디자인의 기준으로 사용한다")
parts[previous_last]=named_text(parts[previous_last],"page","11")

new_slide_path="ppt/slides/slide11.xml"
new_notes_path="ppt/notesSlides/notesSlide11.xml"
assert new_slide_path not in parts
slide=ET.Element("{"+P+"}sld")
common=ET.SubElement(slide,"{"+P+"}cSld",name="1안 기반 비주얼 보강 시안")
bg=ET.SubElement(common,"{"+P+"}bg")
bgpr=ET.SubElement(bg,"{"+P+"}bgPr")
ET.SubElement(ET.SubElement(bgpr,"{"+A+"}solidFill"),"{"+A+"}srgbClr",val="FCFBF8")
ET.SubElement(bgpr,"{"+A+"}effectLst")
tree=ET.SubElement(common,"{"+P+"}spTree")
nv=ET.SubElement(tree,"{"+P+"}nvGrpSpPr")
ET.SubElement(nv,"{"+P+"}cNvPr",id="1",name="")
ET.SubElement(nv,"{"+P+"}cNvGrpSpPr")
ET.SubElement(nv,"{"+P+"}nvPr")
group=ET.SubElement(tree,"{"+P+"}grpSpPr")
transform=ET.SubElement(group,"{"+A+"}xfrm")
for tag,attrs in [("off",{"x":"0","y":"0"}),("ext",{"cx":"0","cy":"0"}),("chOff",{"x":"0","y":"0"}),("chExt",{"cx":"0","cy":"0"})]:
    ET.SubElement(transform,"{"+A+"}"+tag,attrs)
text_shape(tree,2,"title","1안 기반 비주얼 보강 시안",72,28,1136,62,42,"222B38",True)
with Image.open(asset) as image:
    width,height=image.size
display_height=520
display_width=display_height*width/height
picture=ET.SubElement(tree,"{"+P+"}pic")
nv=ET.SubElement(picture,"{"+P+"}nvPicPr")
ET.SubElement(nv,"{"+P+"}cNvPr",id="3",name="visual-direction-1-enhanced",descr="1안을 기준으로 자연광, 배경 깊이, 재질과 사냥 동작을 보강한 검토용 생성 이미지")
locks=ET.SubElement(nv,"{"+P+"}cNvPicPr")
ET.SubElement(locks,"{"+A+"}picLocks",noChangeAspect="1")
ET.SubElement(nv,"{"+P+"}nvPr")
blip=ET.SubElement(picture,"{"+P+"}blipFill")
ET.SubElement(blip,"{"+A+"}blip",{"{"+R+"}embed":"rIdConceptImage"})
ET.SubElement(ET.SubElement(blip,"{"+A+"}stretch"),"{"+A+"}fillRect")
props=ET.SubElement(picture,"{"+P+"}spPr")
transform=ET.SubElement(props,"{"+A+"}xfrm")
ET.SubElement(transform,"{"+A+"}off",x=str(round((1280-display_width)/2*9525)),y=str(98*9525))
ET.SubElement(transform,"{"+A+"}ext",cx=str(round(display_width*9525)),cy=str(520*9525))
ET.SubElement(ET.SubElement(props,"{"+A+"}prstGeom",prst="rect"),"{"+A+"}avLst")
text_shape(tree,4,"concept-disclosure","검토용 생성 이미지 · 자연광, 배경 깊이, 사냥 동작 보강",72,628,1136,30,20,"626C79")
text_shape(tree,5,"footer","RoxHistory  /  초기 상세안 검토 기록",72,677,1000,26,16,"626C79")
text_shape(tree,6,"page","10",1160,674,48,30,18,"626C79")
ET.SubElement(ET.SubElement(slide,"{"+P+"}clrMapOvr"),"{"+A+"}masterClrMapping")
parts[new_slide_path]=xml(slide)

last_rel_path="ppt/slides/_rels/"+Path(previous_last).name+".rels"
last_rels=ET.fromstring(parts[last_rel_path])
layout=next(r.get("Target") for r in last_rels if r.get("Type").endswith("/slideLayout"))
new_rels=ET.Element("{"+PKG+"}Relationships")
for ident,kind,dest in [("rIdConceptImage","image","../media/visual-direction-1-enhanced.png"),("rIdLayout","slideLayout",layout),("rIdNotes","notesSlide","../notesSlides/notesSlide11.xml")]:
    ET.SubElement(new_rels,"{"+PKG+"}Relationship",Id=ident,Type=R+"/"+kind,Target=dest)
parts["ppt/slides/_rels/slide11.xml.rels"]=xml(new_rels)
notes=ET.Element("{"+P+"}notes")
ntree=ET.SubElement(ET.SubElement(notes,"{"+P+"}cSld"),"{"+P+"}spTree")
nnv=ET.SubElement(ntree,"{"+P+"}nvGrpSpPr")
ET.SubElement(nnv,"{"+P+"}cNvPr",id="1",name="")
ET.SubElement(nnv,"{"+P+"}cNvGrpSpPr")
ET.SubElement(nnv,"{"+P+"}nvPr")
ET.SubElement(ntree,"{"+P+"}grpSpPr")
text_shape(ntree,2,"Notes","사용자 요청: 전체 스타일은 아기자기한 2.5D 1안으로 사용하고 2안의 자연광, 배경 깊이, 재질 표현과 사냥 동작만 접목한다. 한 화면으로 통합한 시각 검토용 생성 이미지이며 실제 구현 화면이나 고증 승인 자료가 아니다. 화면 속 UI는 이미지 일부다. 원본: assets/visual-direction-1-enhanced.png. 앞선 09장 비교 다음에 추가했으며 기존 마지막 장은 11장으로 이동한다.",0,0,700,500,20,"222B38")
ET.SubElement(ET.SubElement(notes,"{"+P+"}clrMapOvr"),"{"+A+"}masterClrMapping")
parts[new_notes_path]=xml(notes)
note_rels=ET.Element("{"+PKG+"}Relationships")
ET.SubElement(note_rels,"{"+PKG+"}Relationship",Id="rIdSlide",Type=R+"/slide",Target="../slides/slide11.xml")
for part in list(parts):
    if part.startswith("ppt/notesSlides/_rels/") and part.endswith(".rels"):
        old_rels=ET.fromstring(parts[part])
        master=next((r.get("Target") for r in old_rels if r.get("Type").endswith("/notesMaster")),None)
        if master:
            ET.SubElement(note_rels,"{"+PKG+"}Relationship",Id="rIdMaster",Type=R+"/notesMaster",Target=master)
            break
parts["ppt/notesSlides/_rels/notesSlide11.xml.rels"]=xml(note_rels)
parts["ppt/media/visual-direction-1-enhanced.png"]=asset.read_bytes()
rid="rIdVisualConcept"
assert rid not in rel_map
ET.SubElement(relations,"{"+PKG+"}Relationship",Id=rid,Type=R+"/slide",Target="slides/slide11.xml")
new_id=ET.Element("{"+P+"}sldId",{"id":str(max(int(s.get("id")) for s in slide_ids)+1),"{"+R+"}id":rid})
slide_ids.insert(9,new_id)
parts["ppt/presentation.xml"]=xml(presentation)
parts["ppt/_rels/presentation.xml.rels"]=xml(relations)
types=ET.fromstring(parts["[Content_Types].xml"])
for dest,kind in [("/"+new_slide_path,"application/vnd.openxmlformats-officedocument.presentationml.slide+xml"),("/"+new_notes_path,"application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml")]:
    ET.SubElement(types,"{"+CT+"}Override",PartName=dest,ContentType=kind)
if not any(n.get("Extension")=="png" for n in types):
    ET.SubElement(types,"{"+CT+"}Default",Extension="png",ContentType="image/png")
parts["[Content_Types].xml"]=xml(types)
if "docProps/app.xml" in parts:
    app=ET.fromstring(parts["docProps/app.xml"])
    for n in app.iter():
        if n.tag.endswith("}Slides"): n.text="11"
    parts["docProps/app.xml"]=xml(app)
temporary=target.with_suffix(".concept-tmp.pptx")
with ZipFile(temporary,"w",ZIP_DEFLATED) as archive:
    for name,data in parts.items(): archive.writestr(name,data)
temporary.replace(target)
with ZipFile(target) as archive:
    ids=ET.fromstring(archive.read("ppt/presentation.xml")).find("p:sldIdLst",NS)
    assert len(ids)==11
    assert ids[9].get("{"+R+"}id")==rid
    assert archive.read("ppt/media/visual-direction-1-enhanced.png")==asset.read_bytes()
print("PASS inserted concept at page 10; previous final slide moved to 11")
