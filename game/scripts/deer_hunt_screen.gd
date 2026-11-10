extends Control

const RULES := preload("res://scripts/deer_hunt_rules.gd")
const DESIGN := Vector2(960,540)
const GRASS := preload("res://assets/environment/terrain-clean-v033.png")
const TREE := preload("res://assets/environment/tree-v018.png")
const GEAR := preload("res://assets/ui/v0158/settings.svg")
const SPEAR := preload("res://assets/ui/s40000/hunt-spear-v001.png")
const AXE := preload("res://assets/ui/s40000/craft-axe-v001.png")
const HERO_MARK := preload("res://assets/ui/s40000/portrait.png")
const HUNTER_SLOTS := [Vector2(408,300),Vector2(336,269),Vector2(344,345)]
const PREP_SLOTS := [Vector2(218,420),Vector2(145,342),Vector2(105,453)]
const DEER_SLOT := Vector2(573,303)

var app: Node
var rules := RULES.new()
var canvas: Control
var preparation: Control
var combat: Control
var hunters: Array[HybridCharacter] = []
var deer: WorldAnimal
var hunter_bar: ProgressBar
var deer_bar: ProgressBar
var gauge_text: Label
var skill_buttons: Dictionary = {}
var skill_icons: Dictionary = {}
var ready_flashes: Dictionary = {}
var running := false
var result_shown := false
var result_timer := 0.0
var pose_clock := 1.0
var actor_delta := 0.0
var pose := ""
var exit_button: DemoButton

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ground: TextureRect = app.picture(self,GRASS,Rect2())
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = DESIGN
	add_child(canvas)
	canvas.draw.connect(draw_stage)
	for rect in [Rect2(-55,-74,275,275),Rect2(738,-82,280,275),Rect2(-105,306,205,235)]:
		var tree: TextureRect = app.picture(canvas,TREE,rect)
		tree.modulate = Color(.79,.85,.64)
	var actors := Node2D.new()
	actors.y_sort_enabled = true
	canvas.add_child(actors)
	for model in ["meshy01/hero","residents/sturdy_male","residents/female"]:
		var hunter := HybridCharacter.new()
		hunter.model_path = "res://assets/characters/"+model+".glb"
		hunter.render_size_factor = .5
		actors.add_child(hunter)
		hunter.set_enabled(true)
		hunter.use_training_spear()
		hunters.append(hunter)
	deer = WorldAnimal.new()
	deer.world_height = 90
	deer.heading = -PI*.5
	deer.position = DEER_SLOT
	actors.add_child(deer)
	deer.set_physics_process(false)
	deer.footprint_body.collision_layer = 0
	deer.footprint_body.collision_mask = 0
	deer.scale = Vector2.ONE
	build_preparation()
	build_combat()
	resized.connect(fit_layout)
	fit_layout()
	update_actors(0.1)

func fit_layout() -> void:
	var inset := Vector2(20,14)
	if OS.has_feature("android"):
		var area := DisplayServer.get_display_safe_area()
		var physical := Vector2(DisplayServer.screen_get_size())
		if physical.x>0 and physical.y>0:
			var edge := Vector2(maxi(area.position.x,int(physical.x)-area.end.x),maxi(area.position.y,int(physical.y)-area.end.y))
			inset = inset.max(edge*size/physical)
	var fit := minf((size.x-inset.x*2)/DESIGN.x,(size.y-inset.y*2)/DESIGN.y)
	canvas.scale = Vector2.ONE*maxf(.1,fit)
	canvas.position = (size-DESIGN*canvas.scale)*.5

func build_preparation() -> void:
	preparation = layer()
	var enter: DemoButton = app.button(preparation,"",start_combat)
	enter.name = "PrepareTap"
	enter.custom_minimum_size = Vector2.ZERO
	enter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for state in ["normal","hover","pressed","focus"]:enter.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	# The full viewport also advances the preparation on wider screens.
	var back := make_button(preparation,"‹   사냥 준비",Rect2(16,12,170,51),app.close_hunt)
	back.name = "PrepareBack"
	var card := plaque(preparation,Rect2(662,38,278,450),Color("ecd2a3"),Color("764c2a"))
	caption(card,"첫 사냥",Rect2(12,29,254,43),31,Color("49321e"))
	caption(card,"숲 가장자리",Rect2(12,79,254,38),22,Color("49321e"))
	caption(card,"목표   사슴 처치",Rect2(12,140,254,38),20,Color("49321e"))
	caption(card,"사냥꾼 3명",Rect2(12,223,254,38),19,Color("49321e"))
	caption(card,"화면을 터치하여 전투 시작",Rect2(8,348,262,55),18,Color("49321e"))

