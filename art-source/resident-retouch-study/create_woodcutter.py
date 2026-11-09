import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
source=root/'art-source/meshy01/meshy01-hero.blend'
original_hash=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source));hero=bpy.data.objects['Meshy01Hero'];rig=bpy.data.objects['VillagerSkeleton']
# Retain skinning and skeleton rest transforms. Adult proportions, no hero topknot.
for v in hero.data.vertices:
 x,y,z=v.co
 head=max(0,min(1,(z-1.88)/.22));torso=max(0,1-abs(z-1.48)/.43)
 v.co.x=x*(1-.13*head+.10*torso)
 v.co.y=y*(1-.10*head)
 if z>1.95:v.co.z=1.95+(z-1.95)*.86
 if v.co.z>2.43:v.co.z=2.43+(v.co.z-2.43)*.16
# Existing helper mesh creation retains weighted bone attachments.
def mat(name,c):
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=.9;return m
def ellipsoid(name,loc,scale,m,bone='head',rotation=(0,0,0)):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=10,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;o.rotation_euler=rotation
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);o.data.materials.append(m)
 for p in o.data.polygons:p.use_smooth=True
 o.vertex_groups.new(name=bone).add(list(range(len(o.data.vertices))),1,'REPLACE');o.modifiers.new('SharedHumanoidRig','ARMATURE').object=rig;o.parent=rig
 return o
hair=mat('Woodcutter warm chestnut hair',(.035,.009,.003));hairlight=mat('Woodcutter hair highlights',(.075,.023,.008));rope=mat('Flax cord',(.48,.29,.105))
ellipsoid('LowCrownFill',(0,.025,2.42),(.25,.23,.105),hair)
for i in range(5):
 ellipsoid('CrownLock'+str(i),(-.16+i*.08,0,2.50),(.09,.22,.05),hair,rotation=(0,-.15,-.3))
# Low swept nape rather than protagonist's high spiky bun.
ellipsoid('LowNapeHair',(0,.21,2.23),(.235,.145,.19),hair)
for s in (-1,1):ellipsoid('SideHair',(.275*s,-.005,2.22),(.065,.145,.16),hair)
# Replace the hero clothing and boots rather than recoloring them.
import bmesh
bm=bmesh.new();bm.from_mesh(hero.data)
bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z<1.94],context='VERTS');bm.to_mesh(hero.data);bm.free()
skin=mat('Resident warm skin',(.72,.32,.12));hide=mat('Worn ochre plain hide',(.28,.115,.035));trim=mat('Pale rawhide binding',(.49,.30,.13))
def surface(name,rings,material,weights):
 verts=[];faces=[];n=32
 for k,ring in enumerate(rings):
  cx,cy,z,rx,ry=ring
  for i in range(n):
   a=i*2*math.pi/n;zz=z(a) if callable(z) else z
   verts.append((cx+rx*math.cos(a),cy+ry*math.sin(a),zz))
 for k in range(len(rings)-1):
  for i in range(n):faces.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
 faces.append(tuple(range(n-1,-1,-1)));faces.append(tuple((len(rings)-1)*n+i for i in range(n)))
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.materials.append(material);o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
 groups={b:o.vertex_groups.new(name=b) for b in rig.data.bones.keys()}
 for i,v in enumerate(verts):
  for b,w in weights(v).items():
   if w>0:groups[b].add([i],w,'REPLACE')
 for p in me.polygons:p.use_smooth=True
 o.modifiers.new('SharedHumanoidRig','ARMATURE').object=rig;o.parent=rig
 return o

def torso_weights(v):
 t=max(0,min(1,(v[2]-1.15)/.35));return {'hips':1-t,'spine':t}
surface('AdultTorso',[(0,0,1.02,.24,.14),(0,0,1.22,.25,.15),(0,0,1.48,.32,.17),(0,0,1.71,.36,.16),(0,0,1.80,.29,.14),(0,0,1.87,.12,.10),(0,0,1.99,.12,.11)],skin,torso_weights)
for side,suffix in [(-1,'L'),(1,'R')]:
 def arm_weights(v,suffix=suffix):
  z=v[2]
  if z>1.55:return {'arm'+suffix:1}
  if z>1.37:
   t=(z-1.37)/.18;return {'arm'+suffix:t,'forearm'+suffix:1-t}
  if z>1.15:return {'forearm'+suffix:1}
  return {'hand'+suffix:1}
 ellipsoid('Shoulder'+suffix,(side*.33,0,1.72),(.145,.145,.15),skin,'arm'+suffix)
 surface('BareArm'+suffix,[(side*.33,0,1.78,.14,.14),(side*.41,0,1.65,.135,.13),(side*.48,0,1.47,.105,.105),(side*.53,0,1.29,.09,.09),(side*.58,-.04,1.12,.067,.065)],skin,arm_weights)
 ellipsoid('BareHand'+suffix,(side*.59,-.035,1.04),(.075,.065,.12),skin,'hand'+suffix)
 for i in range(4):ellipsoid('Finger'+suffix+str(i),(side*(.54+i*.032),-.045,.96),(.021,.03,.07),skin,'hand'+suffix)
 ellipsoid('Thumb'+suffix,(side*.50,-.04,1.035),(.035,.04,.065),skin,'hand'+suffix,rotation=(0,side*.45,0))
 def leg_weights(v,suffix=suffix):
  z=v[2]
  if z>.82:return {'thigh'+suffix:1}
  if z>.62:
   t=(z-.62)/.20;return {'thigh'+suffix:t,'shin'+suffix:1-t}
  if z>.30:return {'shin'+suffix:1}
  return {'foot'+suffix:1}
 surface('BareLeg'+suffix,[(side*.22,0,1.0,.10,.10),(side*.25,0,.90,.135,.13),(side*.25,0,.72,.10,.105),(side*.25,0,.51,.10,.10),(side*.25,0,.17,.065,.07)],skin,leg_weights)
 ellipsoid('BareFoot'+suffix,(side*.25,-.08,.09),(.115,.21,.09),skin,'foot'+suffix)
 for i in range(5):ellipsoid('Toe'+suffix+str(i),(side*.25-.075+i*.037,-.24,.065),(.025,.055-.004*i,.035),skin,'foot'+suffix)
