extends Control
## Visual slots are separate from the six playable encounters in each saved chapter.
const STAGES_PER_CHAPTER := 6
const HUNT_CHAPTER_ONE := preload("res://scripts/hunt_chapter_one_catalog.gd")
const CHAPTERS := ["초원","숲"]
const TOTAL_STAGES := STAGES_PER_CHAPTER*2
const ART := "res://assets/ui/d0024/"
const STAGE_ART := "res://assets/ui/d0025/"
const DESIGN := Vector2(960,540)
const MEADOW := Vector2(1280,720)
const MEADOW_IDLE := preload("res://assets/ui/hunt-selection/hunt-meadow-idle-loop.ogv")
const CAMP_MASK := """
shader_type canvas_item;
uniform sampler2D minimum_plate : filter_linear;
void fragment() {
	vec2 p=UV*vec2(1280.0,720.0);
	// Enlarge just the flame around its ground contact, not the whole camp.
	vec2 flame=vec2(126.0,375.0)+(p-vec2(126.0,375.0))/1.45;
	vec3 pixel=texture(TEXTURE,flame/vec2(1280.0,720.0)).rgb;
	// The source plume starts above the old tent roof. Re-anchor its base
	// to the fire without moving either the source video or its playback clock.
	float height=clamp((375.0-p.y)/285.0,0.0,1.0);
	vec2 plume=vec2(126.0+(p.x-126.0)/mix(1.0,1.35,height),(p.y-375.0)/1.8+285.0);
	vec3 vapour=texture(TEXTURE,plume/vec2(1280.0,720.0)).rgb;
	vec3 plate=texture(minimum_plate,(plume-vec2(40.0,100.0))/vec2(200.0,300.0)).rgb;
	float area=smoothstep(70.0,90.0,plume.x)*(1.0-smoothstep(215.0,235.0,plume.x))*smoothstep(125.0,145.0,plume.y)*(1.0-smoothstep(275.0,295.0,plume.y));
	float chroma=max(vapour.r,max(vapour.g,vapour.b))-min(vapour.r,min(vapour.g,vapour.b));
	float neutral=1.0-smoothstep(.12,.28,chroma);
	float light=dot(vapour,vec3(.299,.587,.114));
	float base=dot(plate,vec3(.299,.587,.114));
	float change=light-base;
	float smoke=clamp((change-.035)/max(.15,1.0-base)*.8,0.0,.36)*smoothstep(.035,.09,change)*neutral*area;
	smoke*=smoothstep(65.0,145.0,p.y)*(1.0-smoothstep(365.0,395.0,p.y));
	float fire_area=1.0-smoothstep(.65,1.0,length((flame-vec2(126.0,361.0))/vec2(29.0,43.0)));
	float fire=fire_area*smoothstep(.52,.85,pixel.r)*smoothstep(.08,.30,pixel.r-pixel.b)*smoothstep(.22,.52,dot(pixel,vec3(.299,.587,.114)));
	float alpha=max(smoke,fire);
	COLOR=vec4(mix(vec3(.91,.92,.92),pixel,fire/max(.001,fire+smoke)),alpha);
}
"""
const STAGE_ROW_Y := 385.0
const PREPARE_Y := 454.0
const PREPARE_HEIGHT := 50.0
const STAGE_ART_SCALE := 0.56
const BOAR_DISPLAY_SCALE := .86
const TITLE := preload(ART+"08-ui-title-plaque-660.png")
const BOSS := preload(ART+"08-ui-stage-finalboss-crest.png")
const FIELD := preload(ART+"02-meadow-background.png")
const CLEAN_FIELD := preload("res://assets/ui/d0061/meadow-clean.png")
const TENT := preload("res://assets/ui/d0061/tent.png")
# 54 source pixels are about 80 screen pixels at the unfolded review scale.
# All camp parts share this offset; vertical position and tent size stay fixed.
const CAMP_SHIFT := Vector2(-54,0)
const TENT_RECT := Rect2(872,285,137,92)
const CAMP_SOURCE := Vector2(126,375)
const CAMP_TARGET := Vector2(937,374)
const CAMP_SCALE := .52
const BOAR := preload(ART+"03-boar-entrance-atlas.png")
const HOLD := preload(ART+"05-boar-settled-pose.png")
const ENTRY_AUDIO := preload("res://assets/ui/d0027/boar-entry-sync.wav")
const ARROW := preload(ART+"08-ui-arrow-gold-worn-right.svg")
const TOP_ENTRY := 1.99
const FOOTER_ENTRY := 2.29
const ENTRY_END := 2.56
const ENTRY_AUDIO_LEAD := .30
const IDLE_ART := "res://assets/ui/d0031/"
const SKINS := {
	"active":preload(STAGE_ART+"stage-active-body@2x.png"),
	"complete":preload(STAGE_ART+"stage-complete-body@2x.png"),
	"locked":preload(STAGE_ART+"stage-locked-body@2x.png"),
	"midboss":preload(STAGE_ART+"stage-midboss-body@2x.png"),
}
var app: Node
var page: Control
var top_group: Control
var corner_mist: ColorRect
var top_rest_y := 0.0
var footer_rest_y := 0.0
var footer: Control
var backdrop: TextureRect
var camp_idle: VideoStreamPlayer
var camp_still:TextureRect
var tent:TextureRect
var tent_shadow:TextureRect
var static_motion := false
var boar: TextureRect
var shadow: TextureRect
var boar_frame := AtlasTexture.new()
var frames: Array = []
var hold_index := 42
var hold_at := Vector2(204,217)
var frame_index := -1
var chapter := 0
var elapsed := 0.0
var entry_presented := false
var audio_clock_started := false
var audio_clock_active := false
var voice := AudioStreamPlayer.new()
var plaque_art: Texture2D
var skip_hint: Label
var skip_mouse := false
var skip_touch := -1
var entry_finished := false
var idle_elapsed := 0.0
var idle_frames: Array[AtlasTexture] = []
var idle_origin := Vector2(207,228)
var idle_extent := Vector2(281,176)
var idle_fps := 24.0

