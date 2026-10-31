"""Blender 4.5: preserve supplied Meshy appearance, simplify, bind and export.
Run: blender --background --python tools/prepare_meshy_hero.py -- input.glb output_dir
The original GLB is never modified. All weights and joint locations remain editable.
"""
import bpy, sys, json, math, hashlib
from pathlib import Path
from mathutils import Vector

args=sys.argv[sys.argv.index('--')+1:]
source=Path(args[0]); out=Path(args[1]); out.mkdir(parents=True,exist_ok=True)
if '--reuse' in args and (out/'meshy01-hero.blend').exists():
 bpy.ops.wm.open_mainfile(filepath=str(out/'meshy01-hero.blend'))
 hero=bpy.data.objects['Meshy01Hero'];hero.parent=None
 for modifier in list(hero.modifiers):hero.modifiers.remove(modifier)
 hero.vertex_groups.clear()
 for obj in list(bpy.data.objects):
  if obj.type=='ARMATURE':bpy.data.objects.remove(obj,do_unlink=True)
 original_triangles=json.loads((out/'model-provenance.json').read_text())['original_triangles']
else:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(source))
 objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
 points=[o.matrix_world@Vector(v) for o in objects for v in o.bound_box]
 lo=Vector([min(p[i] for p in points) for i in range(3)])
 hi=Vector([max(p[i] for p in points) for i in range(3)])
 factor=3/(hi.z-lo.z)
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:
  o.select_set(True);o.matrix_world.translation-=Vector(((hi.x+lo.x)/2,(hi.y+lo.y)/2,lo.z))
  o.matrix_world.translation*=factor;o.scale*=factor
 bpy.context.view_layer.objects.active=objects[0]
 bpy.ops.object.join();hero=bpy.context.object;hero.name='Meshy01Hero'
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 original_triangles=sum(len(p.vertices)-2 for p in hero.data.polygons)
 dec=hero.modifiers.new('Mobile silhouette-preserving reduction','DECIMATE');dec.ratio=60000/original_triangles
 bpy.ops.object.modifier_apply(modifier=dec.name)
for poly in hero.data.polygons:poly.use_smooth=True
for mat in hero.data.materials:
 if not mat or not mat.use_nodes:continue
 for node in mat.node_tree.nodes:
  if node.type=='BSDF_PRINCIPLED':
   for key,value in [('Roughness',.92),('Metallic',0),('Specular IOR Level',.12)]:
    for link in list(node.inputs[key].links):mat.node_tree.links.remove(link)
    node.inputs[key].default_value=value
  elif node.type=='NORMAL_MAP':node.inputs['Strength'].default_value=.22

# Coordinates use the game convention (X right, Y up, Z forward).
joints={'hips':('',(0,1.10,0)), 'spine':('hips',(0,1.50,0)), 'head':('spine',(0,1.92,0))}
for side,suffix in [(-1,'L'),(1,'R')]:
 joints.update({
  'arm'+suffix:('spine',(side*.34,1.78,0)),
  'forearm'+suffix:('arm'+suffix,(side*.48,1.47,0)),
  'hand'+suffix:('forearm'+suffix,(side*.58,1.12,.04)),
  'thigh'+suffix:('hips',(side*.25,1.06,0)),
  'shin'+suffix:('thigh'+suffix,(side*.25,.72,0)),
  'foot'+suffix:('shin'+suffix,(side*.25,.22,0))})
def blender_point(p):return Vector((p[0],-p[2],p[1]))
arm=bpy.data.armatures.new('RoxHistoryHumanoid15');rig=bpy.data.objects.new('VillagerSkeleton',arm);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
for name,(parent,point) in joints.items():
 bone=arm.edit_bones.new(name);bone.head=blender_point(point)
 child=next((p for n,(par,p) in joints.items() if par==name),None)
 bone.tail=blender_point(child) if child else bone.head+Vector((0,0,.18))
 if name=='hips':bone.tail=blender_point(joints['spine'][1])
 if name=='spine':bone.tail=blender_point(joints['head'][1])
 if name=='head':bone.tail=Vector((0,0,2.85))
 if parent:bone.parent=arm.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
