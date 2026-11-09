import bpy, math
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
# Comparison uses exported runtime meshes, equal scale, no changes to approved source.
for filename,x,angle in [(root/'game/assets/characters/meshy01/hero.glb',-2.5,0),(out/'woodcutter-study.glb',0,0),(out/'woodcutter-study.glb',2.5,math.pi*.55)]:
 old=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(filename));new=set(bpy.data.objects)-old
 pivot=bpy.data.objects.new('ComparisonPivot',None);bpy.context.collection.objects.link(pivot)
 for ob in new:
  if ob.parent is None:ob.parent=pivot
 pivot.location.x=x;pivot.rotation_euler.z=angle
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=48;scene.cycles.use_denoising=False
scene.render.resolution_x=1500;scene.render.resolution_y=700;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('StudioWorld');scene.world.color=(.7,.7,.7)
# neutral cream floor and soft light
m=bpy.data.materials.new('Studio cream');m.diffuse_color=(.67,.62,.51,1)
bpy.ops.mesh.primitive_plane_add(size=200);bpy.context.object.data.materials.append(m)
for pos,power,size in [((-3,-4,7),450,5),((4,0,5),220,4)]:
 bpy.ops.object.light_add(type='AREA',location=pos);lamp=bpy.context.object;lamp.data.energy=power;lamp.data.shape='DISK';lamp.data.size=size;lamp.rotation_euler=(Vector((0,0,1.5))-lamp.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(0,-11,5));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1.45))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=8.6;scene.camera=cam
scene.view_settings.view_transform='Standard';scene.render.image_settings.file_format='PNG';scene.render.filepath=str(out/'model-comparison.png');bpy.ops.render.render(write_still=True)
scene.render.resolution_x=960;scene.render.resolution_y=540;cam.data.ortho_scale=26;scene.render.filepath=str(out/'scale-study-approx-110px.png');bpy.ops.render.render(write_still=True)