func _ready() -> void:
	app.warm_hunt_resources()
	mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	chapter=0 if int(app.chapter_one_story_number(int(app.hunt_stage))) > 0 else int(app.hunt_stage)/STAGES_PER_CHAPTER
	plaque_art=IntegratedMenuArt.trimmed(TITLE,Rect2(TITLE.get_image().get_used_rect()))
	backdrop=app.picture(self,CLEAN_FIELD if chapter==0 else FIELD,Rect2())
	backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var gradient := Gradient.new()
	gradient.colors=PackedColorArray([Color(0,0,0,.31),Color(0,0,0,0)])
	var soft := GradientTexture2D.new()
	soft.gradient=gradient
	soft.fill=GradientTexture2D.FILL_RADIAL
	soft.fill_from=Vector2(.5,.5)
	soft.fill_to=Vector2(1,.5)
	tent_shadow=app.picture(self,soft,Rect2())
	tent_shadow.modulate.a=.5
	tent=app.picture(self,TENT,Rect2())
	tent.visible=chapter==0;tent_shadow.visible=chapter==0
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
	voice.stream=ENTRY_AUDIO
	voice.volume_db=linear_to_db(.50*preload("res://scripts/hunt_audio.gd").HUNT_GAIN)
	add_child(voice)
	skip_hint=title(self,"스킵",Rect2(),23)
	skip_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	skip_hint.add_theme_color_override("font_outline_color",Color("432e1c"))
	skip_hint.add_theme_constant_override("outline_size",4)
	static_motion=reduce_motion()
	if static_motion:
		entry_finished=true
		elapsed=ENTRY_END
		set_process(false)
	resized.connect(draw_page)
	draw_page()
	if not static_motion:
		for index in range(1,4):
			ResourceLoader.load_threaded_request(IDLE_ART+"boar-idle-atlas-%02d.png"%index)
	if not entry_finished:
		if DisplayServer.get_name()=="headless":
			entry_presented=true
		else:
			RenderingServer.frame_post_draw.connect(mark_entry_presented,CONNECT_ONE_SHOT)

