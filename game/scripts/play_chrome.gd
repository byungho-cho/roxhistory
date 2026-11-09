class_name PlayChrome
extends Control
var app: Node
var flights: Array[Dictionary]=[]
var pulse := {"wood":0.0,"stone":0.0,"tokens":0.0}
var styles: Dictionary={}
var portrait: Texture2D
const RESIDENT_ICON=preload("res://assets/ui/resource-bars/resident.png")
const CORN_ICON=preload("res://assets/ui/resource-bars/corn.png")
const TRACK_COLOR:=Color("523621")
const TRACK_RIM:=Color("874f0d")
const FILL_COLORS:=[Color("ffdb45"),Color("f2b00a"),Color("d48005")]
var resource_capacities:Dictionary={}
var refill_targets:Dictionary={}
# Original portrait pixels, clipped to the hair/shoulders instead of its baked gold ring.
const PORTRAIT_OUTLINE=[Vector2(28,103),Vector2(29,77),Vector2(40,57),Vector2(53,43),Vector2(70,34),Vector2(82,22),Vector2(100,27),Vector2(118,23),Vector2(142,37),Vector2(157,53),Vector2(157,73),Vector2(170,90),Vector2(171,116),Vector2(162,140),Vector2(147,153),Vector2(156,166),Vector2(153,177),Vector2(132,186),Vector2(100,186),Vector2(68,179),Vector2(47,167),Vector2(61,152),Vector2(66,141),Vector2(49,130),Vector2(43,118),Vector2(33,120)]
const COUNT_DURATION:=0.35
var resource_counts:Dictionary={}
var last_map_position := Vector2.INF
var minimap:LiveMinimap
# Optional future marker artwork; keep its placement independent of map projection.
var location_marker_texture:Texture2D=preload("res://assets/ui/minimap-player-figma-v001.svg")
func _init(owner_app: Node) -> void: app=owner_app
func _ready() -> void:
	for key in ["wood","stone","tokens"]:
		var target:=DemoButton.new()
		target.name=key.capitalize()+"RefillTarget"
		target.flat=true
		target.focus_mode=Control.FOCUS_NONE
		for style in ["normal","hover","pressed","focus","disabled","hover_pressed"]:
			target.add_theme_stylebox_override(style,StyleBoxEmpty.new())
		target.pressed.connect(refill_resource.bind(key))
		add_child(target)
		refill_targets[key]=target
	sync_resource_counts(true)
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	app.model.changed.connect(sync_resource_counts)
	resized.connect(queue_redraw)
	resized.connect(layout_refill_targets)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/ui/s40000/portrait.png"): portrait=load("res://assets/ui/v034/chief-portrait.png")
	call_deferred("create_minimap")
func create_minimap()->void:
	minimap=LiveMinimap.new(app);add_child(minimap)
func slot(kind: String) -> Rect2:
	var i:int=["wood","stone","tokens","residents"].find(kind)
	if app.w<app.h:return Rect2(Vector2(app.safe.x+i*86,app.safe.y+62),Vector2(82,36))
	return Rect2(Vector2(app.w-app.safe.x-520+i*100,app.safe.y+1),Vector2(96,36))
func layout_refill_targets()->void:
	for key in refill_targets:
		var target:DemoButton=refill_targets[key]
		var bounds:=slot(key)
		target.position=bounds.position
		target.size=bounds.size
		target.visible=app.model.debug_resource_refill

func refill_resource(key:String)->void:
	if app.modal or app.world_map_open or app.map_transition_active or not app.application_active:return
	if app.model.debug_fill_resource("grain" if key=="tokens" else key):
		var count:Dictionary=resource_counts[key]
		count.shown=count.target
		count.elapsed=COUNT_DURATION
		queue_redraw()

func gained(kind:String,at:Vector2,delay:float=0.0) -> void:
	flights.append({"kind":kind,"world":at,"age":-delay})
func clear_effects() -> void:
	flights.clear();sync_resource_counts(true)
func sync_resource_counts(immediate:bool=false)->void:
	layout_refill_targets()
	for kind in ["wood","stone","grain"]:
		resource_capacities[kind]=ResourceStorage.capacity(app.model,kind)
	for key in ["wood","stone","tokens"]:
		var target:=float(app.model.state.get("grain",app.model.state.get("tokens",0)) if key=="tokens" else app.model.state.get(key,0))
		if immediate or not resource_counts.has(key):
			resource_counts[key]={"shown":target,"from":target,"target":target,"elapsed":COUNT_DURATION}
		elif resource_counts[key].target!=target:
			var count:Dictionary=resource_counts[key]
			count.from=count.shown;count.target=target;count.elapsed=0.0
	queue_redraw()
