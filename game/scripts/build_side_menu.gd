class_name BuildSideMenu
extends Control
var app:Node
var hut:DemoButton
var outpost_button:DemoButton
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
	name="BuildSideMenu";mouse_filter=Control.MOUSE_FILTER_IGNORE;size=Vector2(132,68);hide()
	var tower:=item("초소",AssetCatalog.texture("BLD-OUTPOST"),Vector2.ZERO,func():pass)
	var lock:=AtlasTexture.new();lock.atlas=preload("res://assets/figma-latest/023a3.png");lock.region=Rect2(1152,558,364,400);lock.filter_clip=true
	app.picture(tower,lock,Rect2(47,0,14,16))
	outpost_button=tower
	tower.disabled=true;tower.hint_text="초소는 아직 열리지 않았어요"
	hut=item("움집",AssetCatalog.texture("BLD-HUT-L1"),Vector2(68,0),select_hut)
	hut.hint_text="나무 20개와 돌 20개가 필요해요"
func item(title:String,texture:Texture2D,at:Vector2,callback:Callable)->DemoButton:
	var b:DemoButton=app.button(self,"",callback);b.position=at;b.custom_minimum_size=Vector2(64,68);b.size=Vector2(64,68)
	for state in ["normal","hover","pressed","disabled"]:b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	app.picture(b,texture,Rect2(7,0,50,50))
	var brush:Texture2D=preload("res://assets/ui/brush/resource-slot-brush@2x.png")
	app.picture(b,brush,Rect2(3,40,58,20))
	var caption:Label=app.label(b,title,11,Color("fff5d6"));caption.position=Vector2(3,40);caption.size=Vector2(58,20);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	b.enable_art_feedback()
	return b
func _process(_delta:float)->void:
	if not visible:return
	# Do not activate the unverified legacy tower artwork as the approved L1.
	outpost_button.disabled=true
	outpost_button.hint_text=app.building_workflow.outpost_block_reason()
	position=app.build_button.global_position+Vector2(-68,-71)
	hut.disabled=not app.model.can_build()
	if app.world_map_open or app.modal:hide()
func select_hut()->void:
	if not app.model.can_build():app.toast(hut.hint_text);return
	hide();app.choosing_plot=true;app.world.show_candidates=true;app.world.queue_redraw()
