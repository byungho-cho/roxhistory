"""Bind the existing mobile Meshy meshes; preserve textures and immutable sources.
Blender --background --python tools/rig_wildlife.py -- REPOSITORY
Joint coordinates and weights are exported to editable .blend files.
"""
import bpy, sys, json, math
from pathlib import Path
from mathutils import Vector

root=Path(sys.argv[sys.argv.index('--')+1])
for species in ['deer','bear','rabbit']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(root/f'game/assets/animals/{species}.glb'))
    mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    bpy.context.view_layer.objects.active=mesh
    mesh.select_set(True)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    pts=[Vector((v.co.x,v.co.z,-v.co.y)) for v in mesh.data.vertices]
    lo=Vector([min(p[i] for p in pts) for i in range(3)])
    hi=Vector([max(p[i] for p in pts) for i in range(3)])
    print('ANATOMY',species,list(lo),list(hi),flush=True)
    # Z is forward in the game's convention. Four limb roots split at torso midline.
    leg_top={'deer':.80,'bear':.65,'rabbit':.42}[species]
    half_x=max(abs(lo.x),hi.x)*.53
    front=hi.z*.52; rear=lo.z*.55
    joints={'body':('',(0,leg_top+.12,0)), 'neck':('body',(0,leg_top+.23,front)),
            'head':('neck',(0,leg_top+.50,front+.12))}
    for side,s in [(-1,'L'),(1,'R')]:
        for z,f in [(front,'F'),(rear,'B')]:
            joints['upper'+f+s]=('body',(side*half_x,leg_top,z))
            joints['lower'+f+s]=('upper'+f+s,(side*half_x,leg_top*.48,z))
            joints['foot'+f+s]=('lower'+f+s,(side*half_x,.08,z+.035))
    def bp(p):return Vector((p[0],-p[2],p[1]))
    arm=bpy.data.armatures.new(species+'Anatomy')
    rig=bpy.data.objects.new(species+'Skeleton',arm);bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
    for name,(parent,p) in joints.items():
        b=arm.edit_bones.new(name);b.head=bp(p);b.tail=b.head+Vector((0,0,.12))
        if parent:b.parent=arm.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    groups={n:mesh.vertex_groups.new(name=n) for n in joints}
    def smooth(a,b,x):
        t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
    for v,p in zip(mesh.data.vertices,pts):
        x,y,z=p
        weights={}
        limb=1-smooth(leg_top*.65,leg_top*1.13,y)
        if limb>.001:
            s='L' if x<0 else 'R';f='F' if z>(front+rear)*.5 else 'B'
            lower=1-smooth(leg_top*.35,leg_top*.70,y)
            foot=1-smooth(.07,.19,y)
            weights['upper'+f+s]=limb*(1-lower)
            weights['lower'+f+s]=limb*lower*(1-foot)
            weights['foot'+f+s]=limb*lower*foot
        head=smooth(front-.10,front+.18,z)*smooth(leg_top*.85,leg_top+0.4,y)*(1-limb)
        weights['neck']=head*.35;weights['head']=head*.65
        weights['body']=max(0,1-limb-head)
        for name,w in weights.items():
            if w>.00001:groups[name].add([v.index],w,'REPLACE')
    modifier=mesh.modifiers.new('Locomotion skin','ARMATURE');modifier.object=rig
    mesh.parent=rig
    out=root/'design/assets/animals-3d/rigged-v001';out.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(out/f'{species}.blend'))
    bpy.ops.export_scene.gltf(filepath=str(root/f'game/assets/animals/{species}-rigged.glb'),export_format='GLB',export_animations=False)
    (out/f'{species}-joints.json').write_text(json.dumps(joints,indent=2))
