extends RefCounted

static var halo_texture: GradientTexture2D

static func _halo(layer: CanvasItem, center: Vector2, extent: Vector2, angle: float, tint: Color) -> void:
	if halo_texture == null:
		var falloff := Gradient.new()
		falloff.offsets = PackedFloat32Array([0.0, .28, .64, 1.0])
		falloff.colors = PackedColorArray([Color.WHITE, Color(1,1,1,.68), Color(1,1,1,.23), Color(1,1,1,0)])
		halo_texture = GradientTexture2D.new()
		halo_texture.gradient = falloff
		halo_texture.fill = GradientTexture2D.FILL_RADIAL
		halo_texture.fill_from = Vector2(.5,.5)
		halo_texture.fill_to = Vector2(1,.5)
		halo_texture.width = 96
		halo_texture.height = 96
	layer.draw_set_transform(center,angle)
	layer.draw_texture_rect(halo_texture,Rect2(-extent*.5,extent),false,tint)
	layer.draw_set_transform(Vector2.ZERO)

static func spear(layer: Node2D, _soft: Texture2D, tip: Vector2, hand: Vector2) -> void:
	if not tip.is_finite() or not hand.is_finite() or tip.distance_to(hand)<3.0: return
	var axis := tip-hand
	var length := clampf(axis.length()*.35,12.0,31.0)
	var center := tip-axis.normalized()*length*.34
	_halo(layer,center,Vector2(length*2.0,length*1.22),axis.angle(),Color(.26,.64,1,.25))
	_halo(layer,center,Vector2(length*1.46,length*.71),axis.angle(),Color(.57,.85,1,.36))

static func blade_glow(layer: CanvasItem, palm: Vector2, direction: Vector2) -> void:
	if not palm.is_finite() or direction.is_zero_approx(): return
	var heading := direction.normalized()
	var center := palm+heading*12.0
	_halo(layer,center,Vector2(37,23),heading.angle(),Color(1.0,.75,.26,.49))
	_halo(layer,center+heading*3.0,Vector2(25,13),heading.angle(),Color(1.0,.93,.67,.59))

static func blade_core(layer: CanvasItem, palm: Vector2, direction: Vector2) -> void:
	if not palm.is_finite() or direction.is_zero_approx(): return
	var heading := direction.normalized()
	_halo(layer,palm+heading*12.0,Vector2(22,14),heading.angle(),Color(1.0,.96,.77,.39))

static func shield(layer: Node2D, _soft: Texture2D, view: HybridCharacter) -> void:
	var mesh: MeshInstance3D = view.shield
	if not is_instance_valid(mesh) or not mesh.is_visible_in_tree() or not mesh.mesh is QuadMesh: return
	var half: Vector2 = (mesh.mesh as QuadMesh).size*.5
	var left := shield_point(layer,view,mesh.to_global(Vector3(-half.x,0,0)))
	var right := shield_point(layer,view,mesh.to_global(Vector3(half.x,0,0)))
	var top := shield_point(layer,view,mesh.to_global(Vector3(0,half.y,0)))
	var bottom := shield_point(layer,view,mesh.to_global(Vector3(0,-half.y,0)))
	var center := top.lerp(bottom,.43)
	var extent := Vector2(maxf(23.0,left.distance_to(right)*1.87),maxf(26.0,top.distance_to(bottom)*1.63))
	var angle := (right-left).angle()
	_halo(layer,center,extent,angle,Color(1.0,.48,.13,.64))
	_halo(layer,top.lerp(bottom,.32),extent*Vector2(.88,.72),angle,Color(1.0,.77,.36,.68))
	_halo(layer,top.lerp(bottom,.27),extent*Vector2(.60,.50),angle,Color(1.0,.90,.63,.40))

static func shield_point(layer: Node2D, view: HybridCharacter, p: Vector3) -> Vector2:
	return layer.to_local(view.display.to_global(view.camera.unproject_position(p)))
