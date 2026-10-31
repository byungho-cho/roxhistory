class_name WorldObjectives
extends Node2D
var world: DemoWorld
var targets := {}
var flash := 0.0
var previous_selection:=""
var markers: Node2D
func _init(owner_world: DemoWorld) -> void: world=owner_world
func _ready() -> void:
	z_index=-5
	markers=Node2D.new();markers.z_index=9;add_child(markers);markers.draw.connect(draw_markers)
	world.model.changed.connect(refresh)
	refresh()
func refresh() -> void:
	if world.model.state.built: targets.clear();redraw();return
	for kind in ["wood","stone"]:
		if world.model.state[kind]>=1: targets.erase(kind);continue
		if targets.has(kind) and not world.exhausted(targets[kind]): continue
		var best: Dictionary={};var distance:=INF
		for n in DemoConfig.get_data().nodes:
			if n.kind!=kind or world.exhausted(n): continue
			var d: float=world.player.position.distance_to(DemoConfig.point(n.position))
			var other_distance:=INF
			for other in DemoConfig.get_data().nodes:
				if other.kind!=kind and not world.exhausted(other) and world.model.state[other.kind]<1:
					other_distance=minf(other_distance,DemoConfig.point(n.position).distance_to(DemoConfig.point(other.position)))
			if is_finite(other_distance): d+=other_distance*0.65
			if d<distance: best=n;distance=d
		if not best.is_empty(): targets[kind]=best
	redraw()
func focus_point() -> Vector2:
	flash=1.0
	for kind in ["wood","stone"]:
		if targets.has(kind): return DemoConfig.point(targets[kind].position)
	return world.site.position
func redraw() -> void:
	queue_redraw()
	if markers:markers.queue_redraw()
func _process(delta: float) -> void:
	if flash<=0 and previous_selection==world.selected:return
	previous_selection=world.selected
	flash=maxf(0,flash-delta*0.8);redraw()
func _draw() -> void:
	for key in targets:
		var at:=DemoConfig.point(targets[key].position)
		draw_set_transform(at,0,Vector2(1,0.58))
		draw_circle(Vector2.ZERO,168,Color(0.65,0.80,0.35,0.13+flash*0.06))
		draw_arc(Vector2.ZERO,168,0,TAU,64,Color(.18,.27,.11,.65),7,true)
		draw_arc(Vector2.ZERO,168,0,TAU,64,Color(.87,.90,.47,.78+flash*.20),3,true)
		draw_set_transform(Vector2.ZERO)
		if world.selected==str(targets[key].id):
			# Actual reach is a world-space circle, not the larger decorative zone.
			draw_arc(at,float(DemoConfig.get_data().interact_radius),0,TAU,64,Color(.95,.86,.55,.40),2,true)
	if world.model.can_build() and not world.model.state.built:
		draw_texture_rect(DemoArt.icon("hut"),Rect2(world.site.position+Vector2(-26,-168-flash*8),Vector2(52,52)),false)

func draw_markers() -> void:
	for key in targets:
		if world.selected==str(targets[key].id): continue
		var at:=DemoConfig.point(targets[key].position)+Vector2(55,-92-flash*8)
		markers.draw_circle(at,27,Color("493020ed"))
		markers.draw_arc(at,27,0,TAU,48,Color("dbe58d"),2,true)
		markers.draw_texture_rect(DemoArt.icon(key),Rect2(at-Vector2(19,18),Vector2(38,36)),false)