# Weld new anatomy pieces only; do not remesh the original face or cloth.
from mathutils.kdtree import KDTree
parts=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m==skin for m in o.data.materials)]
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();body=bpy.context.object;body.name='ResidentConnectedAnatomy'
for mod in list(body.modifiers):body.modifiers.remove(mod)
oldgroups={g.index:g.name for g in body.vertex_groups}
oldweights=[{oldgroups[g.group]:g.weight for g in v.groups} for v in body.data.vertices]
kd=KDTree(len(body.data.vertices))
for i,v in enumerate(body.data.vertices):kd.insert(v.co,i)
kd.balance()
rem=body.modifiers.new('Weld shoulders hands and ankles','REMESH');rem.mode='VOXEL';rem.voxel_size=.018;rem.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=rem.name)
sm=body.modifiers.new('Organic joint transitions','SMOOTH');sm.factor=.8;sm.iterations=4;bpy.ops.object.modifier_apply(modifier=sm.name)
body.vertex_groups.clear();vg={b:body.vertex_groups.new(name=b) for b in rig.data.bones.keys()}
for v in body.data.vertices:
 weights={}
 for co,i,d in kd.find_n(v.co,4):
  influence=1/max(d,.002)
  for b,w in oldweights[i].items():weights[b]=weights.get(b,0)+w*influence
 total=sum(weights.values())
 if total:
  for b,w in weights.items():vg[b].add([v.index],w/total,'REPLACE')
body.modifiers.new('SharedHumanoidRig','ARMATURE').object=rig;body.parent=rig

# Unadorned one-shoulder worker's hide: no fur cape, boots or wrist guards.
surface('WorkerOneShoulderHide',[(0,0,lambda a:.78+.045*math.sin(a*7),.43,.23),(0,0,1.00,.36,.205),(0,0,1.12,.29,.175),(0,0,1.42,.335,.19),(0,0,lambda a:1.68+.15*math.cos(a),.35,.18)],hide,torso_weights)
surface('ShoulderRawhideEdge',[(0,0,lambda a:1.64+.15*math.cos(a),.355,.185),(0,0,lambda a:1.68+.15*math.cos(a),.355,.185)],trim,torso_weights)
surface('SimpleCordBelt',[(0,0,1.13,.302,.19),(0,0,1.16,.302,.19)],rope,torso_weights)
ellipsoid('BeltKnot',(.07,-.195,1.14),(.055,.025,.04),rope,'hips')

# Small pendant, not a heroic head ornament.
ellipsoid('WoodPendant',(0,-.18,1.68),(.055,.025,.065),rope,'spine')
# Merge new hair into skinned body, preserve rest pose and all bone weights.
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:
 if o.type=='MESH':o.select_set(True)
bpy.context.view_layer.objects.active=hero;bpy.ops.object.join();hero.name='Resident_Woodcutter_Study'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(out/'woodcutter-study.blend'))
tri=sum(len(p.vertices)-2 for p in hero.data.polygons);dec=hero.modifiers.new('Resident mobile budget','DECIMATE');dec.ratio=1.0;bpy.ops.object.modifier_apply(modifier=dec.name)
for im in bpy.data.images:
 if im.size[0]>1024 or im.size[1]>1024:im.scale(1024,1024)
bpy.ops.export_scene.gltf(filepath=str(out/'woodcutter-study.glb'),export_format='GLB',export_animations=False,export_skins=True,export_yup=True)
(out/'provenance.json').write_text(json.dumps({'status':'unapproved 3D reuse study; not installed in game','source':str(source.relative_to(root)),'source_sha256':original_hash,'base_commit':'a1f149f','reference':'Figma 1161:12 B simple 2D (woodcutter)','scope':'v3 keeps v2 hair blockout; connected anatomy remeshed with reprojected skin weights. Rejected stretched rear ponytail experiment retained separately.','bones':[b.name for b in rig.data.bones],'optimization':'Full reference topology retained in study because 16k decimation produced visible UV seam cracks; mobile optimization pending','triangles':sum(len(p.vertices)-2 for p in hero.data.polygons),'hero_unchanged':hashlib.sha256(source.read_bytes()).hexdigest()==original_hash},indent=2))
print('STUDY_EXPORTED')
