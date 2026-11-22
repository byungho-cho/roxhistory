extends RefCounted
## Saebom rope sling presentation; no combat timing, damage, or collision ownership.
static func make_glow() -> GradientTexture2D:
	var g:=Gradient.new()
	g.offsets=PackedFloat32Array([0.,.23,.58,1.])
	g.colors=PackedColorArray([Color(1,1,1,1),Color(1,1,1,.70),Color(1,1,1,.20),Color(1,1,1,0.)])
	var t:=GradientTexture2D.new()
	t.gradient=g;t.fill=GradientTexture2D.FILL_RADIAL
	t.fill_from=Vector2(.5,.5);t.fill_to=Vector2(1.,.5)
	return t

static func held_mesh(rig) -> MeshInstance3D:
	if not is_instance_valid(rig):return null
	if rig.has_meta("_rope_sling_basic_mesh"):
		var known:Variant=rig.get_meta("_rope_sling_basic_mesh")
		if is_instance_valid(known):return known
	for model in rig.pivot.find_children("*","MeshInstance3D",true,false):
		var n:=String(model.name).to_lower()
		if "large stone" in n or "large_stone" in n:
			rig.set_meta("_rope_sling_basic_mesh",model)
			rig.set_meta("_rope_sling_basic_visible",model.visible)
			return model
	return null

static func set_loaded(rig,loaded:bool)->void:
	var mesh:=held_mesh(rig)
	if is_instance_valid(mesh):mesh.visible=loaded and bool(rig.get_meta("_rope_sling_basic_visible",true))

static func stone_world(rig)->Vector3:
	var sk:Skeleton3D=rig.skeleton
	var joint:=sk.find_bone("sling_stone")
	if joint<0:return Vector3.INF
	var pose:=sk.get_bone_global_pose(joint)
	var mesh:=held_mesh(rig)
	if is_instance_valid(mesh) and is_instance_valid(mesh.skin) and mesh.skin.get_bind_count()>joint:
		var center:=mesh.skin.get_bind_pose(joint)*mesh.get_aabb().get_center()
		if center.length()<.3:return sk.to_global(pose*center)
	return sk.to_global(pose.origin)

static func _soft(layer:CanvasItem,texture:Texture2D,p:Vector2,s:Vector2,c:Color,a:float)->void:
	if p.is_finite() and a>.002:layer.draw_texture_rect(texture,Rect2(p-s*.5,s),false,Color(c,a))

static func draw_stone(layer:CanvasItem,texture:Texture2D,center:Vector2,age:float,draw_core:=false)->void:
	var a:=clampf(age/.33,0.,1.)
	var w:=26.+9.*a
	_soft(layer,texture,center,Vector2(w,w*.84),Color("e3a03f"),.68-.11*a)
	_soft(layer,texture,center,Vector2(8,7),Color("ffe9a8"),.60)
	if draw_core:layer.draw_circle(center,3.,Color("ffdf9c"),true,-1.,true)

static func draw_impact(layer:CanvasItem,texture:Texture2D,at:Vector2,t:float)->void:
	if not at.is_finite() or t<0. or t>=.30:return
	var p:=t/.30
	var fade:=1.-smoothstep(.25,1.,p)
	_soft(layer,texture,at+Vector2(-4.-9.*p,3.+2.*p),Vector2(13.,9.)*(1.+.8*p),Color("997049"),fade*.30)
	_soft(layer,texture,at+Vector2(4.+11.*p,4.+3.*p),Vector2(14.,8.)*(1.+.6*p),Color("bc9565"),fade*.38)
	for i in 6:
		var phase:=float(i)*2.39996
		var dir:=Vector2(cos(phase),sin(phase)*.68)
		var point:=at+dir*(4.+float(i%3)*4.)*(1.-exp(-p*4.))+Vector2(0.,7.*p*p)
		layer.draw_circle(point,(1.3+float(i%3)*.36)*(1.-.34*p),Color("a27341",fade*.94),true,-1.,true)
		layer.draw_circle(point+Vector2(-.55,-.40),.63,Color("ffe2a4",fade*.90),true,-1.,true)
