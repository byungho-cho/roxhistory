import bpy,math
from pathlib import Path
out=Path(__file__).resolve().parent
# Separate static prop assets, origin at resident spine attachment point.
def mat(n,c):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);return m
for kind in ['wood','stone','grain']:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 wood=mat('bark',(.24,.10,.035));cut=mat('cut wood',(.48,.27,.10));cord=mat('fiber',(.46,.31,.14));rock=mat('stone',(.27,.30,.28));grain=mat('grain',(.58,.37,.06))
 if kind=='wood':
  for z,y in [(-.10,.02),(.04,.02),(-.03,.15)]:
   bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.085,depth=.68,location=(0,y,z),rotation=(0,math.pi/2,0));bpy.context.object.data.materials.append(wood)
   for x in [-.342,.342]:
    bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.078,depth=.005,location=(x,y,z),rotation=(0,math.pi/2,0));bpy.context.object.data.materials.append(cut)
  for x in [-.20,.20]:
   bpy.ops.mesh.primitive_torus_add(major_radius=.13,minor_radius=.015,major_segments=12,minor_segments=6,location=(x,.07,-.03),rotation=(0,math.pi/2,0));bpy.context.object.data.materials.append(cord)
 else:
  bpy.ops.mesh.primitive_cone_add(vertices=16,radius1=.15,radius2=.21,depth=.30,location=(0,0,-.09));bpy.context.object.data.materials.append(wood)
  for z in [-.21,-.13,-.05,.04]:
   bpy.ops.mesh.primitive_torus_add(major_radius=.17+(z+.21)*.13,minor_radius=.013,major_segments=16,minor_segments=6,location=(0,0,z));bpy.context.object.data.materials.append(cord)
  for i in range(7):
   x=.12*math.cos(i*2.4);y=.12*math.sin(i*2.4)
   if kind=='stone':
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.10,location=(x,y,.05+(i%2)*.045));bpy.context.object.scale=(1,.8,.7);bpy.context.object.data.materials.append(rock)
   else:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,radius=1,location=(x,y,.06));bpy.context.object.scale=(.045,.045,.15);bpy.context.object.rotation_euler=(.3*math.cos(i),.3*math.sin(i),0);bpy.context.object.data.materials.append(grain)
 bpy.ops.export_scene.gltf(filepath=str(out/('carry-'+kind+'-blockout.glb')),export_format='GLB')
