extends Control

const ART := "res://assets/ui/hunt-result/"
const CELL := Vector2i(388,516)
const ATLAS_SIZE := Vector2i(2328,3096)
const RESULT_COLUMN_X := 498.0
const CTA_FIRST_X := 82.0
const CTA_SECOND_X := CTA_FIRST_X + 184.0
const ACTOR_FRAME := Rect2(-350, 0, 960, 540)
var app: Node
var won: bool
var stars := 0
var frame_art: AtlasTexture
var elapsed := 0.0
var leaving := false
var progression_advanced:=false
var use_han_field := false
var result_video:VideoStreamPlayer
var result_last:TextureRect
var result_first:TextureRect
var video_finished:=false
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
	details.position.x = RESULT_COLUMN_X
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(details)
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
	write(details,"%d장 · %s / %s" % [chapter+1,region,"보스" if boss else "%d단계" % (stage+1)],Rect2(0,76,420,24),19,Color("fff0d0"))
	var accent := Color("ffcf75") if won else Color("9dd5ff")
	write(details,"사냥 성공" if won else "사냥 실패",Rect2(-2,105,430,70),62,accent)
	var rule := ColorRect.new()
	rule.color = accent
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(rule)
	rule.position = Vector2(0,185)
	rule.size = Vector2(57,3)
	if won and use_han_field:
		var replay:=int(app.model.state.get("hunt_cleared",0))>int(app.hunt_stage) and not progression_advanced
		var message:=("다음 단계 해금" if story > 1 else "진행 보상 · 다음 단계 해금") if progression_advanced else "이미 완료한 사냥입니다." if replay else "진행 저장 상태를 확인해 주세요."
		write(details,message,Rect2(0,210,420,28),19,Color("fff0d0"))
	if won and stars>0:
		write(details,"★".repeat(stars),Rect2(0,258,420,48),36,accent)
	if not won:
		write(details,"전력을 정비하고 다시 도전하세요.",Rect2(0,210,390,21),17,Color("fff0d0"))
		followup(details,"전투력 향상",239,"icon-spear.png")
		followup(details,"모집",304,"icon-horn.png")
	village_back = app.button(self,"",func(): _leave(app.leave_hunt_result_to_village))
	village_back.name = "ResultBackToVillage"
	village_back.custom_minimum_size = Vector2.ZERO
	village_back.size = Vector2(52,52)
	for state in ["normal","hover","pressed","focus"]:
		village_back.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	village_back_icon = app.picture(village_back,preload("res://assets/ui/d0024/08-ui-back-button.png"),Rect2(4,4,44,44))
	fit(layout)
	if won:
		result_button(details,"사냥터 선택",CTA_FIRST_X,false,app.close_hunt).name = "ResultStageSelect"
		if app.next_hunt_stage_id() >= 0:
			result_button(details,"다음 스테이지",CTA_SECOND_X,true,app.prepare_next_hunt).name = "ResultNextStage"
	else:
		result_button(details,"마을로",CTA_FIRST_X,false,app.leave_hunt_result_to_village).name = "ResultLeave"
		result_button(details,"다시 준비",CTA_SECOND_X,true,app.retry_hunt).name = "ResultRetry"
	if use_han_field and build_field_video(layout):
		set_process(true)
		return
	var prefix := ART + ("hunt-result-success" if won else "hunt-result-failure")
	var art: TextureRect = app.picture(layout,load(prefix+"-fallback.png"),Rect2(82,74,319,425))
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
	var inset:Vector2=app.safe
	var factor := minf((size.x-inset.x*2)/960.0,(size.y-inset.y*2)/540.0)
	layout.scale = Vector2.ONE * maxf(.01,factor)
	layout.position = (size-layout.size*layout.scale)*.5
	if is_instance_valid(village_back):
		var top_left := inset
		if OS.has_feature("android"):
			var area := DisplayServer.get_display_safe_area()
			var physical := Vector2(DisplayServer.screen_get_size())
			if physical.x>0 and physical.y>0 and area.has_area():
				top_left = (Vector2(area.position)*size/physical).clamp(Vector2.ZERO,size)
		var control_scale := maxf(.65,factor)
		village_back.position = top_left + Vector2(14,12)*control_scale
		village_back.size = Vector2.ONE * 52.0 * control_scale
		village_back_icon.position = Vector2.ONE * 4.0 * control_scale
		village_back_icon.size = Vector2.ONE * 44.0 * control_scale

func write(parent: Control, value: String, rect: Rect2, font_size: int, color: Color) -> void:
	var label: Label = app.label(parent,value,font_size,color)
	label.position = rect.position
	label.size = rect.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

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
	button.size = Vector2(170,52)
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
	skin.bg_color = Color(.14,.16,.17,.83)
	skin.border_color = Color(.67,.71,.74,.44)
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(8)
	row.add_theme_stylebox_override("panel",skin)
	parent.add_child(row)
	row.position = Vector2(0,y)
	row.size = Vector2(391,56)
	app.picture(row,load(ART+icon),Rect2(10,8,40,40))
	write(row,value,Rect2(62,0,220,56),20,Color("cac6bd"))
	write(row,"준비 중",Rect2(283,0,66,56),14,Color("cac6bd"))
	app.picture(row,preload("res://assets/ui/hunt-result/chevron-right.svg"),Rect2(354,18,20,20))

func _process(delta: float) -> void:
	if is_instance_valid(result_video):
		result_video.paused=not app.application_active
		if result_video.is_playing() and result_video.stream_position>.03:result_first.hide()
		return
	if not app.application_active: return
	elapsed = fposmod(elapsed+delta,2.0)
	var frame := int(elapsed*18)
	frame_art.region.position = Vector2((frame%6)*CELL.x,(frame/6)*CELL.y)

func build_field_video(layout:Control)->bool:
	var prefix:=FIELD_ART+"han-"+("success" if won else "failure")
	var stream:=load(prefix+".ogv") as VideoStream
	if stream==null:return false
	result_last=app.picture(layout,load(prefix+"-last.png"),ACTOR_FRAME)
	layout.move_child(result_last,0)
	result_last.hide()
	result_video=VideoStreamPlayer.new()
	result_video.name="ConfirmedResultMotion"
	result_video.stream=stream
	result_video.expand=true
	result_video.position=ACTOR_FRAME.position
	result_video.size=ACTOR_FRAME.size
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
	result_first=app.picture(layout,load(prefix+"-first.png"),ACTOR_FRAME)
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