func mark_entry_presented() -> void:
	entry_presented=true

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
	if is_instance_valid(camp_idle):camp_idle.paused=not app.application_active
	if entry_finished:
		if chapter == 0 and not static_motion and app.application_active and is_visible_in_tree():
			if idle_frames.is_empty() and not load_boar_idle():
				return
			idle_elapsed += delta
			layout_boar()
		return
	if not entry_presented:return
	if not app.application_active:
		voice.stream_paused=true
		return
	voice.stream_paused=false
	if not audio_clock_started:
		audio_clock_started=true
		audio_clock_active = not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX"))
		if audio_clock_active:voice.play()
		return
	if voice.playing:
		var mixed_position := voice.get_playback_position()
		# Start interpolation only after the driver has mixed this stream.
		var audible_position := mixed_position
		if mixed_position>0.0:
			audible_position += AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency()
		elapsed=maxf(elapsed,audible_position-ENTRY_AUDIO_LEAD)
	else:
		if audio_clock_active:
			# The playback cursor resets at EOF while the queued tail still drains.
			audio_clock_active = false
			elapsed = maxf(elapsed,ENTRY_AUDIO.get_length()-AudioServer.get_output_latency()-ENTRY_AUDIO_LEAD)
		elapsed+=delta
	layout_boar()
	update_groups()
	if elapsed>=ENTRY_END:finish_entry()

func finish_entry(skipped := false) -> void:
	if entry_finished:return
	entry_finished=true
	elapsed=ENTRY_END
	if skipped:voice.stop()
	skip_hint.hide()
	layout_boar()
	update_groups()
	sync_camp_idle()

func sync_camp_idle() -> void:
	var allow_idle := chapter==0 and not static_motion and DisplayServer.get_name()!="headless"
	if not allow_idle:
		if is_instance_valid(camp_idle):
			camp_idle.stop()
			camp_idle.hide()
		if chapter==0 and static_motion and not is_instance_valid(camp_still):
			camp_still=app.picture(self,FIELD,Rect2())
			camp_still.material=camp_material()
			move_child(camp_still,tent.get_index()+1)
			fit_camp_idle()
		return
	if not is_instance_valid(camp_idle):
		camp_idle = VideoStreamPlayer.new()
		camp_idle.name = "CampfireAndSmoke"
		camp_idle.stream = MEADOW_IDLE
		camp_idle.expand = true
		camp_idle.loop = true
		camp_idle.volume_db = -80.0
		camp_idle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		camp_idle.material = camp_material()
		add_child(camp_idle)
		move_child(camp_idle,tent.get_index()+1)
	camp_idle.show()
	fit_camp_idle()
	if not camp_idle.is_playing():camp_idle.play()
	camp_idle.paused=not app.application_active
	set_process(true)

func camp_material()->ShaderMaterial:
	var shader:=Shader.new();shader.code=CAMP_MASK
	var material:=ShaderMaterial.new();material.shader=shader
	material.set_shader_parameter("minimum_plate",preload("res://assets/ui/d0061/camp-min.png"))
	return material

func fit_camp_idle() -> void:
	var cover := maxf(size.x/MEADOW.x,size.y/MEADOW.y)
	var offset:=(size-MEADOW*cover)*.5
	for layer in [camp_idle,camp_still]:
		if not is_instance_valid(layer):continue
		layer.size=MEADOW*CAMP_SCALE*cover
		layer.position=offset+(CAMP_TARGET+CAMP_SHIFT-CAMP_SOURCE*CAMP_SCALE)*cover

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
	if entry_finished and chapter == 0 and not idle_frames.is_empty() and not static_motion:
		boar.texture = idle_frames[int(idle_elapsed * idle_fps) % idle_frames.size()]
		boar.position = offset + idle_origin * cover
		boar.size = idle_extent * cover
		frame_index = -1
		return
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

