"""Blender background: --python tools/prepare_animals.py -- REPOSITORY.

Keep the supplied Meshy originals immutable; generate reproducible mobile copies.
"""
import bpy
import sys
import json
import hashlib
from pathlib import Path
from mathutils import Vector

root = Path(sys.argv[sys.argv.index('--') + 1])
source_dir = root / 'design/assets/animals-3d/reference-v001'
out = root / 'game/assets/animals'
out.mkdir(parents=True, exist_ok=True)
entries = [('bear', 'Meshy_AI_Brown_Bear_1102123404_image-to-3d-texture.glb'),
           ('rabbit', 'Meshy_AI_Bunny_Rabbit_1102125159_image-to-3d-texture.glb'),
           ('deer', 'Meshy_AI_Spotted_Deer_1102125209_image-to-3d-texture.glb')]
report = []
for key, filename in entries:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    source = source_dir / filename
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    original = sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
    bones = sum(len(o.data.bones) for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    actions = len(bpy.data.actions)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes: obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    points = [obj.matrix_world @ v.co for v in obj.data.vertices]
    low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center = Vector(((low.x+high.x)/2, (low.y+high.y)/2, low.z))
    scale = 2.0/(high.z-low.z)
    for v in obj.data.vertices: v.co = (obj.matrix_world @ v.co-center)*scale
    obj.matrix_world.identity()
    decimate = obj.modifiers.new('Mobile silhouette budget', 'DECIMATE')
    decimate.ratio = min(1, 16000/original)
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    for p in obj.data.polygons: p.use_smooth = True
    for image in bpy.data.images:
        if image.size[0] > 1024 or image.size[1] > 1024:
            ratio = 1024/max(image.size)
            image.scale(round(image.size[0]*ratio), round(image.size[1]*ratio))
    for material in bpy.data.materials:
        if not material.use_nodes: continue
        for node in material.node_tree.nodes:
            if node.type == 'BSDF_PRINCIPLED':
                node.inputs['Roughness'].default_value = .93
                node.inputs['Metallic'].default_value = 0
                node.inputs['Specular IOR Level'].default_value = .12
            elif node.type == 'NORMAL_MAP': node.inputs['Strength'].default_value = .18
    obj.name = key
    target = out / (key+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB', export_animations=False)
    report.append(dict(id=key, source=filename, source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                       original_triangles=original, triangles=sum(len(p.vertices)-2 for p in obj.data.polygons),
                       source_bones=bones, source_actions=actions, texture_max=1024,
                       bytes=target.stat().st_size, height=2.0))
    print('ANIMAL_EXPORT', json.dumps(report[-1]), flush=True)
(out/'provenance.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
