extends RefCounted
## TEST35 presentation only; callers provide accepted events and live projected anchors.
const HeadHud := preload("res://scripts/battle_head_hud.gd")
const CAST_SECONDS := .74
const HP_FADE_SECONDS := .27
var art: RefCounted
var cast_frames: Array[StyleBoxFlat] = []

func _init(prey_art: RefCounted) -> void:
	art = prey_art
	for tint in [Color("ffd179"), Color("87ddff")]:
		var style := StyleBoxFlat.new()
		style.bg_color=Color("101d2c",.93)
		style.border_color=tint
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		cast_frames.append(style)

static func create_head(parent: Node, ally: bool) -> Dictionary:
	var entry := HeadHud.create_compact(parent,ally)
	entry.panel.hide()
	return entry

static func sync_heads(headers: Array, points: Array, bounds: Rect2, since_first_hit: float, ko_ages: Array = []) -> void:
	if headers.size()!=points.size():return
	HeadHud.layout_compact(headers,points,bounds)
	var reveal:=smoothstep(0.,HP_FADE_SECONDS,since_first_hit) if is_finite(since_first_hit) else 0.
	for i in headers.size():
		var panel:Control=headers[i].panel
		var alpha:=reveal
		if i<ko_ages.size() and float(ko_ages[i])>=0.:
			alpha=minf(alpha,1.-smoothstep(.13,.58,float(ko_ages[i])))
		panel.modulate.a=alpha
		panel.visible=alpha>.001

## Measure the native camera's floor ellipse about its ground origin, then fit a
## common radius. The camera is the actor's own subviewport camera, not main UI.
static func ground_rect(camera: Camera3D, feet: Vector2, radius_px: float = 23.) -> Rect2:
	if not is_instance_valid(camera) or not feet.is_finite() or radius_px<=0.:return Rect2()
	var origin:=camera.unproject_position(Vector3.ZERO)
	var bounds:=Rect2()
	for i in 40:
		var u:=Vector2.from_angle(TAU*float(i)/40.)
		var p:=camera.unproject_position(Vector3(u.x*.64,0.,u.y*.64))-origin
		bounds=bounds.expand(p)
	if bounds.size.x<=.001:return Rect2()
	var size:=bounds.size*(2.*radius_px/bounds.size.x)
	return Rect2(feet-size*.5,size)

## phase advances at rate 1.5/2.4 or 2/2.4 per simulation second for 2SP/3SP.
func draw_ready_ring(layer: Node2D, floor: Rect2, sp: int, phase: float) -> void:
	if sp<2 or not floor.has_area():return
	var q:=fposmod(phase,1.)
	var alpha:=.72*smoothstep(0.,.14,q)*(1.-smoothstep(.86,1.,q))
	var extent:=floor.size/.68*lerpf(float(mini(3,sp)),.035,smoothstep(0.,1.,q))
	var center:=floor.get_center()
	var tint:=HeadHud.duel_team_color(true)
	layer.draw_texture_rect(art.ring_band,Rect2(center-extent*.5,extent),false,Color(tint.lightened(.25),alpha))
	var focus:=smoothstep(.71,.93,q)*(1.-smoothstep(.95,1.,q))
	if focus>0.:
		var dot_size:=Vector2(10,7)*lerpf(.6,1.,focus)
		layer.draw_texture_rect(art.ring_halo,Rect2(center-dot_size*.5,dot_size),false,Color(tint.lightened(.45),focus*.84))

func draw_cast_notice(layer: Node2D, anchor: Vector2, hp_panel: Control, icon: Texture2D, linked: bool, age: float) -> void:
	if icon==null or age<0. or age>=CAST_SECONDS or not anchor.is_finite():return
	var p:=clampf(age/CAST_SECONDS,0.,1.)
	var alpha:=smoothstep(0.,.08,p)*(1.-smoothstep(.65,1.,p))
	var side:=lerpf(24.,29.,smoothstep(0.,.24,p)) if linked else lerpf(20.,24.,smoothstep(0.,.24,p))
	side*=lerpf(1.,1.5,smoothstep(.65,1.,p))
	var y:=anchor.y-17.
	if is_instance_valid(hp_panel) and hp_panel.visible:
		y=minf(y,layer.to_local(hp_panel.get_global_transform().origin).y-12.)
	var center:=Vector2(anchor.x,maxf(70.,y-lerpf(0.,21.,smoothstep(0.,.78,p))))
	_draw_cast_frame(layer,center,icon,linked,alpha,side)


