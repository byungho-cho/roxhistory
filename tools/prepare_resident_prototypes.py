"""Two editable prototype variants from the approved existing lightweight hero; no external service."""
import bpy,math,json,hashlib
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[1]
source=root/'art-source/meshy01/meshy01-hero.blend'
out=root/'art-source/resident-prototypes';out.mkdir(parents=True,exist_ok=True)
runtime=root/'game/assets/characters/residents';runtime.mkdir(parents=True,exist_ok=True)
def material(name,color):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.94;return m
def sphere(name,at,size,mat,bone,rig):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,location=at);o=bpy.context.object;o.name=name;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
 # Vertices must be in rig space before assigning existing bone weights.
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 for p in o.data.polygons:p.use_smooth=True
 o.vertex_groups.new(name=bone).add(list(range(len(o.data.vertices))),1,'REPLACE');mod=o.modifiers.new('SharedHumanoidRig','ARMATURE');mod.object=rig;o.parent=rig
 return o

def garment(name,rings,mat,rig):
 # Low-poly hide drape with a gently irregular hem; no modern tailored costume.
 verts=[];faces=[];n=32
 for k,(z,rx,ry) in enumerate(rings):
  for i in range(n):
   a=2*math.pi*i/n;hem=(.022*math.cos(a*7) if k==0 else 0)
   verts.append((rx*math.cos(a),ry*math.sin(a)-.015,z+hem))
 for k in range(len(rings)-1):
  for i in range(n):faces.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.materials.append(mat)
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
 hip=o.vertex_groups.new(name='hips');spine=o.vertex_groups.new(name='spine')
 for i,v in enumerate(verts):
  w=max(0,min(1,(v[2]-1.2)/.35));hip.add([i],1-w,'REPLACE');spine.add([i],w,'REPLACE')
 mod=o.modifiers.new('SharedHumanoidRig','ARMATURE');mod.object=rig;o.parent=rig
 for p in mesh.polygons:p.use_smooth=True
 return o
for kind in ['female','sturdy_male']:
 bpy.ops.wm.open_mainfile(filepath=str(source));hero=bpy.data.objects['Meshy01Hero'];rig=bpy.data.objects['VillagerSkeleton']
 # Keep existing joints, normalized skin weights and UVs; modify only the silhouette.
 for v in hero.data.vertices:
  x,y,z=v.co
  head=max(0,min(1,(z-1.84)/.20));body=max(0,1-abs(z-1.4)/.65)
  width=(1.0+.38*body) if kind=='sturdy_male' else (1.0-.04*body)
  v.co.x=x*width*(1-.13*head);v.co.y=y*(1+.24*body if kind=='sturdy_male' else 1)*(1-.10*head)
  if z>1.95:v.co.z=1.95+(z-1.95)*.91
  # Remove the hero's high spiked topknot silhouette from both adult variants.
  if z>2.48:v.co.z=2.48+(z-2.48)*.16
 hair=material('Warm brown hair',(0.075,.033,.018));fur=material('Ochre hide',(0.47,.25,.09));rope=material('Flax rope',(.63,.43,.19))
 cream=material('Warm pale hide',(.64,.48,.27));sage=material('Muted moss hide',(.22,.31,.14))
 sphere('AdultHairCap',(0,.025,2.48),(.37,.30,.22),hair,'head',rig)
 for j in range(5):
  strand=sphere('SweptHair_%d'%j,(-.24+j*.12,-.10,2.59),(.10,.24,.065),hair,'head',rig)
 if kind=='female':
  sphere('LowBun',(0,.28,2.38),(.20,.18,.19),hair,'head',rig)
  for side in [-1,1]:
   sphere('SideHair',(.29*side,.035,2.24),(.10,.23,.27),hair,'head',rig)
  for i in range(9):
   sphere('Braid_%02d'%i,(.32+math.sin(i*1.8)*.028,-.23,2.18-i*.085),(.083,.075,.078),hair,'head' if i<3 else 'spine',rig)
  sphere('BraidTie',(.32,-.23,1.49),(.065,.06,.035),rope,'spine',rig)
  garment('LongForagerHide',[(.62,.50,.36),(.95,.40,.30),(1.2,.28,.225),(1.56,.32,.24),(1.74,.27,.21)],sage,rig)
  garment('HideHem',[(.62,.507,.367),(.70,.48,.35)],cream,rig)
  garment('TiedBelt',[(1.17,.30,.24),(1.23,.30,.24)],rope,rig)
 else:
  sphere('Beard', (0,-.27,2.02),(.21,.10,.12),hair,'head',rig)
  for side in [-1,1]:sphere('Sideburn',(.24*side,-.10,2.20),(.055,.065,.16),hair,'head',rig)
  garment('BuilderVest',[(1.15,.38,.28),(1.45,.43,.30),(1.72,.43,.26),(1.80,.34,.23)],cream,rig)
  garment('WideHideBelt',[(1.12,.40,.29),(1.23,.41,.29)],fur,rig)
  garment('BuilderApron',[(.82,.41,.28),(1.12,.39,.28)],fur,rig)
 # Join into one skinned mesh, retaining material and vertex-group assignments.
 bpy.ops.object.select_all(action='DESELECT')
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 for o in meshes:o.select_set(True)
 bpy.context.view_layer.objects.active=hero;bpy.ops.object.join();hero.name='Resident_'+kind
 bpy.context.preferences.filepaths.save_version=0
 bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(out/(kind+'.blend')))
 # Editable source stays full resolution. Runtime residents have a smaller
 # budget than the hero and retain the same rig/weights after simplification.
 triangles=sum(len(p.vertices)-2 for p in hero.data.polygons)
 dec=hero.modifiers.new('Mobile resident budget','DECIMATE');dec.ratio=min(1,16000/triangles)
 bpy.context.view_layer.objects.active=hero;bpy.ops.object.modifier_apply(modifier=dec.name)
 for img in bpy.data.images:
  if img.size[0]>1024 or img.size[1]>1024:img.scale(1024,1024)
 bpy.ops.export_scene.gltf(filepath=str(runtime/(kind+'.glb')),export_format='GLB',export_animations=False,export_skins=True,export_yup=True)
 print('PROTOTYPE',kind,'triangles',sum(len(p.vertices)-2 for p in hero.data.polygons))
(out/'provenance.json').write_text(json.dumps({'source':str(source.relative_to(root)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'method':'Existing skinned hero geometry and 15-bone rig reused; silhouette edits and simple weighted hair/garment additions. Trial, not approval-equivalent final residents.','references':['NPC-002','NPC-003'],'external_generation':False,'paid_credits':0,'license':'Inherited user-provided Meshy source; account rights not independently verified.'},indent=2),encoding='utf-8')
