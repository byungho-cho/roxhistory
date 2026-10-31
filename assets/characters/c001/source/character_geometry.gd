class_name CharacterGeometry
extends RefCounted

# Editable ring profiles (height, half-width, half-depth), with continuous seams.
# Used for the cheek/jaw and one-piece hide garment instead of stacked primitives.
static func profile(parent: Node3D, rings: Array[Vector3], mat: Material, folds := 0.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 40
	var samples: Array[Vector3] = []
	for j in rings.size()-1:
		for k in 4:
			var t := float(k)/4.0
			samples.append(rings[j].lerp(rings[j+1],t))
	samples.append(rings[-1])
	for j in samples.size():
		var ring := samples[j]
		var slope := samples[mini(j+1,samples.size()-1)]-samples[maxi(0,j-1)]
		for i in sides+1:
			var a := TAU*i/sides
			var ripple := 1.0+folds*cos(a*7.0+ring.x*2.0)
			var n := Vector3(cos(a)/maxf(ring.y,0.02),-(slope.y+slope.z)/maxf(0.002,slope.x)*0.8,sin(a)/maxf(ring.z,0.02)).normalized()
			st.set_normal(n)
			st.add_vertex(Vector3(cos(a)*ring.y*ripple,ring.x,sin(a)*ring.z*ripple))
	for j in samples.size()-1:
		for i in sides:
			var a := j*(sides+1)+i
			for k in [a,a+1,a+sides+1,a+1,a+sides+2,a+sides+1]: st.add_index(k)
	var node := MeshInstance3D.new()
	node.name="SculptedProfile"
	node.mesh=st.commit();node.material_override=mat;parent.add_child(node)
	return node

# Original modeled geometry: tapered locks, braided cords and continuous skin.
static func strand(parent: Node3D, points: Array[Vector3], width: float, depth: float, outward: Vector3, mat: Material, taper := true) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 24
	var sides := 24
	for j in rings+1:
		var t := float(j)/rings
		var center := points[0]*(1-t)*(1-t)+points[1]*2*t*(1-t)+points[2]*t*t
		var tangent := ((points[1]-points[0])*(1-t)+(points[2]-points[1])*t).normalized()
		var across := tangent.cross(outward).normalized()
		var normal := across.cross(tangent).normalized()
		var shape := maxf(0.015,pow(sin(PI*(0.18+t*0.82)),0.7)) if taper else 1.0
		for i in sides+1:
			var a := TAU*i/sides
			var n := (across*sin(a)+normal*cos(a)).normalized()
			st.set_normal(n)
			st.add_vertex(center+across*sin(a)*width*shape+normal*cos(a)*depth*shape)
	for j in rings:
		for i in sides:
			var a := j*(sides+1)+i
			for k in [a,a+sides+1,a+1,a+1,a+sides+1,a+sides+2]: st.add_index(k)
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh

static func limb(parent: Node3D, rig: Skeleton3D, upper: int, lower: int, top: Vector3, elbow: Vector3, end: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 20
	var sides := 16
	var joint_t := top.distance_to(elbow)/top.distance_to(end)
	for j in rings+1:
		var t := float(j)/rings
		var center := top.lerp(end,t)
		var blend := smoothstep(joint_t-0.16,joint_t+0.16,t)
		var profile := lerpf(1.0,0.68,t)+sin(t*PI)*0.10
		if j == 0 or j == rings: profile *= 0.8
		for i in sides+1:
			var a := TAU*i/sides
			var n := Vector3(cos(a),0,sin(a))
			st.set_normal(n)
			st.set_bones(PackedInt32Array([upper,lower,0,0]))
			st.set_weights(PackedFloat32Array([1-blend,blend,0,0]))
			st.add_vertex(center+n*radius*profile)
	for j in rings:
		for i in sides:
			var a := j*(sides+1)+i
			for k in [a,a+sides+1,a+1,a+1,a+sides+1,a+sides+2]: st.add_index(k)
	var mesh := MeshInstance3D.new()
	mesh.name = "ContinuousLimb"
	mesh.mesh = st.commit()
	mesh.material_override = mat
	var skin := Skin.new()
	for i in rig.get_bone_count(): skin.add_bind(i,rig.get_bone_global_rest(i).affine_inverse())
	mesh.skin = skin
	parent.add_child(mesh)
	mesh.skeleton = mesh.get_path_to(rig)
	return mesh
