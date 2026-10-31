class_name PlayChrome
extends Control
var app: Node
var flights: Array[Dictionary]=[]
var pulse := {"wood":0.0,"stone":0.0,"tokens":0.0}
var styles: Dictionary={}
var portrait: Texture2D
func _init(owner_app: Node) -> void: app=owner_app
func _ready() -> void:
	app.model.changed.connect(queue_redraw)
	resized.connect(queue_redraw)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/ui/hero_portrait.png"): portrait=load("res://assets/ui/hero_portrait.png")
func slot(kind: String) -> Rect2:
	var i: int=["wood","stone","tokens"].find(kind)
	return Rect2(Vector2(app.w-app.safe.x-258+i*86,app.safe.y+5),Vector2(80,40))
func gained(kind: String, at: Vector2) -> void:
	flights.append({"kind":kind,"world":at,"age":0.0})
func clear_effects() -> void: flights.clear();queue_redraw()
func _process(delta: float) -> void:
	if flights.is_empty() and pulse.values().all(func(v):return v<=0):return
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
	var origin: Vector2=app.safe+Vector2(76,0)
	frame(Rect2(origin,Vector2(216,SceneStyle.HEADER_HEIGHT)),Color("493020f2"),Color("b88a46"))
	draw_circle(origin+Vector2(25,24),23,Color("221b14"))
	draw_arc(origin+Vector2(25,24),23,0,TAU,64,Color("edc77f"),2,true)
	if portrait: draw_texture_rect(portrait,Rect2(origin+Vector2(3,2),Vector2(44,44)),false)
	draw_string(font,origin+Vector2(58,20),"암사동 강변",HORIZONTAL_ALIGNMENT_LEFT,148,16,Color("fff1cf"))
	draw_string(font,origin+Vector2(58,38),"첫 보금자리",HORIZONTAL_ALIGNMENT_LEFT,148,12,Color("d8bd89"))
	for key in ["wood","stone","tokens"]:
		var rect:=slot(key);var beat: float=pulse[key]
		frame(rect.grow(beat*2),Color("38291eef"),Color("ffe2a0") if beat>0 else Color("b88a46"))
		var tex:=preload("res://assets/ui/seed.svg") if key=="tokens" else DemoArt.icon(key)
		draw_texture_rect(tex,Rect2(rect.position+Vector2(6,6),Vector2(28,28)),false)
		draw_string(font,rect.position+Vector2(43,28),str(int(app.model.state[key])),HORIZONTAL_ALIGNMENT_LEFT,33,20,Color("fff5d8"))
		if beat>0:
			var c:=rect.position+Vector2(65,8)
			draw_line(c-Vector2(5,0),c+Vector2(5,0),Color(1,.9,.5,beat),2,true)
			draw_line(c-Vector2(0,5),c+Vector2(0,5),Color(1,.9,.5,beat),2,true)
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
