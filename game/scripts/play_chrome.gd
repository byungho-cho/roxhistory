class_name PlayChrome
extends Control
var app: Node
var flights: Array[Dictionary]=[]
var pulse := {"wood":0.0,"stone":0.0,"tokens":0.0}
var styles: Dictionary={}
var portrait: Texture2D
const RESOURCE_BRUSH=preload("res://assets/ui/brush/resource-slot-brush@2x.png")
# Original portrait pixels, clipped to the hair/shoulders instead of its baked gold ring.
const PORTRAIT_OUTLINE=[Vector2(28,103),Vector2(29,77),Vector2(40,57),Vector2(53,43),Vector2(70,34),Vector2(82,22),Vector2(100,27),Vector2(118,23),Vector2(142,37),Vector2(157,53),Vector2(157,73),Vector2(170,90),Vector2(171,116),Vector2(162,140),Vector2(147,153),Vector2(156,166),Vector2(153,177),Vector2(132,186),Vector2(100,186),Vector2(68,179),Vector2(47,167),Vector2(61,152),Vector2(66,141),Vector2(49,130),Vector2(43,118),Vector2(33,120)]
var reveal := 0.0
var resource_alpha := .75
var displayed_tokens := 0.0
var token_target := 0.0
var last_map_position := Vector2.INF
func _init(owner_app: Node) -> void: app=owner_app
func _ready() -> void:
	displayed_tokens=float(app.model.state.tokens);token_target=displayed_tokens
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	app.model.changed.connect(queue_redraw)
	resized.connect(queue_redraw)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/ui/s40000/portrait.png"): portrait=load("res://assets/ui/v034/chief-portrait.png")
func slot(kind: String) -> Rect2:
	var i:int=["wood","stone","tokens"].find(kind)
	if app.w<app.h:return Rect2(Vector2(app.safe.x+i*100,app.safe.y+66),Vector2(96,36))
	return Rect2(Vector2(app.w-app.safe.x-420+i*100,app.safe.y+5),Vector2(96,36))
func gained(kind:String,at:Vector2,delay:float=0.0) -> void:
	reveal=5.0
	flights.append({"kind":kind,"world":at,"age":-delay})
func clear_effects() -> void:
	flights.clear();displayed_tokens=float(app.model.state.get("tokens",0));token_target=displayed_tokens;queue_redraw()
func _process(delta: float) -> void:
	var previous_alpha:=resource_alpha
	var previous_tokens:=displayed_tokens
	reveal=maxf(0,reveal-delta)
	resource_alpha=move_toward(resource_alpha,1.0 if reveal>0 else .75,delta*.5)
	displayed_tokens=move_toward(displayed_tokens,token_target,delta*24)
	var moving_map := false
	if is_instance_valid(app.world):
		var p: Vector2=app.world.player.position
		moving_map=p!=last_map_position
		last_map_position=p
	var active := moving_map or not flights.is_empty() or previous_alpha!=resource_alpha or previous_tokens!=displayed_tokens
	for key in pulse: active=active or pulse[key]>0
	if not active:return
	for key in pulse: pulse[key]=maxf(0,pulse[key]-delta*2.5)
	for f in flights:
		f.age+=delta
		if f.age>=0.85:
			pulse[f.kind]=1.0
			if f.kind=="tokens":token_target=float(app.model.state.tokens)
	flights=flights.filter(func(f): return f.age<0.85)
	queue_redraw()
func frame(rect: Rect2, fill: Color, border: Color) -> void:
	var key:=fill.to_html()+border.to_html()
	if not styles.has(key):
		var style:=StyleBoxFlat.new();style.bg_color=fill;style.border_color=border
		style.set_corner_radius_all(12);style.set_border_width_all(2)
		style.shadow_color=Color(0.10,0.06,0.02,0.3);style.shadow_size=3;style.shadow_offset=Vector2(0,3)
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
	for key in ["wood","stone","tokens"]:
		var rect:=slot(key);var beat:float=pulse.get(key,0.0)
		# PNG already includes 75% alpha. Preserve brush caps at the height scale.
		var brush_rect:=Rect2(rect.position+Vector2(11,5),Vector2(84,27))
		var scale_y:=brush_rect.size.y/112.0
		var left:=64*scale_y;var right:=176*scale_y
		draw_texture_rect_region(RESOURCE_BRUSH,Rect2(brush_rect.position,Vector2(left,27)),Rect2(0,0,64,112))
		draw_texture_rect_region(RESOURCE_BRUSH,Rect2(brush_rect.position+Vector2(left,0),Vector2(84-left-right,27)),Rect2(64,0,272,112))
		draw_texture_rect_region(RESOURCE_BRUSH,Rect2(brush_rect.end-Vector2(right,27),Vector2(right,27)),Rect2(336,0,176,112))
		var extent:=28.0+beat*4
		draw_texture_rect(DemoArt.icon(key),Rect2(rect.position+Vector2(3,3),Vector2(extent,extent)),false)
		draw_string(font,rect.position+Vector2(34,25),str(int(displayed_tokens)) if key=="tokens" else str(int(app.model.state[key])),HORIZONTAL_ALIGNMENT_LEFT,62,15,Color(1,.98,.90,1))
	var center:=Vector2(app.w-app.safe.x-50,app.safe.y+50)
	draw_circle(center+Vector2(1,3),53,Color(.15,.10,.04,.20))
	draw_circle(center,51,Color("49321e"))
	var points:=PackedVector2Array();var uv:=PackedVector2Array()
	for i in 64:
		var d:=Vector2.from_angle(TAU*i/64.0)
		points.append(center+d*48);uv.append(Vector2(.5,.5)+d*.5)
	draw_colored_polygon(points,Color.WHITE,uv,preload(SceneStyle.TERRAIN))
	draw_arc(center,50,0,TAU,64,Color("c8a15e"),3,true)
	draw_arc(center,49,-PI,-PI*.12,40,Color("fff0bb"),1,true)
	var normalized: Vector2=app.world.player.position/Vector2(2400,1350)-Vector2(.5,.5)
	var dot:=center+(normalized*96).limit_length(45)
	draw_circle(dot,4.5,Color("63451d"))
	draw_circle(dot,2.5,Color("fff0b2"))
	draw_string(font,center+Vector2(-5,-33),"N",HORIZONTAL_ALIGNMENT_LEFT,20,12,Color("fff2cf"))
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
		draw_texture_rect(DemoArt.icon(f.kind),Rect2(at-Vector2.ONE*extent/2,Vector2.ONE*extent),false)

func energy_fill()->StyleBoxFlat:
	var skin:=StyleBoxFlat.new();skin.bg_color=Color("8ac644");skin.set_corner_radius_all(3);return skin