func build_combat() -> void:
	combat = layer()
	combat.hide()
	var team := plaque(combat,Rect2(16,12,242,45),Color("503317"),Color("e2b273"))
	caption(team,"사냥대",Rect2(8,0,78,45),19)
	hunter_bar = hp_bar(team,Rect2(91,15,135,15),Color("84b73a"))
	var place := plaque(combat,Rect2(381,12,198,46),Color("503317"),Color("e2b273"))
	caption(place,"숲 가장자리",Rect2(Vector2.ZERO,place.size),22)
	exit_button = make_button(combat,"",Rect2(888,10,56,56),app.close_hunt)
	exit_button.name = "ExitHunt"
	exit_button.tooltip_text = "사냥 종료"
	app.picture(exit_button,GEAR,Rect2(5,5,46,46))
	var target := plaque(combat,Rect2(528,177,100,46),Color("503317"),Color("e2b273"))
	caption(target,"사슴",Rect2(0,0,100,28),17)
	deer_bar = hp_bar(target,Rect2(8,28,84,9),Color("c8543e"))
	var objective := plaque(combat,Rect2(302,475,356,42),Color("ecd2a3"),Color("987046"))
	caption(objective,"사슴을 처치하세요",Rect2(Vector2.ZERO,objective.size),21,Color("49321e"))
	# Bounds are kept separate so the large thrust control cannot steal a skill tap.
	add_skill("thrust",Rect2(778,341,102,102),SPEAR)
	add_skill("strike",Rect2(797,272,64,64),AXE)
	add_skill("team",Rect2(710,323,64,64),HERO_MARK)
	var gauge_plate := plaque(combat,Rect2(778,447,102,28),Color("164253"),Color("5aa0ae"))
	gauge_text = caption(gauge_plate,"0 / 100",Rect2(Vector2.ZERO,gauge_plate.size),17)
	update_combat_ui()

func layer() -> Control:
	var result := Control.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(result)
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return result

func make_button(parent: Control, title: String, rect: Rect2, callback: Callable) -> DemoButton:
	var button: DemoButton = app.button(parent,title,callback)
	button.custom_minimum_size = Vector2.ZERO
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size",20)
	return button