func load_boar_idle() -> bool:
	var paths: Array[String] = []
	for index in range(1,4):
		var path := IDLE_ART+"boar-idle-atlas-%02d.png"%index
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
			return false
		paths.append(path)
	var atlas_pages: Array[Texture2D] = []
	for path in paths:
		atlas_pages.append(ResourceLoader.load_threaded_get(path))
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/d0031-boar-idle.json"))
	if not data is Dictionary:
		return false
	var at: Array = data.source_top_left_xy
	var cell: Array = data.frame_cell_size_px
	idle_origin = Vector2(at[0],at[1])
	idle_extent = Vector2(cell[0],cell[1])
	idle_fps = float(data.fps)
	for entry in data.frames:
		var cut: Array = entry.rect_xywh
		var frame := AtlasTexture.new()
		frame.atlas = atlas_pages[int(entry.atlas)]
		frame.region = Rect2(cut[0],cut[1],cut[2],cut[3])
		frame.filter_clip = true
		idle_frames.append(frame)
	return not idle_frames.is_empty()

func update_groups() -> void:
	move_group(top_group,TOP_ENTRY,-18.0)
	move_group(footer,FOOTER_ENTRY,20.0)

func move_group(group: Control, start: float, shift: float) -> void:
	group.visible=elapsed>=start
	var phase := clampf((elapsed-start)/.30,0,1)
	group.modulate.a=smoothstep(0,.32,phase)
	group.position.y=(top_rest_y if group==top_group else footer_rest_y)+shift*(1.0-Tween.interpolate_value(0.0,1.0,phase,1.0,Tween.TRANS_BACK,Tween.EASE_OUT))
	group.mouse_behavior_recursive=Control.MOUSE_BEHAVIOR_ENABLED if phase>=.32 else Control.MOUSE_BEHAVIOR_DISABLED

func progress() -> int:
	return int(app.model.state.get("hunt_cleared",0))

func layer(parent: Control) -> Control:
	var group := Control.new()
	group.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(group)
	return group

func _layout_corner_mist() -> void:
	if not is_instance_valid(corner_mist):
		corner_mist=ColorRect.new()
		corner_mist.name="SelectorCornerMist"
		corner_mist.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(corner_mist)
		var shader:=Shader.new()
		shader.code="""
shader_type canvas_item;
void fragment(){
	vec2 p=min(UV,vec2(1.)-UV)/vec2(.25,.25);
	float cloud=clamp(1.-length(p),0.,1.);
	float veil=.85+.15*sin(UV.x*31.+UV.y*19.);
	COLOR=vec4(.85,.83,.75,.29*cloud*cloud*veil);
}
"""
		var material:=ShaderMaterial.new()
		material.shader=shader
		corner_mist.material=material
	corner_mist.size=size
	move_child(corner_mist,-1)

