extends Control
## Visual slots are separate from the six playable encounters in each saved chapter.
const STAGES_PER_CHAPTER := 6
const CHAPTERS := ["초원","숲"]
const TOTAL_STAGES := STAGES_PER_CHAPTER*2
const ART := "res://assets/ui/d0024/"
const STAGE_ART := "res://assets/ui/d0025/"
const DESIGN := Vector2(960,540)
const MEADOW := Vector2(1280,720)
const STAGE_ROW_Y := 385.0
const STAGE_ART_SCALE := 0.56
const BOAR_DISPLAY_SCALE := .86
const TITLE := preload(ART+"08-ui-title-plaque-660.png")
const BOSS := preload(ART+"08-ui-stage-finalboss-crest.png")
const FIELD := preload(ART+"02-meadow-background.png")
const BOAR := preload(ART+"03-boar-entrance-atlas.png")
const HOLD := preload(ART+"05-boar-settled-pose.png")
const SWIPE := preload(ART+"07-sfx-parchment-swipe.wav")
const HOOF := preload(ART+"06-sfx-boar-hoof.wav")
const ARROW := preload(ART+"08-ui-arrow-gold-worn-right.svg")
const ENTRY_TIMES := [.42,.88,1.46,1.96,2.26]
const ENTRY_END := 2.56
const SKINS := {
	"active":preload(STAGE_ART+"stage-active-body@2x.png"),
	"complete":preload(STAGE_ART+"stage-complete-body@2x.png"),
	"locked":preload(STAGE_ART+"stage-locked-body@2x.png"),
	"midboss":preload(STAGE_ART+"stage-midboss-body@2x.png"),
}
var app: Node
var page: Control
var top_group: Control
var footer: Control
var backdrop: TextureRect
var boar: TextureRect
var shadow: TextureRect
var boar_frame := AtlasTexture.new()
var frames: Array = []
var hold_index := 42
var hold_at := Vector2(204,217)
var frame_index := -1
var chapter := 0
var elapsed := 0.0
var next_event := 0
var voice := AudioStreamPlayer.new()
var plaque_art: Texture2D
var skip_hint: Label
var skip_mouse := false
var skip_touch := -1
var entry_finished := false

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	chapter=int(app.hunt_stage)/STAGES_PER_CHAPTER
	plaque_art=IntegratedMenuArt.trimmed(TITLE,Rect2(TITLE.get_image().get_used_rect()))
	backdrop=app.picture(self,FIELD,Rect2())
	backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var gradient := Gradient.new()
	gradient.colors=PackedColorArray([Color(0,0,0,.31),Color(0,0,0,0)])
	var soft := GradientTexture2D.new()
	soft.gradient=gradient
	soft.fill=GradientTexture2D.FILL_RADIAL
	soft.fill_from=Vector2(.5,.5)
	soft.fill_to=Vector2(1,.5)
	shadow=app.picture(self,soft,Rect2())
	shadow.stretch_mode=TextureRect.STRETCH_SCALE
	boar=app.picture(self,null,Rect2())
	boar.stretch_mode=TextureRect.STRETCH_SCALE
	boar_frame.atlas=BOAR
	boar_frame.filter_clip=true
	var metadata: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/d0024-boar-entrance.json"))
	if metadata is Dictionary:
		frames=metadata.get("frames",[])
		hold_index=int(metadata.get("hold_frame",42))
		var origin: Array=metadata.get("hold_pose_source_top_left_xy",[204,217])
		hold_at=Vector2(origin[0],origin[1])
	voice.bus=&"SFX"
	voice.volume_db=linear_to_db(.50)
	add_child(voice)
	skip_hint=title(self,"스킵",Rect2(),23)
	skip_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	skip_hint.add_theme_color_override("font_outline_color",Color("432e1c"))
	skip_hint.add_theme_constant_override("outline_size",4)
	if reduce_motion():
		entry_finished=true
		elapsed=ENTRY_END
		next_event=ENTRY_TIMES.size()
		set_process(false)
	resized.connect(draw_page)
	draw_page()

func reduce_motion() -> bool:
	if OS.get_cmdline_user_args().has("--reduce-motion") or app.settings.get_value("app","reduce_motion",false):
		return true
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime"):return false
	var wrapper := Engine.get_singleton("JavaClassWrapper")
	if wrapper==null:return false
	var settings_class: Variant=wrapper.wrap("android.provider.Settings$Global")
	var activity: Variant=Engine.get_singleton("AndroidRuntime").getActivity()
	return settings_class!=null and activity!=null and float(settings_class.getFloat(activity.getContentResolver(),"animator_duration_scale",1.0))<=0.0

func _process(delta: float) -> void:
	if not app.application_active:
		voice.stream_paused=true
		return
	voice.stream_paused=false
	elapsed+=delta
	while next_event<ENTRY_TIMES.size() and elapsed>=ENTRY_TIMES[next_event]:
		voice.stream=HOOF if next_event<3 else SWIPE
		if not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")):
			voice.play()
		next_event+=1
	layout_boar()
	update_groups()
	if elapsed>=ENTRY_END:finish_entry()