func plaque(parent: Control, rect: Rect2, color: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel",box(color,border,14))
	parent.add_child(panel)
	return panel

func box(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style

func caption(parent: Control, value: String, rect: Rect2, font_size: int, color := Color("fff0d0")) -> Label:
	var line: Label = app.label(parent,value,font_size,color)
	line.position = rect.position
	line.size = rect.size
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func hp_bar(parent: Control, rect: Rect2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.value = RULES.MAX_HP
	bar.position = rect.position
	bar.size = rect.size
	bar.add_theme_stylebox_override("background",box(Color("302415"),Color("755638"),5))
	bar.add_theme_stylebox_override("fill",box(color,color,5))
	parent.add_child(bar)
	return bar

func add_skill(id: String, rect: Rect2, texture: Texture2D) -> void:
	var info: Dictionary = RULES.SKILLS[id]
	var control := make_button(combat,"",rect,use_skill.bind(id))
	control.name = id
	control.tooltip_text = info.label
	var radius := int(rect.size.x*.5)
	var color := Color("7c4721") if id=="thrust" else Color("984126") if id=="strike" else Color("6b663a")
	control.add_theme_stylebox_override("normal",box(color,Color("edbd68"),radius))
	control.add_theme_stylebox_override("hover",box(color.lightened(.14),Color("ffe4a0"),radius))
	control.add_theme_stylebox_override("pressed",box(color.darkened(.18),Color("e7ba60"),radius))
	control.add_theme_stylebox_override("disabled",box(Color("474747"),Color("969696"),radius))
	var icon_rect := Rect2(rect.size*.16,rect.size*.66)
	var icon: TextureRect = app.picture(control,texture,icon_rect)
	var grayscale := Shader.new()
	grayscale.code = "shader_type canvas_item; uniform bool gray = false; void fragment(){vec4 c=COLOR; if(gray){c.rgb=vec3(dot(c.rgb,vec3(0.299,0.587,0.114)));} COLOR=c;}"
	var material := ShaderMaterial.new()
	material.shader = grayscale
	icon.material = material
	skill_icons[id] = material
	caption(control,"%s  %d"%[info.label,info.cost],Rect2(0,rect.size.y*.71,rect.size.x,22),13)
	skill_buttons[id] = control
	ready_flashes[id] = 0.0

func _gui_input(event: InputEvent) -> void:
	if not running and ((event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed)):
		start_combat()
		accept_event()

func start_combat() -> void:
	if running or not app.application_active:return
	running = true
	preparation.hide()
	combat.show()
	update_actors(.1)

func use_skill(id: String) -> void:
	if not running or not app.application_active or not rules.use_skill(id):return
	play_pose(id)
	update_combat_ui()

func play_pose(id: String) -> void:
	pose = id
	pose_clock = 0.0

func _process(delta: float) -> void:
	if not app.application_active:return
	if running and not result_shown:
		for move in rules.advance(delta):
			play_pose(move)
		for id in ready_flashes:
			ready_flashes[id] = maxf(0,ready_flashes[id]-delta)
		update_combat_ui()
		if not rules.outcome.is_empty():show_result()
	if result_shown:
		result_timer -= delta
		if result_timer<=0:
			app.close_hunt()
			return
	pose_clock += delta
	actor_delta += delta
	if actor_delta>=1.0/30.0:
		update_actors(actor_delta)
		actor_delta = 0.0
	canvas.queue_redraw()

func update_combat_ui() -> void:
	hunter_bar.value = rules.hunter_hp
	deer_bar.value = rules.deer_hp
	gauge_text.text = "%d / %d"%[floori(rules.gauge),int(RULES.MAX_GAUGE)]
	for id in skill_buttons:
		var control: DemoButton = skill_buttons[id]
		var ready := rules.can_use(id)
		if id!="thrust" and running and control.disabled and ready:
			ready_flashes[id] = .42
		control.disabled = not ready
		skill_icons[id].set_shader_parameter("gray",not ready)

func update_actors(delta: float) -> void:
	var beat := sin(clampf(pose_clock/.52,0,1)*PI)
	for i in hunters.size():
		var hunter := hunters[i]
		var attack := running and pose_clock<.52 and pose!="counter" and (i==0 or pose=="team")
		var dodge := running and pose=="counter" and i==0
		var base: Vector2 = HUNTER_SLOTS[i] if running else PREP_SLOTS[i]
		hunter.scale = Vector2.ONE*(.89 if running else 1.13)
		hunter.position = base + Vector2((32 if attack else -18 if dodge else 0)*beat,-5*beat if attack else 0)
		hunter.animate(delta,Vector2.RIGHT,pose_clock*12,dodge,"" if not attack else "hunt",pose_clock,false)
		if attack:
			hunter.blend_bone("spine",Vector3(.10+beat*.12,0,-.08),.9)
			hunter.blend_bone("armR",Vector3(-.88-beat*.38,0,-.15),1)
			hunter.blend_bone("forearmR",Vector3(-.95+beat*.75,0,0),1)
		hunter.tool_3d.visible = true
		hunter.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var charge := running and pose=="counter"
	deer.position = DEER_SLOT+Vector2((-29 if charge else 23)*beat if running else -45,-8*beat if running else -38)
	deer.walking = beat if running else 0.0
	deer.gait_phase = pose_clock*14

func draw_stage() -> void:
	if not running:return
	var center := Vector2(829,392)
	canvas.draw_arc(center,57,-1.24,1.31,38,Color("15272b"),9,true)
	if rules.gauge>0:
		canvas.draw_arc(center,57,-1.24,lerpf(-1.24,1.31,rules.gauge/RULES.MAX_GAUGE),38,Color("57deff"),6,true)
	for id in ["strike","team"]:
		var flash: float = ready_flashes[id]
		if flash<=0:continue
		var button: DemoButton = skill_buttons[id]
		canvas.draw_arc(button.position+button.size*.5,36,0,TAU,40,Color(1,.87,.43,flash/.42),4,true)

func show_result() -> void:
	result_shown = true
	result_timer = 1.6
	var panel := plaque(combat,Rect2(310,208,340,108),Color("503317"),Color("e2b273"))
	caption(panel,"사냥 성공" if rules.outcome=="win" else "사냥 실패",Rect2(Vector2.ZERO,panel.size),32)
