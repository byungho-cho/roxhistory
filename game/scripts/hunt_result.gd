extends Control

const ART := "res://assets/ui/hunt-result/"
const CELL := Vector2i(388,516)
const ATLAS_SIZE := Vector2i(2328,3096)
const RESULT_COLUMN_X := 498.0
const RESULT_TITLE_SAFE_Y := 80.0
const RESULT_TITLE_GLYPH_Y := 97.0
const STAGE_CONTEXT_FONT := 29
const CTA_FIRST_X := 82.0
const CTA_SECOND_X := CTA_FIRST_X + 184.0
const CTA_WIDTH := 170.0
const FAILURE_ROW_WIDTH := CTA_SECOND_X + CTA_WIDTH
const ACTOR_FRAME := Rect2(-350, 0, 960, 540)
const VICTORY_LEFT_SHIFT := 28.0
const VICTORY_SWING_MARGIN_SHIFT := 50.0
var app: Node
var won: bool
var stars := 0
var reward: Dictionary = {}
const STAR_REVEAL_START := .28
const STAR_REVEAL_STEP := .28
var star_labels: Array[Label] = []
var star_elapsed := 0.0
var paper_layer: Node2D
var paper_motion := false
var reduced_motion := false
var frame_art: AtlasTexture
var elapsed := 0.0
var leaving := false
var progression_advanced:=false
var use_han_field := false
var result_video:VideoStreamPlayer
var result_last:TextureRect
var result_first:TextureRect
var video_finished:=false
var result_details: Control
var result_actions: Control
var stage_context: Label
var village_back: DemoButton
var village_back_icon: TextureRect
const FIELD_ART := "res://assets/ui/hunt-readiness/"
const ACTOR_MASK := """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV * vec2(0.5, 1.0);
	vec3 rgb = texture(TEXTURE, uv).rgb;
	float matte = texture(TEXTURE, uv + vec2(0.5, 0.0)).r;
	COLOR = vec4(rgb, smoothstep(0.025, 0.975, matte));
}
"""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.name = "ResultViewportBackdrop"
	shade.color = Color(0.06,.045,.03,.30)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layout := Control.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layout)
	layout.size = Vector2(960,540)
	var details := Control.new()
	details.name = "ResultDetails"
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(details)
	result_details = details
	result_actions = Control.new()
	result_actions.name = "ResultActions"
	result_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(result_actions)
	resized.connect(fit.bind(layout))
	fit(layout)
	var chapter: int = app.hunt_stage / 6
	var stage: int = app.hunt_stage % 6
	var story := int(app.chapter_one_story_number(int(app.hunt_stage)))
	if story > 0:
		chapter = 0
		stage = story - 1
	var region := "초원" if chapter == 0 else "숲"
	var boss := story == 10 if story > 0 else stage == 5
	stage_context = app.label(self,"%d장 · %s / %s" % [chapter+1,region,"보스" if boss else "%d단계" % (stage+1)],STAGE_CONTEXT_FONT,Color("fff0d0"))
	stage_context.name = "ResultStageContext"
	stage_context.size = Vector2(410,24)
	stage_context.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stage_context.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_text_shadow(stage_context)
	var accent := Color("ffcf75") if won else Color("9dd5ff")
	write(details,"사냥 성공" if won else "사냥 실패",Rect2(-2,77,430,70),62,accent)
	add_title_rule(details,accent)
	if won and use_han_field:
		var replay:=int(app.model.state.get("hunt_cleared",0))>int(app.hunt_stage) and not progression_advanced
		var message := "이미 완료한 사냥입니다." if replay else "진행 저장 상태를 확인해 주세요."
		if progression_advanced:
			message = "진행 보상"
			if app.next_hunt_stage_id() >= 0:
				message = "다음 단계 해금" if story > 1 else "진행 보상 · 다음 단계 해금"
		write(details,message,Rect2(0,173,420,28),19,Color("fff0d0"))
	reduced_motion = app.reduced_ui_motion()
	if won and stars>0:
		for i in stars:
			var star: Label = app.label(details,"★",36,accent)
			star.position = Vector2(i*37,214)
			star.size = Vector2(38,48)
			star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			apply_text_shadow(star)
			star.visible = reduced_motion
			star_labels.append(star)
	if won and int(reward.get("meat",0)) > 0:
		app.picture(details,DemoArt.icon("meat"),Rect2(0,267,35,35)).name = "HuntRewardMeatIcon"
		var receipt: Label = app.label(details,"고기 +%d" % int(reward.meat),22,Color("fff0d0"))
		receipt.name = "HuntRewardMeat"
		receipt.position = Vector2(45,265)
		receipt.size = Vector2(345,38)
		receipt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		receipt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		apply_text_shadow(receipt)
	paper_motion = won and not reduced_motion
	if paper_motion:
		paper_layer = Node2D.new()
		layout.add_child(paper_layer)
		layout.move_child(paper_layer,0)
		paper_layer.draw.connect(_draw_paper)
	if not won:
		write(details,"전력을 정비하고 다시 도전하세요.",Rect2(0,173,390,21),17,Color("fff0d0"))
		followup(details,"전투력 향상",204,"icon-spear.png")
		followup(details,"모집",269,"icon-horn.png")
	village_back = app.button(self,"",func(): _leave(app.leave_hunt_result_to_village))
	village_back.name = "ResultBackToVillage"
	village_back.custom_minimum_size = Vector2.ZERO
	village_back.size = Vector2(52,52)
	for state in ["normal","hover","pressed","focus"]:
		village_back.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	village_back_icon = app.picture(village_back,preload("res://assets/ui/d0024/08-ui-back-button.png"),Rect2(4,4,44,44))
	fit(layout)
	if won:
		result_button(result_actions,"사냥터 선택",CTA_FIRST_X,false,app.close_hunt).name = "ResultStageSelect"
		if app.next_hunt_stage_id() >= 0:
			result_button(result_actions,"다음 스테이지",CTA_SECOND_X,true,app.prepare_next_hunt).name = "ResultNextStage"
	else:
		result_button(result_actions,"마을로",CTA_FIRST_X,false,app.leave_hunt_result_to_village).name = "ResultLeave"
		result_button(result_actions,"다시 준비",CTA_SECOND_X,true,app.retry_hunt).name = "ResultRetry"
	if (won or use_han_field) and build_field_video(layout):
		set_process(true)
		return
	if won:
		set_process(paper_motion or (not reduced_motion and not star_labels.is_empty()))
		return
	var prefix := ART + "hunt-result-failure"
	var art: TextureRect = app.picture(layout,load(prefix+"-fallback.png"),Rect2(82,74,319,425))
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(paper_motion or (not reduced_motion and not star_labels.is_empty()))
	if not reduced_motion:
		var texture := load(prefix+"-loop-atlas.png") as Texture2D
		if texture and Vector2i(texture.get_size()) == ATLAS_SIZE:
			frame_art = AtlasTexture.new()
			frame_art.atlas = texture
			frame_art.region = Rect2(Vector2.ZERO,Vector2(CELL))
			frame_art.filter_clip = true
			art.texture = frame_art
			set_process(true)