func advance_resource_counts(delta:float)->bool:
	var changed:=false
	for count in resource_counts.values():
		if count.elapsed>=COUNT_DURATION:continue
		count.elapsed=minf(COUNT_DURATION,count.elapsed+delta)
		var t:float=count.elapsed/COUNT_DURATION
		count.shown=lerpf(count.from,count.target,t*t*(3.0-2.0*t))
		if count.elapsed>=COUNT_DURATION:count.shown=count.target
		changed=true
	return changed
func _process(delta: float) -> void:
	var counting:=advance_resource_counts(delta)
	var moving_map := false
	if is_instance_valid(app.world):
		var p: Vector2=app.world.player.position
		moving_map=p!=last_map_position
		last_map_position=p
	var active := moving_map or not flights.is_empty() or counting
	for key in pulse: active=active or pulse[key]>0
	if not active:return
	for key in pulse: pulse[key]=maxf(0,pulse[key]-delta*2.5)
	for f in flights:
		f.age+=delta
		if f.age>=0.85:
			pulse[f.kind]=1.0
	flights=flights.filter(func(f): return f.age<0.85)
	queue_redraw()
func frame(rect: Rect2, fill: Color, border: Color) -> void:
	var key:=fill.to_html()+border.to_html()
	if not styles.has(key):
		var style:=StyleBoxFlat.new();style.bg_color=fill;style.border_color=border
		style.set_corner_radius_all(10);style.set_border_width_all(1)
		style.shadow_color=Color(0.10,0.06,0.02,0.3);style.shadow_size=1;style.shadow_offset=Vector2(0,1)
		styles[key]=style
	draw_style_box(styles[key],rect)
