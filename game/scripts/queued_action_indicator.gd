class_name QueuedActionIndicator
extends TextureRect
## Presentation only; pending_action remains the single source of truth.
var app:Node
var icon_key:=""
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
	name="QueuedActionIndicator";mouse_filter=Control.MOUSE_FILTER_IGNORE
	expand_mode=TextureRect.EXPAND_IGNORE_SIZE;stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	size=Vector2(26,26);z_index=7;hide()
func resolve_icon(request:Dictionary)->String:
	match str(request.get("kind","")):
		"build":return "hut"
		"move":return "move"
		"gather":
			var id:String=str(request.get("id",""))
			if id.is_empty():return "berries"
			for node in app.model.nodes():
				if str(node.id)==id:return str(node.kind) if str(node.kind) in ["wood","stone"] else ""
	return "" # No dedicated family invitation icon; do not invent an action symbol.
func refresh()->void:
	icon_key=resolve_icon(app.pending_action)
	visible=not icon_key.is_empty() and app.screen=="play" and not app.world_map_open and not app.modal and app.application_active and is_instance_valid(app.world)
	if not visible:return
	texture=BuildingMenu.art("icon-move.png") if icon_key=="move" else DemoArt.play_icon(icon_key)
	var transform:Transform2D=app.world.get_global_transform_with_canvas()
	var head:Vector2=transform*(app.world.player.position-Vector2(0,DemoPlayer.HEIGHT))
	var origin:=head-Vector2(size.x*.5,size.y+5)
	var obstacles:Array[Rect2]=[]
	for i in app.model.built_count():
		if app.model.reward_pending(i):obstacles.append(transform*app.world.reward_marker_rect(i))
	if is_instance_valid(app.family) and is_instance_valid(app.family.bubble) and app.family.bubble.is_visible_in_tree():obstacles.append(app.family.bubble.get_global_rect())
	position=origin
	for offset in [Vector2.ZERO,Vector2(34,0),Vector2(-34,0),Vector2(0,-34),Vector2(68,0),Vector2(-68,0)]:
		var candidate:=Rect2(origin+offset,size)
		var clear:=true
		for obstacle in obstacles:
			if candidate.intersects(obstacle.grow(4)):clear=false;break
		if clear:position=candidate.position;return
	# Dense reward/dialogue clusters: keep the icon above the highest obstruction.
	for obstacle in obstacles:position.y=minf(position.y,obstacle.position.y-size.y-5)
func _process(_delta:float)->void:refresh()