func finish_entry(skipped := false) -> void:
	if entry_finished:return
	entry_finished=true
	elapsed=ENTRY_END
	next_event=ENTRY_TIMES.size()
	if skipped:voice.stop()
	skip_hint.hide()
	layout_boar()
	update_groups()
	set_process(false)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not app.application_active:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed and not entry_finished and get_global_rect().has_point(event.position):
			skip_mouse=true
			finish_entry(true)
			get_viewport().set_input_as_handled()
		elif not event.pressed and skip_mouse:
			skip_mouse=false
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed and not entry_finished and get_global_rect().has_point(event.position):
			skip_touch=event.index
			finish_entry(true)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index==skip_touch:
			skip_touch=-1
			get_viewport().set_input_as_handled()

func layout_boar() -> void:
	var cover := maxf(size.x/MEADOW.x,size.y/MEADOW.y)
	var offset := (size-MEADOW*cover)*.5
	var index := mini(hold_index,int(elapsed*24.0))
	var origin := hold_at
	var extent := HOLD.get_size()
	if not frames.is_empty():
		var data: Dictionary=frames[clampi(index,0,frames.size()-1)]
		var cut: Array=data.atlas_rect_xywh
		var at: Array=data.source_top_left_xy
		origin=Vector2(at[0],at[1])
		extent=Vector2(cut[2],cut[3])
		if index!=frame_index:
			boar_frame.region=Rect2(cut[0],cut[1],cut[2],cut[3])
			boar.texture=boar_frame
	else:
		boar.texture=HOLD
	frame_index=index
	var display_extent := extent*BOAR_DISPLAY_SCALE
	var display_origin := origin+Vector2((extent.x-display_extent.x)*.5,extent.y-display_extent.y-13)
	boar.position=offset+display_origin*cover
	boar.size=display_extent*cover
	shadow.position=offset+(display_origin+Vector2(display_extent.x*.08,display_extent.y-15))*cover
	shadow.size=Vector2(display_extent.x*.87,30)*cover

func update_groups() -> void:
	move_group(top_group,1.96,-18.0)
	move_group(footer,2.26,20.0)

func move_group(group: Control, start: float, shift: float) -> void:
	group.visible=elapsed>=start
	var phase := clampf((elapsed-start)/.30,0,1)
	group.modulate.a=smoothstep(0,.32,phase)
	group.position.y=shift*(1.0-Tween.interpolate_value(0.0,1.0,phase,1.0,Tween.TRANS_BACK,Tween.EASE_OUT))
	group.mouse_behavior_recursive=Control.MOUSE_BEHAVIOR_ENABLED if phase>=.32 else Control.MOUSE_BEHAVIOR_DISABLED

func progress() -> int:
	return int(app.model.state.get("hunt_cleared",0))

func layer(parent: Control) -> Control:
	var group := Control.new()
	group.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(group)
	return group

