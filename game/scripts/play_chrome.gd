class_name PlayChrome
extends Control
var app: Node
var flights: Array[Dictionary]=[]
var pulse := {"wood":0.0,"stone":0.0,"tokens":0.0}
var styles: Dictionary={}
var portrait: Texture2D
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
	if ResourceLoader.exists("res://assets/ui/s40000/portrait.png"): portrait=load("res://assets/ui/s40000/portrait.png")
func slot(kind: String) -> Rect2:
	var i:int=["wood","stone","tokens"].find(kind)
	return Rect2(Vector2(app.w-app.safe.x-330+i*70,app.safe.y+5),Vector2(68,36))
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
	frame(Rect2(origin,Vector2(205,56)),Color(.16,.13,.09,.68),Color(.65,.48,.22,0))

	if portrait:draw_texture_rect(portrait,Rect2(origin+Vector2(-2,-2),Vector2(58,58)),false)

	draw_string(font,origin+Vector2(64,22),"새벽",HORIZONTAL_ALIGNMENT_LEFT,138,16,Color("fff1d4"))
	draw_string(font,origin+Vector2(64,43),"정착",HORIZONTAL_ALIGNMENT_LEFT,32,12,Color("d6e5ab"))
	frame(Rect2(origin+Vector2(98,33),Vector2(94,9)),Color(.14,.16,.08,.75),Color(0,0,0,0))
	if app.model.built_count()>0:frame(Rect2(origin+Vector2(99,34),Vector2(92*app.model.built_count()/3.0,7)),Color("8ac644"),Color(0,0,0,0))
	for key in ["wood","stone","tokens"]:
		var rect:=slot(key);var beat:float=pulse.get(key,0.0)
		frame(rect,Color(.15,.12,.08,resource_alpha*.32),Color(.65,.48,.22,0.0))
		var extent:=28.0+beat*4
		draw_texture_rect(DemoArt.icon(key),Rect2(rect.position+Vector2(3,3),Vector2(extent,extent)),false,Color(1,1,1,resource_alpha))
		draw_string(font,rect.position+Vector2(34,25),str(int(displayed_tokens)) if key=="tokens" else str(int(app.model.state[key])),HORIZONTAL_ALIGNMENT_LEFT,32,15,Color(1,.96,.85,resource_alpha))
	var center:=Vector2(app.w-app.safe.x-50,app.safe.y+50)
	draw_circle(center,51,Color("49321e"))
	var points:=PackedVector2Array();var uv:=PackedVector2Array()
	for i in 64:
		var d:=Vector2.from_angle(TAU*i/64.0)
		points.append(center+d*48);uv.append(Vector2(.5,.5)+d*.5)
	draw_colored_polygon(points,Color.WHITE,uv,preload(SceneStyle.TERRAIN))
	draw_arc(center,50,0,TAU,64,Color("c8a15e"),3,true)
	var normalized: Vector2=app.world.player.position/Vector2(2400,1350)-Vector2(.5,.5)
	var dot:=center+(normalized*96).limit_length(45)
	draw_circle(dot,4,Color("ffe28b"));draw_arc(dot,5,0,TAU,16,Color("49321e"),1,true)
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