groups={name:hero.vertex_groups.new(name=name) for name in joints}
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def blend(a,b,t):return {a:1-t,b:t}
def arm_bounds(y):
 knots=[(.8,.42,.46),(.95,.42,.52),(1,.425,.465),(1.1,.415,.465),(1.2,.38,.47),(1.3,.34,.40),(1.4,.24,.38),(1.5,.24,.46),(1.7,.25,.43),(1.85,.30,.46)]
 for a,b in zip(knots,knots[1:]):
  if y<=b[0]:
   t=max(0,min(1,(y-a[0])/(b[0]-a[0])));return a[1]*(1-t)+b[1]*t,a[2]*(1-t)+b[2]*t
 return knots[-1][1:]
for vertex in hero.data.vertices:
 x,_,y=vertex.co;ax=abs(x);suffix='L' if x<0 else 'R'
 arm_boundary,arm_outer=arm_bounds(y)
 if y>=1.98:weights={'head':1}
 elif y>1.84:weights=blend('spine','head',smooth(1.84,1.98,y))
 elif ax>arm_boundary and y>.80:
  if y>1.57:limb={'arm'+suffix:1}
  elif y>1.37:limb=blend('arm'+suffix,'forearm'+suffix,1-smooth(1.37,1.57,y))
  elif y>1.13:limb=blend('hand'+suffix,'forearm'+suffix,smooth(1.13,1.28,y))
  else:limb={'hand'+suffix:1}
  influence=smooth(arm_boundary,arm_outer,ax)
  weights={k:v*influence for k,v in limb.items()};weights['spine']=1-influence
 elif y>1.15:weights=blend('hips','spine',smooth(1.15,1.43,y))
 elif y>1.02:weights=blend('thigh'+suffix,'hips',smooth(1.02,1.15,y))
 elif y>.82:weights={'thigh'+suffix:1}
 elif y>.62:weights=blend('shin'+suffix,'thigh'+suffix,smooth(.62,.82,y))
 else:weights=blend('foot'+suffix,'shin'+suffix,smooth(.34,.49,y))
 for name,weight in weights.items():
  if weight>1e-6:groups[name].add([vertex.index],weight,'REPLACE')
# Smooth on welded spatial vertices: UV/normal seams receive identical weights.
# This removes narrow transition spikes without erasing the original silhouette.
keys={}; vertex_keys=[]; groups_by_position=[]; values=[]
for v in hero.data.vertices:
 key=tuple(round(c,5) for c in v.co)
 if key not in keys:
  keys[key]=len(values);groups_by_position.append([])
  values.append({g.group:g.weight for g in v.groups})
 index=keys[key];vertex_keys.append(index);groups_by_position[index].append(v.index)
neighbors=[set() for _ in values]
for edge in hero.data.edges:
 a,b=(vertex_keys[i] for i in edge.vertices)
 if a!=b:neighbors[a].add(b);neighbors[b].add(a)
for iteration in range(4):
 result=[]
 for index,weights in enumerate(values):
  linked=neighbors[index]
  if not linked:result.append(weights);continue
  mixed={k:v*.6 for k,v in weights.items()}
  for neighbor in linked:
   for k,v in values[neighbor].items():mixed[k]=mixed.get(k,0)+v*.4/len(linked)
  strongest=sorted(mixed.items(),key=lambda pair:pair[1],reverse=True)[:4]
  total=sum(v for k,v in strongest);result.append({k:v/total for k,v in strongest if v>1e-6})
 values=result
hero.vertex_groups.clear()
ordered=[hero.vertex_groups.new(name=name) for name in joints]
for index,weights in enumerate(values):
 for group,weight in weights.items():ordered[group].add(groups_by_position[index],weight,'REPLACE')
modifier=hero.modifiers.new('Humanoid deformation','ARMATURE');modifier.object=rig
hero.parent=rig
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(out/'meshy01-hero.blend'))
bpy.ops.export_scene.gltf(filepath=str(out/'meshy01-hero.glb'),export_format='GLB',export_animations=False,export_skins=True,export_yup=True,export_apply=False)
stats={'source':source.name,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'original_triangles':original_triangles,'triangles':sum(len(p.vertices)-2 for p in hero.data.polygons),'vertices':len(hero.data.vertices),'bones':len(joints),'height':3,'material':{'roughness':.92,'specular':.12,'normal_strength':.22},'joints':joints,'license':'User-provided Meshy asset; account-specific commercial/export rights not independently verified.'}
(out/'model-provenance.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
print('HERO_EXPORT',json.dumps(stats))