func draw_page() -> void:
	if size.x<=0 or size.y<=0:return
	backdrop.size=size
	layout_boar()
	if is_instance_valid(page):
		remove_child(page)
		page.queue_free()
	page=layer(self)
	var unit := minf(1.0,minf(size.x/DESIGN.x,size.y/DESIGN.y))
	skip_hint.visible=not entry_finished
	skip_hint.position=Vector2(size.x-maxf(20.0,app.safe.x)-104*unit,size.y-maxf(20.0,app.safe.y)-42*unit)
	skip_hint.size=Vector2(104,42)*unit
	skip_hint.add_theme_font_size_override("font_size",roundi(23*unit))
	move_child(skip_hint,-1)
	page.scale=Vector2.ONE*unit
	page.position=(size-DESIGN*unit)*.5
	top_group=layer(page)
	footer=layer(page)
	var crest := Rect2(315,12,330,65)
	app.picture(top_group,plaque_art,crest).stretch_mode=TextureRect.STRETCH_SCALE
	var chapter_name := "%d장 · %s"%[chapter+1,CHAPTERS[chapter]]
	var heading := title(top_group,chapter_name,Rect2(315,35.5,330,27),22)
	var half_text := heading.get_theme_font("font").get_string_size(chapter_name,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x*.5
	if chapter>0:chapter_arrow(480-half_text-20-12,-1)
	if chapter+1<CHAPTERS.size():chapter_arrow(480+half_text+20+12,1)
	var back := action(top_group,Rect2(13,10,48,48),exit_selection)
	app.picture(back,preload(ART+"08-ui-back-button.png"),Rect2(5,5,38,38))
	var rules := action(top_group,Rect2(854,20,84,33),open_rules)
	app.picture(rules,preload(ART+"08-ui-rules-body.svg"),Rect2(Vector2.ZERO,rules.size))
	app.picture(rules,preload(ART+"08-ui-rules-book.svg"),Rect2(9,8,15,16))
	title(rules,"규칙",Rect2(27,0,49,32),15)
	app.picture(footer,preload(STAGE_ART+"stage-connector@2x.png"),Rect2(132,STAGE_ROW_Y-3,702,6)).stretch_mode=TextureRect.STRETCH_SCALE
	for slot in 10:
		add_stage(slot)
	var prepare := action(footer,Rect2(625,456,238,50),app.prepare_selected_hunt)
	app.picture(prepare,preload(ART+"08-ui-prepare-gold-body.svg"),Rect2(Vector2.ZERO,prepare.size))
	title(prepare,"사냥 준비",Rect2(Vector2.ZERO,prepare.size),24,Color("462b14"))
	prepare.disabled=int(app.hunt_stage)/STAGES_PER_CHAPTER!=chapter or app.hunt_stage>progress()
	prepare.modulate.a=.62 if prepare.disabled else 1.0
	update_groups()

func chapter_arrow(x: float, direction: int) -> void:
	var arrow := action(top_group,Rect2(x-21,29.5,42,42),change_chapter.bind(direction))
	var picture: TextureRect=app.picture(arrow,ARROW,Rect2(9,9,24,24))
	picture.flip_h=direction<0

func add_stage(slot: int) -> void:
	var boss := slot==9
	var midboss := slot==4
	var real := slot<5 or boss
	var stage_id := chapter*STAGES_PER_CHAPTER+(STAGES_PER_CHAPTER-1 if boss else slot)
	var unlocked := real and stage_id<=progress()
	var done := real and stage_id<progress()
	var selected: bool=real and stage_id==app.hunt_stage
	var current := real and stage_id==progress()
	var center := Vector2(132+78*slot,STAGE_ROW_Y)
	var diameter := 78.0 if boss else (116.0 if midboss else 96.0)*STAGE_ART_SCALE
	var extent := Vector2.ONE*diameter
	var rect := Rect2(center-extent*.5,extent)
	var tile := action(footer,rect,choose.bind(stage_id) if real else Callable())
	tile.name="HuntStage%d"%stage_id if real else "UnavailableSlot%d"%(slot+1)
	tile.disabled=not unlocked
	tile.hint_text="준비 중인 스테이지" if not real else "앞 사냥터를 완료하면 열립니다."
	if boss:
		# Anchor the red plate at the row center, leaving the boar above it.
		var plate_center := Vector2(94,120)
		var art_scale := diameter/116.0
		app.picture(tile,BOSS,Rect2(extent*.5-plate_center*art_scale,BOSS.get_size()*art_scale))
	else:
		var skin: Texture2D = SKINS.midboss if midboss else SKINS.complete if done and not selected else SKINS.active if (selected or current) else SKINS.locked
		var shadow_offset := Vector2(5,1)*STAGE_ART_SCALE
		app.picture(tile,skin,Rect2(-shadow_offset,skin.get_size()*.5*STAGE_ART_SCALE))
	var has_caption := boss or midboss
	var number_y := 10.0 if boss else 3.0
	title(tile,str(slot+1),Rect2(0,number_y,diameter,24),22 if (selected or current) else 18)
	if has_caption:
		title(tile,"최종 보스" if boss else "중간 보스",Rect2(0,diameter*.46,diameter,14),10)
	if done or not unlocked:
		var marker: Texture2D=preload(ART+"08-ui-stage-check.svg") if done else preload(ART+"08-ui-padlock-gold.png")
		var marker_y := diameter*.68 if has_caption else diameter*.60
		app.picture(tile,marker,Rect2((diameter-13)*.5,marker_y,13,13))

func choose(stage_id: int) -> void:
	if stage_id<0 or stage_id>=TOTAL_STAGES or stage_id>progress():return
	app.hunt_stage=stage_id
	draw_page()

func change_chapter(direction: int) -> void:
	chapter=clampi(chapter+direction,0,CHAPTERS.size()-1)
	draw_page()

func exit_selection() -> void:
	app.show_screen("play")

func open_rules() -> void:
	if app.modal:return
	app.show_modal("사냥 규칙","스테이지를 선택한 뒤 사냥 준비를 누르세요.\n완료한 사냥터는 다시 도전할 수 있습니다.\n현재 장의 일반 사냥터 다섯 곳을 완료하면 최종 보스가 열립니다.",[{"text":"닫기","action":app.close_modal}],false,true,false,Vector2(490,330))

func title(parent: Control, value: String, rect: Rect2, font_size: int, color := Color("fff1cd")) -> Label:
	return FigmaArt.text(parent,value,rect,font_size,FigmaArt.BODY,color)

func action(parent: Control, rect: Rect2, callback: Callable) -> DemoButton:
	var button: DemoButton=app.button(parent,"",callback if callback.is_valid() else func():pass)
	button.custom_minimum_size=Vector2.ZERO
	button.position=rect.position
	button.size=rect.size
	for state in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	return button