func draw_page() -> void:
	if size.x<=0 or size.y<=0:return
	backdrop.texture=CLEAN_FIELD if chapter==0 else FIELD
	tent.visible=chapter==0;tent_shadow.visible=chapter==0
	if is_instance_valid(camp_still):camp_still.visible=chapter==0 and static_motion
	backdrop.size=size
	var cover:=maxf(size.x/MEADOW.x,size.y/MEADOW.y)
	var offset:=(size-MEADOW*cover)*.5
	tent.position=offset+(TENT_RECT.position+CAMP_SHIFT)*cover;tent.size=TENT_RECT.size*cover
	tent_shadow.position=offset+(Vector2(899,365)+CAMP_SHIFT)*cover;tent_shadow.size=Vector2(86,18)*cover
	fit_camp_idle()
	sync_camp_idle()
	layout_boar()
	if is_instance_valid(page):
		remove_child(page)
		page.queue_free()
	_layout_corner_mist()
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
	# Match the existing preparation title plank and visible gold button artwork.
	# The preparatory scene retains its original layout, including its edge wash.
	var safe_start:=Vector2.ZERO
	var safe_end:=size
	if OS.has_feature("android"):
		var area:=DisplayServer.get_display_safe_area()
		var physical:=Vector2(DisplayServer.screen_get_size())
		if physical.x>0. and physical.y>0. and area.has_area():
			safe_start=(Vector2(area.position)*size/physical).clamp(Vector2.ZERO,size)
			safe_end=(Vector2(area.end)*size/physical).clamp(safe_start,size)
	var safe_size:=safe_end-safe_start
	var prep_fit:=maxf(.1,minf(safe_size.x/DESIGN.x,safe_size.y/DESIGN.y))
	var prep_bar_top:=safe_start.y+10.*prep_fit
	var prep_art_end:=safe_end.y-(540.+7.-472.-65.*(.18+.64))*prep_fit
	top_rest_y=(prep_bar_top-page.position.y)/unit-12.
	footer_rest_y=(prep_art_end-page.position.y)/unit-PREPARE_Y-PREPARE_HEIGHT
	var crest := Rect2(315,12,330,65)
	var title_plate:TextureRect=app.picture(top_group,plaque_art,crest)
	title_plate.name="SelectorTitlePlate"
	title_plate.stretch_mode=TextureRect.STRETCH_SCALE
	var chapter_name := "%d장 · %s"%[chapter+1,CHAPTERS[chapter]]
	var heading := title(top_group,chapter_name,Rect2(315,37.5,330,27),22)
	var half_text := heading.get_theme_font("font").get_string_size(chapter_name,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x*.5
	if chapter>0:chapter_arrow(480-half_text-20-12,-1)
	if chapter+1<CHAPTERS.size():chapter_arrow(480+half_text+20+12,1)
	var back := action(top_group,Rect2(13,10,48,48),exit_selection)
	app.picture(back,preload(ART+"08-ui-back-button.png"),Rect2(5,5,38,38))
	var rules := action(top_group,Rect2(854,20,84,33),open_rules)
	app.picture(rules,preload(ART+"08-ui-rules-body.svg"),Rect2(Vector2.ZERO,rules.size))
	var rule_label := title(rules,"규칙",Rect2(0,0,0,33),15)
	var label_width := rule_label.get_theme_font("font").get_string_size("규칙",HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
	var group_x := (rules.size.x-15.0-7.0-label_width)*.5
	app.picture(rules,preload(ART+"08-ui-rules-book.svg"),Rect2(group_x,8.5,15,16))
	rule_label.position.x = group_x+22.0
	rule_label.size.x = label_width
	app.picture(footer,preload(STAGE_ART+"stage-connector@2x.png"),Rect2(132,STAGE_ROW_Y-3,702,6)).stretch_mode=TextureRect.STRETCH_SCALE
	for slot in 10:
		add_stage(slot)
	var prepare := action(footer,Rect2(625,PREPARE_Y,238,PREPARE_HEIGHT),app.prepare_selected_hunt)
	prepare.name="PrepareHunt"
	app.picture(prepare,preload(ART+"08-ui-prepare-gold-body.svg"),Rect2(Vector2.ZERO,prepare.size))
	title(prepare,"사냥 준비",Rect2(Vector2.ZERO,prepare.size),24,Color("462b14"))
	prepare.disabled=(0 if int(app.chapter_one_story_number(int(app.hunt_stage))) > 0 else int(app.hunt_stage)/STAGES_PER_CHAPTER)!=chapter or not app.hunt_stage_is_unlocked(int(app.hunt_stage))
	prepare.modulate.a=.62 if prepare.disabled else 1.0
	update_groups()

func chapter_arrow(x: float, direction: int) -> void:
	var arrow := action(top_group,Rect2(x-21,29.5,42,42),change_chapter.bind(direction))
	var picture: TextureRect=app.picture(arrow,ARROW,Rect2(9,9,24,24))
	picture.flip_h=direction<0

# Saved IDs are dense; displayed stages temporarily have unimplemented slots.
static func are_adjacent_playable_slots(current: int, next: int) -> bool:
	var chapter_size := STAGES_PER_CHAPTER
	var current_slot := current % chapter_size
	var next_slot := next % chapter_size
	var current_display := 9 if current_slot == chapter_size - 1 else current_slot
	var next_display := 9 if next_slot == chapter_size - 1 else next_slot
	return next == current + 1 and (next_display == current_display + 1 or (current_display == 9 and next_display == 0))


func add_stage(slot: int) -> void:
	var boss := slot==9
	var midboss := slot==4
	var story := chapter == 0 and bool(app.chapter_one_preview_enabled())
	var real := story or slot<5 or boss
	var stage_id := HUNT_CHAPTER_ONE.route_id(slot+1) if story else chapter*STAGES_PER_CHAPTER+(STAGES_PER_CHAPTER-1 if boss else slot)
	var unlocked := real and bool(app.hunt_stage_is_unlocked(stage_id))
	var completed: Dictionary = app.chapter_one_story_completions() if story else {}
	var done: bool = completed.get(HUNT_CHAPTER_ONE.STAGE_KEYS[slot], false) == true if story else real and stage_id<progress()
	var selected: bool=real and stage_id==app.hunt_stage
	var current := HUNT_CHAPTER_ONE.next_number(completed)==slot+1 if story else real and stage_id==progress()
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
	if selected and not has_caption:
		title(tile,str(slot+1),Rect2(Vector2.ZERO,extent),44)
	else:
		var number_center_y := (22.0 if boss else 15.0)*1.2
		title(tile,str(slot+1),Rect2(0,number_center_y-14.0,diameter,28),24 if (selected or current) else 21)
	if has_caption:
		title(tile,"최종 보스" if boss else "중간 보스",Rect2(0,diameter*.46*.95,diameter,14),10)
	if done or not unlocked:
		var marker: Texture2D=preload(ART+"08-ui-stage-check.svg") if done else preload(ART+"08-ui-padlock-gold.png")
		var marker_y := diameter*.68 if has_caption else diameter*.60
		var marker_size := 9.0 if selected and not has_caption else 13.0
		if selected and not has_caption:
			marker_y = diameter-marker_size-2.0
		app.picture(tile,marker,Rect2((diameter-marker_size)*.5,marker_y,marker_size,marker_size))

func choose(stage_id: int) -> void:
	if not app.hunt_stage_is_unlocked(stage_id):return
	app.hunt_stage=stage_id
	app.warm_hunt_resources()
	draw_page()

func change_chapter(direction: int) -> void:
	chapter=clampi(chapter+direction,0,CHAPTERS.size()-1)
	draw_page()
	sync_camp_idle()

func exit_selection() -> void:
	app.show_screen("play")

func open_rules() -> void:
	if app.modal:return
	var scroll: ScrollContainer = app.show_modal("사냥 규칙","",[],false,true,false,Vector2(735,429))
	var separator := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color(.58,.33,.15,.18)
	separator.add_theme_stylebox_override("separator",line)
	scroll.get_parent().add_child(separator)
	scroll.get_parent().move_child(separator,scroll.get_index())
	var rules := VBoxContainer.new()
	rules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules.add_theme_constant_override("separation",13)
	scroll.add_child(rules)
	var statements := [
		"[color=#733d18][b]스테이지[/b][/color]를 선택한 뒤 [color=#733d18][b]사냥 준비[/b][/color]를 누르세요.",
		"완료한 사냥터는 [color=#733d18][b]다시 도전[/b][/color]할 수 있습니다.",
		"현재 장의 [color=#a32918][b]일반 사냥터 다섯 곳[/b][/color]을 완료하면 [color=#a32918][b]최종 보스[/b][/color]가 열립니다."
	]
	for i in statements.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		rules.add_child(row)
		var badge := PanelContainer.new()
		badge.custom_minimum_size = Vector2(31,25)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color=Color(.71,.47,.20,.17)
		badge_style.border_color=Color(.71,.47,.20,.35)
		badge_style.set_border_width_all(1)
		badge_style.set_corner_radius_all(4)
		badge.add_theme_stylebox_override("panel",badge_style)
		row.add_child(badge)
		var number := Label.new()
		number.text="%02d"%(i+1)
		number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		number.add_theme_font_override("font",FigmaArt.BODY)
		number.add_theme_font_size_override("font_size",15)
		number.add_theme_color_override("font_color",Color("683b19"))
		badge.add_child(number)
		var sentence := RichTextLabel.new()
		sentence.bbcode_enabled = true
		sentence.fit_content = true
		sentence.scroll_active = false
		sentence.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sentence.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sentence.add_theme_font_override("normal_font",FigmaArt.BODY)
		sentence.add_theme_font_override("bold_font",FigmaArt.TITLE)
		sentence.add_theme_font_size_override("normal_font_size",20)
		sentence.add_theme_font_size_override("bold_font_size",20)
		sentence.add_theme_color_override("default_color",Color("472916"))
		sentence.text = statements[i]
		row.add_child(sentence)

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