func fit(layout: Control) -> void:
	var inset:Vector2=app.safe
	var factor := minf((size.x-inset.x*2)/960.0,(size.y-inset.y*2)/540.0)
	layout.scale = Vector2.ONE * maxf(.01,factor)
	layout.position = (size-layout.size*layout.scale)*.5
	# Use some of the extra vertical space without scaling or moving the actor.
	var extra_height := maxf(0.0, (size.y - inset.y*2.0) / layout.scale.y - layout.size.y)
	result_actions.position = Vector2(RESULT_COLUMN_X, 34.0 + minf(extra_height*.30, 60.0))
	var safe_origin := Vector2.ZERO
	var top_left := inset
	if OS.has_feature("android"):
		var area := DisplayServer.get_display_safe_area()
		var physical := Vector2(DisplayServer.screen_get_size())
		safe_origin = (Vector2(area.position)*size/physical).clamp(Vector2.ZERO,size) if physical.x>0 and physical.y>0 and area.has_area() else inset
		top_left = safe_origin
	var glyph_top := safe_origin.y + RESULT_TITLE_SAFE_Y
	result_details.position = Vector2(RESULT_COLUMN_X,(glyph_top-layout.position.y)/layout.scale.y-RESULT_TITLE_GLYPH_Y)
	if is_instance_valid(village_back):
		var control_scale := maxf(.65,factor)
		village_back.position = top_left + Vector2(14,12)*control_scale
		village_back.size = Vector2.ONE * 52.0 * control_scale
		village_back_icon.position = Vector2.ONE * 4.0 * control_scale
		village_back_icon.size = Vector2.ONE * 44.0 * control_scale
		stage_context.scale = Vector2.ONE * control_scale
		stage_context.position = village_back.position + Vector2(69,(52.0-stage_context.size.y)*.5) * control_scale

