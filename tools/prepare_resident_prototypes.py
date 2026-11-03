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
 o.vertex_groups.new(name=bone).add(list(range(len(o.data.vertices))),1,'REPLACE');mod=o.modifiers.new('SharedHumanoidRig','ARMATURE');mod.object=rig;o.parent=rig
 return o
for kind in ['female','sturdy_male']:
 bpy.ops.wm.open_mainfile(filepath=str(source));hero=bpy.data.objects['Meshy01Hero'];rig=bpy.data.objects['VillagerSkeleton']
 # Keep existing joints, normalized skin weights and UVs; modify only the silhouette.
 for v in hero.data.vertices:
  x,y,z=v.co
  head=max(0,min(1,(z-1.84)/.20));body=max(0,1-abs(z-1.4)/.65)
  width=(1.0+.28*body) if kind=='sturdy_male' else (1.0-.06*body)
  v.co.x=x*width*(1-.10*head);v.co.y=y*(1+.20*body if kind=='sturdy_male' else 1)
  if z>1.95:v.co.z=1.95+(z-1.95)*.91
  if kind=='female' and z>2.65:v.co.z=2.60+(z-2.65)*.14
 hair=material('Warm brown hair',(0.115,.050,.021));fur=material('Ochre hide',(0.47,.25,.09));rope=material('Flax rope',(.63,.43,.19))
 if kind=='female':
  # Shoulder braid and longer wrap distinguish the female prototype at game size.
  for i in range(7):
   sphere('Braid_%02d'%i,(.36+math.sin(i*1.8)*.035,-.30,2.20-i*.095),(.115,.095,.10),hair,'head' if i<3 else 'spine',rig)
  sphere('BraidTie',(.36,-.30,1.57),(.07,.065,.035),rope,'spine',rig)
  sphere('HideWrap', (0,-.02,1.00),(.40,.25,.34),fur,'hips',rig)
 else:
  sphere('Beard', (0,-.27,2.10),(.21,.09,.10),hair,'head',rig)
  sphere('HideBelt',(0,0,1.18),(.41,.24,.025),rope,'hips',rig)
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