func _draw() -> void:
	if not is_instance_valid(app.world) or app.model.state.is_empty(): return
	var font:=DemoArt.theme().default_font
	var origin: Vector2=app.safe

	if portrait:draw_texture_rect(portrait,Rect2(origin+Vector2(-5,-3),Vector2(65,59.17)),false)
	draw_string(font,origin+Vector2(62,22),"새벽",HORIZONTAL_ALIGNMENT_LEFT,138,17,Color("fff1d4"))
	draw_string(font,origin+Vector2(62,41),"정착",HORIZONTAL_ALIGNMENT_LEFT,32,12,Color("fff1d4"))
	draw_texture_rect_region(preload("res://assets/ui/v034/energy-bar-frame.png"),Rect2(origin+Vector2(98,30),Vector2(102,10)),Rect2(100,250,1975,205))
	var fill:=minf(1,app.model.built_count()/3.0)
	if fill>0:draw_style_box(energy_fill(),Rect2(origin+Vector2(102,32),Vector2(94*fill,6)))
	for key in ["wood","stone","tokens","residents"]:
		var rect:=slot(key);var beat:float=pulse.get(key,0.0)
		var is_resident:bool=key=="residents"
		var kind:String="grain" if key=="tokens" else key
		var amount:int=app.model.resident_count() if is_resident else roundi(resource_counts[key].shown)
		var capacity:int=app.model.resident_capacity() if is_resident else resource_capacities[kind]
		var track:=Rect2(rect.position+Vector2(15,10),Vector2(rect.size.x-15,20))
		frame(track,TRACK_COLOR,TRACK_RIM)
		var fraction:=clampf(float(amount)/maxi(1,capacity),0,1)
		if fraction>0:
			var inside:=track.grow(-1)
			inside.size.x*=fraction
			draw_resource_fill(inside)
		var label:="%d / %d"%[amount,capacity]
		var number_start:=rect.position+Vector2(30,24)
		var number_width:=rect.size.x-32
		var number_size:=10
		if font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,number_size).x>number_width:
			label=str(amount)
		draw_string_outline(font,number_start,label,HORIZONTAL_ALIGNMENT_CENTER,number_width,number_size,3,TRACK_COLOR)
		draw_string(font,number_start,label,HORIZONTAL_ALIGNMENT_CENTER,number_width,number_size,Color("fffae5"))
		var extent:=32.0+beat*4
		var top:=6.0 if key in ["wood","stone"] else 3.0
		draw_texture_rect(resource_icon(key),Rect2(rect.position+Vector2(0,top),Vector2.ONE*extent),false)
	var center:=Vector2(app.w-app.safe.x-50,app.safe.y+60)
	draw_circle(center+Vector2(1,3),53,Color(.15,.10,.04,.20))
	draw_circle(center,51,Color("49321e"))
	var points:=PackedVector2Array();var uv:=PackedVector2Array()
	for i in 64:
		var d:=Vector2.from_angle(TAU*i/64.0)
		points.append(center+d*48);uv.append(Vector2(.5,.5)+d*.5)
	if is_instance_valid(minimap):draw_colored_polygon(points,Color.WHITE,uv,minimap.current_texture())
	draw_texture_rect(preload("res://assets/ui/review-v037/minimap-ring.png"),Rect2(center-Vector2(54,54.6),Vector2(108,109.2)),false)
	var normalized:=Vector2.ZERO
	if is_instance_valid(minimap):normalized=minimap.normalized_point(Vector2.ZERO if app.world_map_open else app.world.player.position)
	var dot:=center+(normalized*96).limit_length(45)
	draw_location_marker(dot, (dot-center).angle()-PI*.5 if dot.distance_to(center)>34 else 0.0)
	draw_string(font,center+Vector2(-5,-33),"N",HORIZONTAL_ALIGNMENT_LEFT,20,12,Color("fff2cf"))
	draw_set_transform(Vector2.ZERO)
	for f in flights:
		if f.age<0:continue
		var from: Vector2=app.world.get_global_transform_with_canvas()*f.world
		var to:=slot(f.kind).get_center()
		var t: float=clampf(f.age/0.85,0,1)
		var q:=smoothstep(0.12,1.0,t)
		var control: Vector2=from.lerp(to,0.45)+Vector2(0,-100)
		var at: Vector2=from*(1-q)*(1-q)+control*2*q*(1-q)+to*q*q-Vector2(0,sin(t*PI)*20)
		var extent:=lerpf(40,30,q)
		draw_circle(at,extent*0.65,Color(1,.85,.4,.15))
		draw_texture_rect(resource_icon(f.kind),Rect2(at-Vector2.ONE*extent/2,Vector2.ONE*extent),false)

func energy_fill()->StyleBoxFlat:
	var skin:=StyleBoxFlat.new();skin.bg_color=Color("8ac644");skin.set_corner_radius_all(3);return skin

func draw_location_marker(at:Vector2,angle:float=0.0)->void:
	# Twice the former 7.2 x 6 size. Tip stays exactly on projected player position.
	draw_set_transform(at,angle)
	draw_texture_rect(location_marker_texture,Rect2(Vector2(-7.2,-12),Vector2(14.4,12)),false)
	draw_set_transform(Vector2.ZERO)

static func resource_icon(key:String)->Texture2D:
	if key=="tokens" or key=="grain":return CORN_ICON
	if key=="residents":return RESIDENT_ICON
	return DemoArt.icon(key)

func draw_resource_fill(rect:Rect2)->void:
	var radius:=minf(rect.size.x,rect.size.y)*.5
	var points:=PackedVector2Array([rect.get_center()])
	var colors:=PackedColorArray([FILL_COLORS[1]])
	for corner in 4:
		var pivot:=Vector2(rect.end.x-radius if corner in [0,1] else rect.position.x+radius,
			rect.end.y-radius if corner in [1,2] else rect.position.y+radius)
		for step in 5:
			var angle:=(float(corner)-1.0+step/4.0)*PI*.5
			var point:=pivot+Vector2.from_angle(angle)*radius
			var height:=clampf((point.y-rect.position.y)/rect.size.y,0,1)
			points.append(point)
			colors.append(FILL_COLORS[0].lerp(FILL_COLORS[1],height*2) if height<.5 else FILL_COLORS[1].lerp(FILL_COLORS[2],height*2-1))
	for i in range(1,points.size()):
		var next:=i+1 if i+1<points.size() else 1
		if not points[i].is_equal_approx(points[next]):
			draw_polygon(PackedVector2Array([points[0],points[i],points[next]]),PackedColorArray([colors[0],colors[i],colors[next]]))