func write(parent: Control, value: String, rect: Rect2, font_size: int, color: Color) -> void:
	var label: Label = app.label(parent,value,font_size,color)
	label.position = rect.position
	label.size = rect.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	apply_text_shadow(label)

func apply_text_shadow(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color", Color(.12,.09,.045,.45))
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",2)

func add_title_rule(parent: Control, accent: Color) -> void:
	var stops := Gradient.new()
	stops.colors = PackedColorArray([Color(accent,.92),Color(accent,.58),Color(accent,0.0)])
	stops.offsets = PackedFloat32Array([0.0,.32,1.0])
	var gradient := GradientTexture2D.new()
	gradient.gradient = stops
	gradient.width = 108
	gradient.height = 3
	gradient.fill_to = Vector2.RIGHT
	var rule := TextureRect.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.texture = gradient
	parent.add_child(rule)
	rule.position = Vector2(0,161)

func _leave(callback: Callable) -> void:
	if leaving or app.hunt_preparing:
		return
	leaving = true
	callback.call()
	# A canceled async warm-up leaves this result visible and usable.
	if app.hunt_preparing:
		while is_inside_tree() and app.hunt_preparing:
			await get_tree().process_frame
		if is_inside_tree():
			leaving = false

func result_button(parent: Control, value: String, x: float, primary: bool, callback: Callable) -> DemoButton:
	var button: DemoButton = app.button(parent,value,func(): _leave(callback))
	button.position = Vector2(x,427)
	button.custom_minimum_size = Vector2.ZERO
	button.size = Vector2(CTA_WIDTH,52)
	for state in ["normal","hover","pressed","focus"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for key in ["font_color","font_hover_color","font_pressed_color"]:
		button.add_theme_color_override(key,Color("49321e") if primary else Color("f3f5f6"))
	var path := "button-gold.png" if primary else "button-silver.png"
	var skin: TextureRect = app.picture(button,load(ART+path),Rect2(Vector2.ZERO,button.size))
	skin.stretch_mode = TextureRect.STRETCH_SCALE
	skin.show_behind_parent = true
	return button

func followup(parent: Control, value: String, y: float, icon: String) -> void:
	var row := Panel.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(.125,.143,.148,.75)
	skin.border_color = Color(.66,.79,.83,.37)
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(10)
	row.add_theme_stylebox_override("panel",skin)
	parent.add_child(row)
	row.position = Vector2(0,y)
	row.name = "ResultFailureHint"
	row.size = Vector2(FAILURE_ROW_WIDTH,56)
	app.picture(row,load(ART+icon),Rect2(10,8,40,40))
	write(row,value,Rect2(62,0,220,56),21,Color("eae6db"))
	write(row,"준비 중",Rect2(FAILURE_ROW_WIDTH-108,0,66,56),15,Color("c2c9ca"))
	app.picture(row,preload("res://assets/ui/hunt-result/chevron-right.svg"),Rect2(FAILURE_ROW_WIDTH-37,18,20,20))

func _draw_paper() -> void:
	var time := star_elapsed - STAR_REVEAL_START - maxi(0,star_labels.size()-1)*STAR_REVEAL_STEP
	if time < 0.0: return
	var colors: Array[Color] = [Color("cf3641"),Color("ef6643"),Color("ffb583"),Color("e9d7a9"),Color("2d89bb"),Color("60b3d7"),Color("3e9382"),Color("54a355"),Color("f5be45"),Color("ede0d4")]
	var wave := floori(time / 2.75)
	for w in range(maxi(0,wave-1),wave+1):
		var seed := RandomNumberGenerator.new()
		seed.seed = 191 + 83*w
		for j in (330 if w==0 else 190):
			var side := j % 2
			var center := Vector2(114,333) if side==0 else Vector2(898,300)
			if w%2==1: center.y += 39.0 if side else -36.0
			var angle := (-1.23 if side==0 else -2.02) + seed.randf_range(-1.19,1.19)
			var force := seed.randf_range(192.0,690.0)
			var life := seed.randf_range(2.1,3.8)
			var radius := seed.randf_range(3.4,8.7)*(1.8 if j%5==0 else 1.0)
			var phase := seed.randf()*TAU
			var lag := seed.randf_range(0.0,.21)
			var age := time-w*2.75-lag
			if age <= 0.0 or age >= life: continue
			var travel := (1.0-exp(-1.86*age))/1.86
			var at := center + Vector2(cos(angle),sin(angle))*force*travel
			at.x += 24.0*maxf(0.0,age-.22)*sin(age*2.7+phase)
			at.y += (28.0+phase*4.0)*age*age
			if not Rect2(0,0,960,540).has_point(at): continue
			if Rect2(488,67,240,171).has_point(at) or Rect2(25,18,289,61).has_point(at) or Rect2(568,437,344,103).has_point(at): continue
			var width := radius*(.19+.81*absf(cos(phase+age*7.3)))
			var height := radius*.63
			var twist := phase+age*3.1
			var poly := PackedVector2Array()
			for v: Vector2 in [Vector2(-width*.8,-height*.8),Vector2(width*.65,-height),Vector2(width,.1),Vector2(width*.28,height),Vector2(-width*.73,height*.46)]:
				poly.append(at+v.rotated(twist))
			var color := colors[j%colors.size()]
			color.a = .94*minf(1,age/.1)*minf(1,(life-age)/.36)
			paper_layer.draw_colored_polygon(poly,color)


func _process(delta: float) -> void:
	if app.application_active and not reduced_motion and (paper_motion or not star_labels.is_empty()):
		star_elapsed += delta
		for i in star_labels.size():
			star_labels[i].visible = star_elapsed >= STAR_REVEAL_START + STAR_REVEAL_STEP*i
		if paper_motion: paper_layer.queue_redraw()
	if is_instance_valid(result_video):
		result_video.paused=not app.application_active
		if result_video.is_playing():
			var t := result_video.stream_position
			if t>.03:result_first.hide()
			if won:
				# Give the spear room at the widest four frames, then settle back left.
				var swing_margin := smoothstep(.87,1.02,t) * (1.0 - smoothstep(1.26,1.43,t))
				result_video.position.x = ACTOR_FRAME.position.x - VICTORY_LEFT_SHIFT + VICTORY_SWING_MARGIN_SHIFT * swing_margin
		return
	if not app.application_active or not is_instance_valid(frame_art): return
	elapsed = fposmod(elapsed+delta,2.0)
	var frame := int(elapsed*18)
	frame_art.region.position = Vector2((frame%6)*CELL.x,(frame/6)*CELL.y)

func build_field_video(layout:Control)->bool:
	var prefix:=FIELD_ART+"han-"+("success" if won else "failure")
	var stream_path := prefix+".ogv"
	var stream := load(stream_path) as VideoStream if not reduced_motion and ResourceLoader.exists(stream_path) else null
	var final_art := load(prefix+"-last.png") as Texture2D
	if final_art == null:return false
	var frame := ACTOR_FRAME
	if won:frame.position.x -= VICTORY_LEFT_SHIFT
	result_last=app.picture(layout,final_art,frame)
	result_last.name="ConfirmedResultStill"
	layout.move_child(result_last,0)
	if reduced_motion or stream==null:return true
	result_last.hide()
	result_video=VideoStreamPlayer.new()
	result_video.name="ConfirmedResultMotion"
	result_video.stream=stream
	result_video.expand=true
	result_video.position=frame.position
	result_video.size=frame.size
	result_video.loop=false
	result_video.volume_db=-80.0
	result_video.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = ACTOR_MASK
	var mask := ShaderMaterial.new()
	mask.shader = shader
	result_video.material = mask
	layout.add_child(result_video)
	layout.move_child(result_video,1)
	result_first=app.picture(layout,load(prefix+"-first.png"),frame)
	layout.move_child(result_first,2)
	result_video.finished.connect(func():
		video_finished=true
		result_last.show()
		result_video.hide()
		result_first.hide())
	result_video.play()
	return true

func _exit_tree()->void:
	if is_instance_valid(result_video):
		result_video.stop()
		result_video.stream=null
