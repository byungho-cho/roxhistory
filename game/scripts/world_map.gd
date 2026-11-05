class_name VillageWorldMap
extends Control
## Finite map camera. Zoom is defined by visible village width, not PNG padding.
var app:Node
var zoom:=1.0
var center:=Vector2.ZERO
var fingers:Dictionary={}
var mouse_down:=false
var last:=Vector2.ZERO
var village:Texture2D
var visible_fraction:=0.69
var terrain:Texture2D
var mountain:TextureRect
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	village=AssetCatalog.texture("WORLD-VILLAGE")
	visible_fraction=1058.0/1536.0 # Alpha > 0.5 measured from approved WM-001.
	terrain=AssetCatalog.texture("TERRAIN-VILLAGE")
	mountain=TextureRect.new();mountain.texture=AssetCatalog.texture("WORLD-MOUNTAIN");mountain.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;mountain.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var mask:=ShaderMaterial.new();mask.shader=preload("res://shaders/mountain_mask.gdshader");mask.set_shader_parameter("mask_texture",load("res://assets/refactor-v035/mountain-mask.svg"));mountain.material=mask;add_child(mountain)
	size=Vector2(app.w,app.h)
	clip_contents=true
	set_process_input(false);hide()
func activate(value:bool)->void:
	visible=value;set_process_input(value);clear_input();clamp_camera();queue_redraw()
func clear_input()->void:fingers.clear();mouse_down=false
func factor()->float:return app.w/12.0/visible_fraction/village.get_width()*zoom
func clamp_camera()->void:
	# A finite 5-by-5 reference terrain field; mirrored borders avoid empty space.
	var half:=Vector2(app.w,app.h)*.5/zoom
	var limits:=Vector2(app.w,app.h)*2.5-half
	center=center.clamp(-limits,limits)
func zoom_at(at:Vector2,value:float)->void:
	var anchor:=center+(at-size*.5)/zoom
	zoom=clampf(value,1.0,2.4)
	center=anchor-(at-size*.5)/zoom;clamp_camera();queue_redraw()
func pan(delta:Vector2)->void:center-=delta/zoom;clamp_camera();queue_redraw()
func accepts(at:Vector2)->bool:
	return at.y>app.safe.y+110 and not Rect2(Vector2(app.w-app.safe.x-64,app.safe.y+112),Vector2(64,64)).has_point(at)
func _input(event:InputEvent)->void:
	if not app.application_active or app.modal:return
	if event is InputEventMouseButton and not OS.has_feature("android"):
		if event.ctrl_pressed and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and accepts(event.position):
			zoom_at(event.position,zoom*(1.12 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.12));get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_LEFT:
			mouse_down=event.pressed and accepts(event.position);last=event.position
	elif event is InputEventMouseMotion and mouse_down:pan(event.position-last);last=event.position
	elif event is InputEventScreenTouch:
		if event.pressed and accepts(event.position):fingers[event.index]=event.position
		elif not event.pressed:fingers.erase(event.index)
	elif event is InputEventScreenDrag and fingers.has(event.index):
		var before:Array=fingers.values()
		fingers[event.index]=event.position
		var after:Array=fingers.values()
		if after.size()==1:pan(after[0]-before[0])
		elif after.size()==2:
			var old_mid:Vector2=(before[0]+before[1])*.5
			var mid:Vector2=(after[0]+after[1])*.5
			zoom_at(old_mid,zoom*after[0].distance_to(after[1])/maxf(1,before[0].distance_to(before[1])))
			pan(mid-old_mid)
		get_viewport().set_input_as_handled()
func _notification(what:int)->void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:clear_input()
func _draw()->void:
	if not terrain:return
	var tile:=Vector2(app.w,app.h)
	var crop:=Rect2(terrain.get_size()*Vector2(.209318,.265675),terrain.get_size()*Vector2(.568182,.53135))
	for y in range(-2,3):
		for x in range(-2,3):
			var rect:=Rect2(size*.5+(Vector2(x,y)*tile-tile*.5-center)*zoom,tile*zoom)
			# Reflect alternating reference crops; seams remain a documented art limitation.
			if abs(x)%2==1:rect.position.x+=rect.size.x;rect.size.x=-rect.size.x
			if abs(y)%2==1:rect.position.y+=rect.size.y;rect.size.y=-rect.size.y
			draw_texture_rect_region(terrain,rect,crop)
	var extent:=village.get_size()*factor()
	var at:=size*.5-center*zoom
	var base:float=app.w/1672.0
	mountain.size=Vector2(220,170)*base*zoom
	mountain.position=size*.5+(Vector2(-486,-230)*base-center)*zoom-mountain.size*.5
	for object in [["WORLD-RIVER",Vector2(-703,-220),Vector2(525,175)],["WORLD-LAKE",Vector2(315,240),Vector2(122.5,59.76)]]:
		var dimensions:Vector2=object[2]*base*zoom
		var place:Vector2=size*.5+(object[1]*base-center)*zoom
		draw_texture_rect(AssetCatalog.texture(object[0]),Rect2(place-dimensions*.5,dimensions),false)
	draw_texture_rect(village,Rect2(at-extent*.5,extent),false)
	draw_string(DemoArt.theme().default_font,at+Vector2(-40,extent.y*.38+18),"나의 마을",HORIZONTAL_ALIGNMENT_CENTER,80,16,Color("fff1d4"))
