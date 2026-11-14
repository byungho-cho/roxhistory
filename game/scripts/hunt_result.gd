extends Control

const ART := "res://assets/ui/hunt-result/"
const CELL := Vector2i(388,516)
const ATLAS_SIZE := Vector2i(2328,3096)
var app: Node
var won: bool
var frame_art: AtlasTexture
var elapsed := 0.0
var leaving := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.07,.06,.04,.67)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layout := Control.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layout)
	layout.size = Vector2(960,540)
	resized.connect(fit.bind(layout))
	fit(layout)
	var chapter: int = app.hunt_stage / 6
	var stage: int = app.hunt_stage % 6
	var region := "초원" if chapter == 0 else "숲"
	write(layout,"%d장 · %s / %s" % [chapter+1,region,"보스" if stage == 5 else "%d단계" % (stage+1)],Rect2(62,76,420,24),19,Color("fff0d0"))
	var accent := Color("ffcf75") if won else Color("9dd5ff")
	write(layout,"사냥 성공" if won else "사냥 실패",Rect2(60,105,430,70),62,accent)
	var rule := ColorRect.new()
	rule.color = accent
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(rule)
	rule.position = Vector2(62,185)
	rule.size = Vector2(57,3)
	if not won:
		write(layout,"전력을 정비하고 다시 도전하세요.",Rect2(62,210,390,21),17,Color("fff0d0"))
		followup(layout,"전투력 향상",239,"icon-spear.png")
		followup(layout,"모집",304,"icon-horn.png")
	result_button(layout,"마을로",62,false,func(): app.show_screen("play"))
	result_button(layout,"사냥터 선택" if won else "다시 준비",246,true,app.close_hunt if won else app.retry_hunt)
	var prefix := ART + ("hunt-result-success" if won else "hunt-result-failure")
	var art: TextureRect = app.picture(layout,load(prefix+"-fallback.png"),Rect2(562,74,319,425))
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(false)
	if not OS.get_cmdline_user_args().has("--reduce-motion"):
		var texture := load(prefix+"-loop-atlas.png") as Texture2D
		if texture and Vector2i(texture.get_size()) == ATLAS_SIZE:
			frame_art = AtlasTexture.new()
			frame_art.atlas = texture
			frame_art.region = Rect2(Vector2.ZERO,Vector2(CELL))
			frame_art.filter_clip = true
			art.texture = frame_art
			set_process(true)

func fit(layout: Control) -> void:
	var factor := minf((size.x-app.safe.x*2)/960.0,(size.y-app.safe.y*2)/540.0)
	layout.scale = Vector2.ONE * maxf(.01,factor)
	layout.position = (size-layout.size*layout.scale)*.5

func write(parent: Control, value: String, rect: Rect2, font_size: int, color: Color) -> void:
	var label: Label = app.label(parent,value,font_size,color)
	label.position = rect.position
	label.size = rect.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func result_button(parent: Control, value: String, x: float, primary: bool, callback: Callable) -> void:
	var button: DemoButton = app.button(parent,value,func():
		if leaving: return
		leaving = true
		callback.call())
	button.position = Vector2(x,427)
	button.custom_minimum_size = Vector2.ZERO
	button.size = Vector2(170,52)
	for state in ["normal","hover","pressed","focus"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for key in ["font_color","font_hover_color","font_pressed_color"]:
		button.add_theme_color_override(key,Color("49321e") if primary else Color("f3f5f6"))
	var path := "button-gold.png" if primary else "button-silver.png"
	var skin: TextureRect = app.picture(button,load(ART+path),Rect2(Vector2.ZERO,button.size))
	skin.stretch_mode = TextureRect.STRETCH_SCALE
	skin.show_behind_parent = true

func followup(parent: Control, value: String, y: float, icon: String) -> void:
	var row := Panel.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(.14,.16,.17,.83)
	skin.border_color = Color(.67,.71,.74,.44)
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(8)
	row.add_theme_stylebox_override("panel",skin)
	parent.add_child(row)
	row.position = Vector2(62,y)
	row.size = Vector2(391,56)
	app.picture(row,load(ART+icon),Rect2(10,8,40,40))
	write(row,value,Rect2(62,0,220,56),20,Color("cac6bd"))
	write(row,"준비 중",Rect2(283,0,66,56),14,Color("cac6bd"))
	app.picture(row,preload("res://assets/ui/hunt-result/chevron-right.svg"),Rect2(354,18,20,20))

func _process(delta: float) -> void:
	if not app.application_active: return
	elapsed = fposmod(elapsed+delta,2.0)
	var frame := int(elapsed*18)
	frame_art.region.position = Vector2((frame%6)*CELL.x,(frame/6)*CELL.y)
