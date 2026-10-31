class_name PlayChrome
extends Control
var app: Node
var flights: Array[Dictionary]=[]
var pulse := {"wood":0.0,"stone":0.0,"tokens":0.0}
var styles: Dictionary={}
var portrait: Texture2D
var last_map_position := Vector2.INF
func _init(owner_app: Node) -> void: app=owner_app
func _ready() -> void:
	app.model.changed.connect(queue_redraw)
	resized.connect(queue_redraw)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/ui/hero_portrait.png"): portrait=load("res://assets/ui/hero_portrait.png")
func slot(kind: String) -> Rect2:
	var i: int=["wood","stone","meat","berries","tokens"].find(kind)
	if kind=="tokens":return Rect2(app.w-app.safe.x-62,app.h-app.safe.y-66,62,62)
	return Rect2(Vector2(app.w-app.safe.x-390+i*68,app.safe.y+5),Vector2(66,36))
func gained(kind: String, at: Vector2) -> void:
	flights.append({"kind":kind,"world":at,"age":0.0})
func clear_effects() -> void: flights.clear();queue_redraw()
func _process(delta: float) -> void:
	var moving_map := false
	if is_instance_valid(app.world):
		var p: Vector2=app.world.player.position
		moving_map=p!=last_map_position
		last_map_position=p
	var active := moving_map or not flights.is_empty()
	for key in pulse: active=active or pulse[key]>0
	if not active:return
	for key in pulse: pulse[key]=maxf(0,pulse[key]-delta*2.5)
	for f in flights:
		f.age+=delta
		if f.age>=0.85: pulse[f.kind]=1.0
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
	draw_string(font,origin+Vector2(0,18),"RoxHistory",HORIZONTAL_ALIGNMENT_LEFT,180,21,Color("fff0d1"))
	draw_circle(origin+Vector2(31,57),31,Color("221b14"))
	if portrait:draw_texture_rect(portrait,Rect2(origin+Vector2(4,30),Vector2(54,54)),false)
	draw_arc(origin+Vector2(31,57),31,0,TAU,64,Color("fff7e0"),3,true)
	draw_string(font,origin+Vector2(74,44),"새벽 · Lv.—",HORIZONTAL_ALIGNMENT_LEFT,150,15,Color("fff1d4"))
	frame(Rect2(origin+Vector2(74,53),Vector2(145,15)),Color("bd2d17"),Color("a77942"))
	draw_string(font,origin+Vector2(121,65),"— / —",HORIZONTAL_ALIGNMENT_LEFT,75,12,Color("fff4da"))
	frame(Rect2(origin+Vector2(74,74),Vector2(122,9)),Color("4b8a32"),Color("a77942"))
	draw_style_box(DesignSkin.style("ivory"),Rect2(app.w-app.safe.x-394,app.safe.y,280,44))
	for key in ["wood","stone","meat","berries"]:
		var rect:=slot(key);var beat: float=pulse.get(key,0.0)
		var tex:=DemoArt.icon(key)
		draw_texture_rect(tex,Rect2(rect.position+Vector2(6,6),Vector2(28,28)),false)
		draw_string(font,rect.position+Vector2(36,27),str(int(app.model.state[key])) if app.model.state.has(key) else "—",HORIZONTAL_ALIGNMENT_LEFT,30,16,Color("49321e"))
		if beat>0:
			var c:=rect.position+Vector2(65,8)
			draw_line(c-Vector2(5,0),c+Vector2(5,0),Color(1,.9,.5,beat),2,true)
			draw_line(c-Vector2(0,5),c+Vector2(0,5),Color(1,.9,.5,beat),2,true)
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
		var from: Vector2=app.world.get_global_transform_with_canvas()*f.world
		var to:=slot(f.kind).get_center()
		var t: float=clampf(f.age/0.85,0,1)
		var q:=smoothstep(0.12,1.0,t)
		var control: Vector2=from.lerp(to,0.45)+Vector2(0,-100)
		var at: Vector2=from*(1-q)*(1-q)+control*2*q*(1-q)+to*q*q-Vector2(0,sin(t*PI)*20)
		var extent:=lerpf(40,30,q)
		draw_circle(at,extent*0.65,Color(1,.85,.4,.15))
		draw_texture_rect(DemoArt.icon(f.kind),Rect2(at-Vector2.ONE*extent/2,Vector2.ONE*extent),false)