func _draw_cast_frame(layer:Node2D,center:Vector2,icon:Texture2D,linked:bool,alpha:float,side:float)->void:
	var extent:=Vector2.ONE*side
	var box:=Rect2(center-extent*.5,extent)
	var tint:=Color("58b9ff") if linked else Color("ffd179")
	layer.draw_texture_rect(art.ring_halo,box.grow(13.),false,Color(tint,.72*alpha))
	var frame:=cast_frames[1 if linked else 0]
	frame.bg_color.a=.93*alpha
	frame.border_color.a=alpha
	layer.draw_style_box(frame,box)
	layer.draw_texture_rect(icon,box.grow(-2.),false,Color(1.,1.,1.,alpha))

static func rally_notice_shape(age:float, remaining:float, fading:float)->Vector3:
	var p:=clampf(age/CAST_SECONDS,0.,1.)
	var side:=lerpf(24.,29.,smoothstep(0.,.24,p))
	var alpha:=smoothstep(0.,.08,p)
	var rise:=21.*smoothstep(0.,.78,p)
	if remaining>0.:
		var final_beat:=remaining<=1.
		var cycles:float=(1.-remaining)*3. if final_beat else (5.-remaining)*.75
		var phase:=fposmod(cycles,1.)
		var dip:=smoothstep(.19,.37,phase)*(1.-smoothstep(.64,.82,phase))
		var steady:=lerpf(.93 if final_beat else .85,.14 if final_beat else .22,dip)
		alpha=lerpf(alpha,steady,smoothstep(0.,.20,5.-remaining))
	elif fading>=0.:
		var out:=smoothstep(0.,.26,fading)
		alpha=.93*(1.-out)
		side*=lerpf(1.,1.5,out)
		rise+=7.*out
	return Vector3(alpha,side,rise)


func draw_rally_cast_notice(layer:Node2D, anchor:Vector2, hp_panel:Control, icon:Texture2D, age:float, remaining:float, fading:float)->void:
	if icon==null or not anchor.is_finite():return
	var shape:=rally_notice_shape(age,remaining,fading)
	if shape.x<=.001:return
	var y:=anchor.y-17.
	if is_instance_valid(hp_panel) and hp_panel.visible:
		y=minf(y,layer.to_local(hp_panel.get_global_transform().origin).y-12.)
	_draw_cast_frame(layer,Vector2(anchor.x,maxf(70.,y-shape.z)),icon,true,shape.x,shape.y)


func _light(layer: Node2D, point: Vector2, extent: Vector2, tint: Color, opacity: float) -> void:
	layer.draw_texture_rect(art.soft,Rect2(point-extent*.5,extent),false,Color(tint,opacity))

func draw_spear_glow(layer: Node2D, tip: Vector2, hand: Vector2, visual_clock: float) -> void:
	if not tip.is_finite() or not hand.is_finite():return
	var blade:=tip-hand
	if blade.length_squared()<.01:return
	var breath:=.88+.12*sin(visual_clock*TAU*.75)
	var length:=clampf(blade.length()*.24,10.,21.)
	var center:=tip-blade.normalized()*length*.42
	layer.draw_set_transform(center,blade.angle())
	_light(layer,Vector2.ZERO,Vector2(length*1.68,13),Color("389fff"),.31*breath)
	_light(layer,Vector2(1,0),Vector2(length*1.24,5.5),Color("96dcff"),.34*breath)
	layer.draw_set_transform(Vector2.ZERO)

## Project the actual club circumference, not a glow over Uram's hand or body.
static func club_head_samples(club: MeshInstance3D) -> PackedVector3Array:
	var points:=PackedVector3Array()
	if not is_instance_valid(club) or club.mesh==null or not club.visible:return points
	var box:=club.get_aabb()
	var center:=box.get_center()
	for i in 8:
		var phase:=TAU*float(i)/8.
		points.append(club.to_global(Vector3(box.end.x-box.size.x*.11,center.y+box.size.y*.43*cos(phase),center.z+box.size.z*.43*sin(phase))))
	return points

func draw_club_glow(layer: Node2D, projected_samples: PackedVector2Array) -> void:
	for mark in projected_samples:
		if not mark.is_finite():continue
		_light(layer,mark,Vector2(13,11),Color("e96c23"),.24)
		_light(layer,mark,Vector2(5,4),Color("ffbc64"),.33)

## Use one point: held stone or active projectile. Do not draw while prop is hidden.
func draw_sling_glow(layer: Node2D, point: Vector2) -> void:
	if not point.is_finite():return
	_light(layer,point,Vector2(24,20),Color("f5a93a"),.42)
	_light(layer,point,Vector2(9,8),Color("ffe497"),.79)
