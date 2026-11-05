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
	if (world.model.built_count()>=DemoConfig.MAX_RESIDENT_HOMES): targets.clear();redraw();return
	for kind in ["wood","stone"]:
		if world.model.state[kind]>=20: targets.erase(kind);continue
		targets.erase(kind)
		var best: Dictionary={};var distance:=INF
		for n in world.model.nodes():
			if n.kind!=kind or world.exhausted(n): continue
			var d: float=world.player.position.distance_to(DemoConfig.point(n.position))
			var other_distance:=INF
			for other in world.model.nodes():
				if other.kind!=kind and not world.exhausted(other) and world.model.state[other.kind]<20:
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
	pass # Resources own their labels; no proximity rings or duplicate icon badges.

func draw_markers() -> void:
	pass
