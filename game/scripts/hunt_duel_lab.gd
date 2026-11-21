extends Control
signal exited

const SkillHUD = preload("res://scripts/duel_skill_hud.gd")
const Rules = preload("res://scripts/hunt_duel_rules.gd")
const Actor = preload("res://scripts/model_test_actor.gd")
const ModelTest = preload("res://scripts/model_test.gd")
const Profile = preload("res://scripts/model_motion_profile.gd")
const Hunt = preload("res://scripts/deer_hunt_screen.gd")
const HuntArt = preload("res://scripts/hunt_match_art.gd")
const Presentation = preload("res://scripts/duel_motion_presenter.gd")
const SharedWorld = preload("res://scripts/duel_shared_world.gd")
const HeadHUD = preload("res://scripts/battle_head_hud.gd")
const Accent = preload("res://scripts/battle_presentation_accent.gd")
const Ground = preload("res://assets/ui/hunting-formation/clearing-dirt.png")
const UIFont = preload("res://assets/fonts/NotoSansKR.ttf")
const SceneSize := Vector2(960,540)
const Left := Hunt.HUNTER_BATTLE_CENTER+(Hunt.ALLY_CELLS[0]-Hunt.FORMATION_CENTER)*.62
const Right := Hunt.DEER_SLOT
# Preserve latest model proportions; these projection scales match the measured
# settled 1-1 Han/deer heights (63.885 / 67.540 logical pixels at 960x540).
const HANGYEOL_BATTLE_SCALE := .76588
const FOREST_BATTLE_SCALE := .82588
# Local experiment: only this default lab matchup opts into grouped movement.
const APPROACH_TRAVEL := .88
const APPROACH_END := 1.04
const REVIVAL_ENTRANCE_SCALE := 1.30
const SHARED_REVIVAL_DELAY := 1.38
const HAN_SKILL_WINDUP_RATE := 3.25
const HAN_SKILL_WINDUP_LIMIT := .73
var entrance_scale := 1.0
const START_GAP := 218.0
const ENGAGE_GAP := 66.0
const FIRST_BASIC := [.23,.38]
const BASIC_CADENCE := [3.05,3.43]
const BASIC_MAX_TRAVEL := 16.0
const SP_COST := {"skill":2,"chain":3}
const SoundPath := "res://assets/audio/hunt-duel-lab/"
const SoundNames := {"hangyeol":"han", "uram":"uram", "saebom":"bom", "forest":"deer", "adult":"boar"}

var app: Node
var rules := Rules.new()
var arena := Control.new()
var field := Control.new()
var ground: TextureRect
# Reuse the campaign battle camera implementation, without adding its scene or rules to the tree.
var battle_camera := Hunt.new()
var paused := false
var pause_button: Button
var pause_icon: TextureRect
var pause_caption: Label
var name_labels: Array[Label] = []
var selection_frames: Dictionary = {}
var cast_from := Left
var presentation := Presentation.new()
var effects_layer := Node2D.new()
var ready_light_layer := Node2D.new()
var cast_notice_layer:=Node2D.new()
var cast_notice_frames:Array[StyleBoxFlat]=[]
var cast_notice_anchor:=Vector2.ZERO
var cast_notice:Dictionary={}
var location_layer := Node2D.new()
var ring_halo:GradientTexture2D
var ring_band:GradientTexture2D
var ground_wave_phase:=0.0
const GROUND_WAVE_SECONDS:=2.4
var ground_wave_span:=2.0
var hp_reveal_at := -1.0
var deer_wake:Array[Dictionary]=[]
var a: Actor
var b: Actor
var motion: Array[String] = ["idle","idle"]
var age := [0.0,0.0]
var contact_at := [-1.0,-1.0]
var motion_contact := [-1.0,-1.0]
var frame_contact := [-1.0,-1.0]
var start_cast_at := -1.0
var execute_at := -1.0
var next_attack := [0.4,1.6]
var animal_attack_count := 0
var visual_clock := 0.0
var fx: Array[Dictionary] = []
var controls: Dictionary = {}
var timer: Label
var bars: Array[TextureProgressBar] = []
var skill_hud: SkillHUD
var skill_button: Button
var chain_button: Button
var audio_pool: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var cues: Array[String] = []
var pool_index := 0
var closing := false
var approach_active := false
var shared_world:SharedWorld
var overhead:Array=[]
var deer_hud_anchor:=Vector2.INF
var accent:=Accent.new()
var camera_base_scale:=Vector2.ONE
var camera_base_position:=Vector2.ZERO
var chain_impact_frames:Array[Texture2D]=[]
var contact_glow:GradientTexture2D
var tip_trail:Array[Vector2]=[]

func _prototype_duel()->bool:
	return rules.ally_id=="hangyeol" and rules.enemy_id=="forest"

func _duel_anchor(side:int,gap:float)->Vector2:
	return (Left+Right)*.5+Left.direction_to(Right)*gap*.5*(-1.0 if side==0 else 1.0)

func _settled_anchor(side:int)->Vector2:
	if _prototype_duel():
		return _duel_anchor(side,ENGAGE_GAP)
	return Left if side==0 else Right
var touch_pointer := -1
var touch_target: Button
var touch_buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Theme.new()
	var bold:=FontVariation.new();bold.base_font=UIFont
	bold.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):700.0}
	theme.default_font = bold
	var backdrop := ColorRect.new()
	backdrop.color = Color("#1d1712")
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(arena)
	arena.size = SceneSize
	arena.clip_contents = false
	arena.mouse_filter=MOUSE_FILTER_IGNORE
	field.mouse_filter=MOUSE_FILTER_IGNORE
	arena.add_child(field)
	ground=HuntArt.picture(self,Hunt.CLEARING,Rect2())
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	move_child(ground,1)
	battle_camera.canvas=arena;battle_camera.battlefield=field;battle_camera.ground=ground
	battle_camera.arrival_finished=true;battle_camera.approach=1.0
	field.add_child(location_layer)
	var ring_material:=CanvasItemMaterial.new()
	ring_material.blend_mode=CanvasItemMaterial.BLEND_MODE_MIX
	location_layer.material=ring_material
	ring_halo=_new_ring_light(PackedFloat32Array([0,.28,.46,.61,.76,.91,1]),PackedFloat32Array([.10,.12,.15,.27,.18,.035,0]))
	ring_band=_new_ring_light(PackedFloat32Array([0,.53,.60,.65,.68,.72,.79,1]),PackedFloat32Array([0,0,.035,.22,.91,.30,.035,0]))
	location_layer.draw.connect(_draw_location_rings)
	field.add_child(effects_layer)
	effects_layer.z_index = 10
	effects_layer.draw.connect(_draw_effects)
	field.add_child(ready_light_layer)
	ready_light_layer.z_index=9
	var glow_material:=CanvasItemMaterial.new()
	glow_material.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	ready_light_layer.material=glow_material
	ready_light_layer.draw.connect(_draw_duel_lights)
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.volume_db = -9.0
		add_child(player)
		audio_pool.append(player)
	arena.add_child(cast_notice_layer)
	cast_notice_layer.z_index=31
	for tint in [Color("ffd179"),Color("87ddff")]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("101d2c",.93)
		style.border_color=tint
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		cast_notice_frames.append(style)
	cast_notice_layer.draw.connect(func():_draw_cast_notice(cast_notice_anchor))

	_setup_ui()
	for i in 21:chain_impact_frames.append(load("res://assets/effects/d0071-chain/han_chain_impact_%02d.png"%i))
	resized.connect(_fit)
	_fit()
	reset_round()

func _fit() -> void:
	var safe_start:=Vector2.ZERO
	var safe_end:=size
	if OS.has_feature("android"):
		var area:=DisplayServer.get_display_safe_area()
		var physical:=Vector2(DisplayServer.screen_get_size())
		if physical.x>0 and physical.y>0 and area.has_area():
			safe_start=(Vector2(area.position)*size/physical).clamp(Vector2.ZERO,size)
			safe_end=(Vector2(area.end)*size/physical).clamp(safe_start,size)
	var safe_size:=safe_end-safe_start
	var fit := minf(safe_size.x/SceneSize.x,safe_size.y/SceneSize.y)
	arena.scale = Vector2.ONE * fit
	arena.position = safe_start+(safe_size - SceneSize*fit)*.5
	battle_camera.size=size
	# Refit the painted ground without snapping the current combat camera ease.
	battle_camera.update_camera(.000000000001)

func _label(value: String, rect: Rect2, font_size: int) -> Label:
	var item := Label.new()
	item.position = rect.position
	item.size = rect.size
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.text = value
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color",Color("fff2d6"))
	item.add_theme_color_override("font_shadow_color",Color(0,0,0,.5))
	item.add_theme_constant_override("outline_size",0)
	item.add_theme_constant_override("shadow_offset_y", 1)
	arena.add_child(item)
	return item

func _button(value: String, rect: Rect2, pressed: Callable) -> Button:
	var item := Button.new()
	item.text = value
	item.position = rect.position
	item.size = rect.size
	item.pressed.connect(pressed)
	item.focus_mode=Control.FOCUS_NONE
	var texture=preload("res://assets/ui/duel-hud/control-round-gold.svg")
	if value in ["×","↻",""]:
		for state in ["normal","hover","pressed","focus","disabled"]:
			var style:=StyleBoxTexture.new();style.texture=texture
			item.add_theme_stylebox_override(state,style)
	arena.add_child(item)
	touch_buttons.append(item)
	return item

func _plaque(rect:Rect2)->Panel:
	var panel:=Panel.new();panel.position=rect.position;panel.size=rect.size;panel.mouse_filter=MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new();style.bg_color=Color(.12,.086,.055,.76);style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel",style);arena.add_child(panel);return panel

func _button_art(button:Button,texture:Texture2D,span:float)->TextureRect:
	return HuntArt.picture(button,texture,Rect2((button.size-Vector2.ONE*span)*.5,Vector2.ONE*span))

func _setup_ui() -> void:
	# Local backplates only; no full-width title/header covers the battlefield.
	_plaque(Rect2(68,10,304,52))
	_plaque(Rect2(774,17,66,30))
	timer=_label("00:00",Rect2(774,17,66,30),13)
	timer.add_theme_color_override("font_color",Color("fff2d6"))
	var exit_button:=_button("",Rect2(16,16,36,36),_exit)
	exit_button.name="DuelClose"
	exit_button.tooltip_text="닫기"
	_button_art(exit_button,preload("res://assets/ui/duel-hud/close-ivory.svg"),20)
	var reset:=_button("",Rect2(900,16,36,36),reset_round)
	reset.name="DuelReset";reset.tooltip_text="같은 조합으로 다시 시작"
	_button_art(reset,preload("res://assets/ui/duel-hud/restart-ivory.svg"),20)
	pause_button=_button("",Rect2(850,16,36,36),toggle_pause)
	pause_button.name="DuelPause"
	pause_icon=_button_art(pause_button,preload("res://assets/ui/duel-hud/pause-ivory.svg"),20)
	pause_caption=_label("▶",Rect2(0,0,36,36),18);pause_caption.reparent(pause_button,false)
	pause_caption.add_theme_color_override("font_color",Color("fff2d6"))
	var ids := ["hangyeol","uram","saebom","forest","adult"]
	for i in ids.size():
		var key:String=ids[i]
		var item:=_button("",Rect2(78+54*i+(14 if i>=3 else 0),14,44,44),_select.bind(key,i>=3))
		item.name="Select_"+key;item.toggle_mode=true
		item.tooltip_text=["한결","우람","새봄","꽃사슴","큰 멧돼지"][i]
		var icon=ModelTest.portrait(key) if i<3 else preload("res://assets/ui/duel-hud/deer-selector.png") if i==3 else preload("res://assets/ui/duel-hud/boar-selector.png")
		var picture:=_button_art(item,icon,33)
		var material:=ShaderMaterial.new();material.shader=preload("res://shaders/duel_selector_crop.gdshader");picture.material=material
		selection_frames[key]=HuntArt.picture(item,preload("res://assets/ui/duel-hud/selection-gold.svg"),Rect2(0,0,44,44))
		controls[key]=item
	for i in 2:
		var header:=HeadHUD.create_compact(arena,i==0);overhead.append(header);name_labels.append(header.label);bars.append(header.bar)
	skill_hud=SkillHUD.new();skill_hud.position=Vector2(447,437);arena.add_child(skill_hud);skill_hud.enable_duel_ready_feedback()
	skill_hud.requested.connect(_try_player);skill_button=skill_hud.portrait_button;chain_button=skill_hud.chain_button
	touch_buttons.append(chain_button);touch_buttons.append(skill_button)

func toggle_pause()->void:
	paused=not paused
	touch_pointer=-1;touch_target=null
	for player in audio_pool:player.stream_paused=paused
	_refresh()

func _exit_tree() -> void:
	# Unparented camera driver never runs campaign processing.
	battle_camera.hunt_audio.free()
	battle_camera.free()
	for player in audio_pool:
		player.stop()
		player.stream = null
	sounds.clear()

func _exit() -> void:
	if closing:
		return
	closing = true
	set_process(false)
	if app==null:
		get_tree().quit()
	else:
		exited.emit()

func _input(event: InputEvent) -> void:
	# Consume touch once before mouse emulation: a linked-icon release must
	# never be replayed as a portrait tap after SP/UI changes.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_pointer<0:
			for target in touch_buttons:
				var inside:=target.get_global_rect().has_point(event.position)
				if target==skill_button and skill_hud.badge.visible:
					inside=inside or skill_hud.badge.get_global_rect().has_point(event.position)
				if target.is_visible_in_tree() and not target.disabled and inside:
					touch_pointer=event.index;touch_target=target
					get_viewport().set_input_as_handled();return
		elif not event.pressed and event.index==touch_pointer:
			var target:=touch_target
			touch_pointer=-1;touch_target=null
			get_viewport().set_input_as_handled()
			var inside:=target.get_global_rect().has_point(event.position)
			if target==skill_button and skill_hud.badge.visible:
				inside=inside or skill_hud.badge.get_global_rect().has_point(event.position)
			if not event.canceled and target.is_visible_in_tree() and not target.disabled and inside:target.pressed.emit()
			return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_exit()

func _select(key: String, enemy: bool) -> void:
	if enemy:
		rules.enemy_id = key
	else:
		rules.ally_id = key
	reset_round()

func reset_round(after_fade:=false) -> void:
	entrance_scale=REVIVAL_ENTRANCE_SCALE if after_fade else 1.0
	deer_hud_anchor=Vector2.INF
	deer_wake.clear()
	cast_notice.clear()
	cast_notice_layer.queue_redraw()
	hp_reveal_at=-1.0
	ground_wave_phase=0.0
	ground_wave_span=2.0
	accent.reset()
	touch_pointer=-1;touch_target=null
	rules.reset(rules.ally_id,rules.enemy_id)
	for item in audio_pool:
		item.stop()
		item.stream_paused=paused
	if a == null or b == null or a.key != rules.ally_id or b.key != rules.enemy_id:
		if is_instance_valid(shared_world):
			shared_world.detach();shared_world.queue_free();shared_world=null
		for actor in [a,b]:
			if actor != null:
				actor.preview.hide()
				actor.death_effect.hide()
				actor.preview.queue_free()
		a = Actor.new()
		b = Actor.new()
		a.create(field,rules.ally_id)
		b.create(field,rules.enemy_id)
		a.configure(true)
		b.configure(true)
		a.preview.scale = Vector2.ONE * (HANGYEOL_BATTLE_SCALE if a.key=="hangyeol" else 1.08 if a.key=="uram" else .90)
		b.preview.scale = Vector2.ONE * (FOREST_BATTLE_SCALE if b.key=="forest" else .92)
	motion = ["idle","idle"]
	age = [0.0,0.0]
	contact_at = [-1.0,-1.0]
	motion_contact = [-1.0,-1.0]
	frame_contact = [-1.0,-1.0]
	start_cast_at = -1.0
	execute_at = -1.0
	visual_clock = 0.0
	approach_active = _prototype_duel()
	next_attack = FIRST_BASIC.duplicate() if approach_active else [0.4,1.6]
	animal_attack_count = 0
	fx.clear()
	tip_trail.clear()
	a.play("idle")
	b.play("idle")
	a.preview.position = _position(0)
	b.preview.position = _position(1)
	cast_from=_settled_anchor(0)
	presentation.reset(rules.hp)
	presentation.grounded_spear=_prototype_duel()
	if _prototype_duel():
		presentation.cache_spear(a)
		a.preview.set_meta("duel_presenter",presentation)
		if not is_instance_valid(shared_world):
			shared_world=SharedWorld.new();shared_world.name="SharedDuelWorld";field.add_child(shared_world)
			shared_world.configure(a,b,(Left+Right)*.5)
		shared_world.reset()
	elif a.key=="hangyeol":
		a.play("attack")
		presentation.prepare_spear(a,_settled_anchor(0),_settled_anchor(1)-Vector2(0,33),a.duration*.55,0.0 if approach_active else 78.0)
		a.play("idle")
		if _prototype_duel():presentation.prepare_ready(a,_settled_anchor(0),_settled_anchor(1))
	if approach_active:
		motion = ["run","run"]
		a.play("run");b.play("run")
	_start_battle_camera()
	skill_hud.reset(a.key)
	_render_actors()
	cues.clear()
	effects_layer.queue_redraw()
	_refresh()

func _refresh(delta := 0.0) -> void:
	timer.text = rules.elapsed_label()
	presentation.update_hp(rules.hp,delta)
	for i in 2:
		bars[i].max_value = rules.full_hp(i)
		bars[i].value = presentation.hp[i]
	skill_hud.sync(rules.sp,rules.hp[0],rules.full_hp(0),rules.living(),_can_request(),delta)
	skill_hud.hp.value=presentation.hp[0]
	pause_caption.visible=paused;pause_icon.visible=not paused
	pause_button.tooltip_text="재개" if paused else "일시정지"
	name_labels[0].text=ModelTest.NAMES[rules.ally_id]
	name_labels[1].text="꽃사슴" if rules.enemy_id=="forest" else "큰 멧돼지"
	_update_head_hud(delta)
	_advance_ground_wave(delta)
	ready_light_layer.queue_redraw()
	location_layer.queue_redraw()
	for key in controls:
		var chosen:bool=key in [rules.ally_id,rules.enemy_id]
		controls[key].set_pressed_no_signal(chosen)
		selection_frames[key].visible=chosen

func _update_head_hud(delta:float)->void:
	if a==null or b==null:return
	var ally_anchor:=presentation.bone_point(a,"head")
	var deer_anchor:=_position(1)-Vector2(0,54)
	if is_instance_valid(shared_world):
		var nominal_head:Vector3=shared_world.bodies[1].position+Vector3.UP*2.02-shared_world.direction*.48
		deer_anchor=shared_world.project(nominal_head)
	# Smooth only real body travel before applying the current camera transform.
	if deer_hud_anchor==Vector2.INF:
		deer_hud_anchor=deer_anchor
	elif deer_hud_anchor.distance_squared_to(deer_anchor)>16.0 and delta>0:
		deer_hud_anchor=deer_hud_anchor.lerp(deer_anchor,1.0-exp(-12.0*delta))
	var transform:=field.get_transform()
	var points:=[transform*ally_anchor,transform*deer_hud_anchor]
	HeadHUD.layout_compact(overhead,points,Rect2(8,66,944,350))
	cast_notice_anchor=points[0]
	cast_notice_layer.queue_redraw()
	var reveal:=smoothstep(0,.27,visual_clock-hp_reveal_at) if hp_reveal_at>=0 else 0.0
	for side in overhead.size():
		var alpha:=reveal
		if rules.hp[side]<=0:
			alpha=minf(alpha,1.0-smoothstep(.13,.58,age[side]))
		var panel:Panel=overhead[side].panel
		panel.modulate.a=alpha
		panel.visible=alpha>.001

func _draw_cast_notice(anchor:Vector2)->void:
	if cast_notice.is_empty() or rules.hp[0]<=0:return
	var elapsed:=visual_clock-float(cast_notice.at)
	if elapsed>=.74:return
	var p:=clampf(elapsed/.74,0.0,1.0)
	var linked:bool=cast_notice.key=="chain"
	var tint:=Color("58b9ff") if linked else Color("ffd179")
	var alpha:float=smoothstep(0.0,.08,p)*(1.0-smoothstep(.65,1.0,p))
	var side:=lerpf(24.0,29.0,smoothstep(0,.24,p)) if linked else lerpf(20.0,24.0,smoothstep(0,.24,p))
	var panel:Control=overhead[0].panel
	var center:=Vector2(anchor.x,minf(anchor.y-17.0,panel.position.y-12.0) if panel.visible else anchor.y-17.0)
	center.y=maxf(70.0,center.y-lerpf(0.0,21.0,smoothstep(0,.78,p)))
	var extent:=Vector2.ONE*side
	var box:=Rect2(center-extent*.5,extent)
	cast_notice_layer.draw_texture_rect(ring_halo,box.grow(13.0),false,Color(tint,.72))
	cast_notice_layer.draw_style_box(cast_notice_frames[1 if linked else 0],box)
	cast_notice_layer.draw_texture_rect(cast_notice.icon,box.grow(-2.0),false,Color.WHITE)
	cast_notice_layer.modulate.a=alpha


func _can_request()->bool:
	return not paused and not approach_active and rules.living() and motion[0] in ["idle","walk","run","attack","hit"]

func _try_player(key: String) -> void:
	if not SP_COST.has(key) or not _can_request() or not rules.spend(int(SP_COST[key])):
		return
	cast_notice={"key":key,"at":visual_clock,"icon":skill_hud.chain_art.texture if key=="chain" else skill_hud.badge_art.texture}
	cast_from=_position(0)
	contact_at[0]=-1.0 # Cancel the interrupted automatic contact; never land it twice.
	_act(0,key)
	_render_actors()
	_refresh() # Consume SP and hide readiness in the same input frame.

func _act(side: int, key: String) -> void:
	var actor := a if side == 0 else b
	motion[side] = key
	age[side] = 0.0
	frame_contact[side]=-1.0
	actor.play(key)
	var duration: float = actor.duration
	contact_at[side] = duration * (.55 if key == "attack" else .63)
	if is_instance_valid(shared_world):shared_world.begin_action(side,key)
	if is_instance_valid(shared_world) and side==0 and key=="chain":accent.chain_started(duration)
	if not is_instance_valid(shared_world) and side==0 and actor.key=="hangyeol" and key in ["attack","skill"]:
		var travel := 0.0 if _prototype_duel() else 78.0
		presentation.prepare_spear(actor,_settled_anchor(0),_position(1)-Vector2(0,33),contact_at[side],travel)
	if _prototype_duel() and not is_instance_valid(shared_world) and side==0 and key=="chain":
		presentation.prepare_spear(actor,_settled_anchor(0),_position(1)-Vector2(0,33),contact_at[0],0)
	if side == 0 and key != "attack":
		start_cast_at = rules.elapsed
	if side == 1 and key == "skill":
		contact_at[side] = minf(duration-.03,float(Profile.CONTACT[actor.key]))
		execute_at = float(actor.preview.length("req046_skill_anticipation"))
		_sound("warning")
		_flash(_settled_anchor(1),"boss_gather" if b.key=="adult" else "gather",Color("#61bbff"),execute_at)
	else:
		var kind := "basic" if key == "attack" else key
		if not _prototype_duel():
			_sound(SoundNames[actor.key]+"_"+kind)
		if key != "attack" and not (_prototype_duel() and side==0):
			var ground := _settled_anchor(side)
			var name := "chain_"+actor.key if key == "chain" else "cast_"+actor.key
			_flash(ground,name,_ally_color(), duration if key == "chain" else minf(1.25,duration*.8))
	# A support cast and the shield preview have no fictitious target damage.
	if side == 0 and key == "chain" and actor.key != "hangyeol":
		contact_at[side] = -1.0
	var interval:float=BASIC_CADENCE[side] if _prototype_duel() else Rules.BASIC_EVERY
	next_attack[side] = rules.elapsed+maxf(interval,duration+.26)
	motion_contact[side]=contact_at[side]

func _ally_color() -> Color:
	return Color({"hangyeol":"#8bd7ff","uram":"#ef781e","saebom":"#ffe073"}[a.key])

func _sound(key: String) -> void:
	if not sounds.has(key):
		var path := SoundPath+key+".wav"
		sounds[key] = load(path) if ResourceLoader.exists(path) else null
	if sounds[key] == null:
		return
	cues.append(key)
	if cues.size()>128:
		cues.pop_front()
	var player := audio_pool[pool_index]
	pool_index = (pool_index+1)%audio_pool.size()
	for bus in ["Combat","SFX"]:
		if AudioServer.get_bus_index(bus) >= 0:
			player.bus = bus
			break
	player.stream = sounds[key]
	player.play()

func _land(side: int, key: String,contact:Dictionary={}) -> void:
	if approach_active or not rules.living():
		return
	if is_instance_valid(shared_world) and contact.is_empty():return
	var defender := 1-side
	var impact_point := _position(defender)-Vector2(0,33)
	if is_instance_valid(shared_world):impact_point=shared_world.project(contact.point)
	elif side==0 and a.key=="hangyeol" and (key in ["attack","skill"] or (_prototype_duel() and key=="chain")):
		# The calibrated mesh tip and the body's actual contact location coincide.
		impact_point=presentation.spear_point(a)
	var skill := key != "attack"
	if is_instance_valid(shared_world):
		motion_contact[side]=age[side] # Existing D0070 charge/impact FX now use contact time.
		shared_world.apply_hit(defender,contact.normal,skill)
		if side==0 and key=="chain":
			accent.chain_contact()
			_flash(impact_point,"han_chain_impact",Color.WHITE,.70)
			fx[-1]["floor_point"]=_position(defender)
	# Forward approach moves the actor to its strike distance. Check the
	# simulation positions at contact instead of firing a hit from a timer alone.
	var origin := _position(side)
	var target := _position(defender)
	var reach := 180.0 if (side==0 and a.key=="saebom") else 104.0
	if not is_instance_valid(shared_world) and origin.distance_to(target) > reach:
		return
	if side == 1 and skill:
		_flash(_position(0),"burst",Color("#ffad26"),.40)
	if skill:
		if _prototype_duel() and side==0:_sound("han_"+key)
		_sound("ally_hit" if defender==0 else SoundNames[b.key]+"_hit")
	if _prototype_duel():
		presentation.recoil[defender]=origin.direction_to(target)*(6.0 if skill else 3.0)
		presentation.recoil_age[defender]=.025
		var hold:=.48 if skill else .16
		if is_instance_valid(shared_world) and side==0:
			if key=="attack":hold=.23
			elif key=="skill":hold=.68
		if is_instance_valid(shared_world) and side==1 and key=="skill":hold=.67
		_flash(impact_point,"contact_"+key,tone_for_contact(side),hold)
		fx[-1]["attacker"]=side
		if is_instance_valid(shared_world) and key=="skill":
			var ground_point:Vector3=contact.point
			ground_point.y=0
			fx[-1]["floor_point"]=shared_world.project(ground_point)
	# Han is a light glint, Uram dust, Saebom stone fragments. The inbound
	# ordinary hit reads as the agreed short white glint.
	var tone := Color("#fff5df") if defender == 0 or a.key=="hangyeol" else Color("#cf9862")
	if not skill:
		if _prototype_duel():
			_sound(SoundNames[(a if side==0 else b).key]+"_basic")
		if not _prototype_duel():_flash(impact_point,"hit",tone,.21)
	if hp_reveal_at<0:hp_reveal_at=visual_clock
	if rules.damage(defender,38 if key=="chain" else 27 if skill else 11 if side==0 else 13):
		_die(defender)
		return
	# Do not cut off a concurrently committed attack for a cosmetic reaction.
	if motion[defender] == "idle" or (defender==1 and motion[defender]=="walk" and is_instance_valid(shared_world)):
		_react(defender,"hit")

func _react(side: int, key: String) -> void:
	var actor := a if side==0 else b
	motion[side] = key
	age[side] = 0.0
	frame_contact[side]=-1.0
	if key=="death" and is_instance_valid(shared_world):
		actor.preview.animation.pause()
		actor.death_effect.clear()
	else:
		actor.play(key)
	if _prototype_duel() and not is_instance_valid(shared_world) and side==0 and key=="idle":
		presentation.prepare_ready(a,_settled_anchor(0),_position(1))

func tone_for_contact(side:int)->Color:
	return Color("bcefff") if side==0 else Color("fff4df")

func _die(side: int) -> void:
	if is_instance_valid(shared_world):
		rules.revive_at[side]=rules.elapsed+SHARED_REVIVAL_DELAY
	_react(side,"death")
	contact_at = [-1.0,-1.0]
	execute_at = -1.0
	_sound("ally_death" if side==0 else "enemy_death")

func _visual_age(side:int)->float:
	return float(frame_contact[side]) if float(frame_contact[side])>=0 else float(age[side])

func _position(side: int) -> Vector2:
	if is_instance_valid(shared_world):return shared_world.body_screen(side)
	var place := _settled_anchor(side)
	if approach_active:
		return _duel_anchor(side,lerpf(START_GAP,ENGAGE_GAP,smoothstep(0.0,APPROACH_TRAVEL,visual_clock)))
	if _prototype_duel() and motion[side]=="attack" and side==1:
		return place
	if motion[side] not in ["attack","skill","chain"]:
		return place
	if side==0 and a.key=="saebom":
		return place
	if side==0 and motion[side]=="chain" and a.key=="uram":
		return place
	var elapsed := _visual_age(side)
	var duration := a.duration if side==0 else b.duration
	var impact := float(motion_contact[side])
	if impact <= 0.0:
		impact = duration*.59 if side==0 or motion[side]!="skill" else float(Profile.CONTACT[b.key])
	var windup := float(b.preview.length("req046_skill_anticipation")) if side==1 and motion[side]=="skill" else 0.0
	var p := (elapsed-windup)/maxf(.04,impact-windup) if elapsed < impact else 1.0-(elapsed-impact)/maxf(.04,duration-impact)
	var direction := Left.direction_to(Right)*(1.0 if side==0 else -1.0)
	if _prototype_duel():
		if side==0:
			var correction:Vector2=(presentation.thrust_peak+_position(1)-presentation.thrust_target).limit_length(BASIC_MAX_TRAVEL)
			var result:=place+correction*smoothstep(.05,.96,clampf(p,0,1))
			if motion[0] in ["skill","chain"]:result+=(cast_from-place)*(1.0-smoothstep(0,.18,elapsed))
			return result
		# A deer cannot lunge its body past the actual defender either.
		return place+direction*maxf(0,place.distance_to(_settled_anchor(0))-35.0)*smoothstep(.05,.96,clampf(p,0,1))
	var point:=place + direction*78.0*smoothstep(0.05,0.96,clampf(p,0,1))
	if side==0 and a.key=="hangyeol" and motion[0] in ["attack","skill"]:
		var correction := presentation.thrust_peak+_position(1)-presentation.thrust_target
		if _prototype_duel() and motion[0]=="attack":
			correction=correction.limit_length(BASIC_MAX_TRAVEL)
		point=place+correction*smoothstep(0.05,0.96,clampf(p,0,1))
	if side==0 and motion[0] in ["skill","chain"]:point+=(cast_from-_settled_anchor(0))*(1.0-smoothstep(0,.18,elapsed))
	return point

func _process(delta: float) -> void:
	if app != null and not app.application_active:
		return
	advance(delta)

func advance(delta: float) -> void:
	if paused:return
	if is_instance_valid(shared_world):
		_advance_shared(delta)
		return
	if approach_active:
		var used:=minf(delta,APPROACH_END-visual_clock)
		visual_clock+=used
		if visual_clock>=APPROACH_TRAVEL and motion[0]=="run":
			_react(0,"idle");_react(1,"idle")
		else:
			for side in 2:
				age[side]+=used
		_render_actors(used)
		if visual_clock+.000001<APPROACH_END:
			return
		approach_active=false
		_refresh()
		delta-=used
		if delta<=.000001:
			return
	visual_clock += delta
	var revived := rules.advance(delta)
	if not revived.is_empty():
		reset_round()
		return
	for side in 2:
		age[side]+=delta
		# On a low-FPS frame crossing contact, show the actual contact pose once
		# instead of skipping straight to recovery. Simulation time is untouched.
		frame_contact[side]=contact_at[side] if float(contact_at[side])>=0 and float(age[side])>=float(contact_at[side]) else -1.0
	# Sample both participants at this frame before evaluating contact, so FX,
	# reactions and display HP start from the same visible hit frame.
	_render_actors(delta)
	for side in 2:
		if side==1 and execute_at>=0.0 and float(age[side])>=execute_at:
			_sound(SoundNames[b.key]+"_skill")
			execute_at = -1.0
	var order: Array[int] = [0,1]
	# Preserve chronological order if a single frame crosses both impacts.
	if _prototype_duel() and frame_contact[0]>=0.0 and frame_contact[1]>=0.0:
		if float(age[1])-float(frame_contact[1])>float(age[0])-float(frame_contact[0]):
			order.reverse()
	for side in order:
		if frame_contact[side]>=0.0 and contact_at[side]>=0.0:
			_land(side,motion[side])
			contact_at[side]=-1.0
	for side in 2:
		var actor := a if side==0 else b
		if motion[side] not in ["idle","death"] and float(age[side])>=actor.duration:
			_react(side,"idle")
	if rules.living():
		if motion[0]=="idle" and rules.elapsed>=float(next_attack[0]):
			_act(0,"attack")
		if motion[1]=="idle" and rules.elapsed>=float(next_attack[1]):
			animal_attack_count += 1
			_act(1,"skill" if animal_attack_count%3==0 else "attack")
	_render_actors()
	effects_layer.queue_redraw()
	_refresh(delta)

func _start_battle_camera()->void:
	# Pre-roll only the production VS camera (not AI, SP, audio or rewards).
	# This preserves the real first battle frame's residual zoom, followed by
	# the same production-camera easing, instead of forcing a settled frame.
	field.scale=Vector2.ONE;field.position=Vector2.ZERO
	battle_camera.pose="";battle_camera.approach=0; battle_camera.transition_elapsed=0
	battle_camera.update_camera(0)
	var time:=0.0
	while time<Hunt.TRANSITION_SECONDS:
		time+=1.0/60.0
		battle_camera.approach=smoothstep(.06,.98,clampf(time/Hunt.TRANSITION_SECONDS,0,1))
		battle_camera.transition_elapsed=-1.0 if time>=Hunt.TRANSITION_SECONDS else time
		battle_camera.update_camera(1.0/60.0)
	camera_base_scale=field.scale;camera_base_position=field.position

func _render_actors(delta:=0.0)->void:
	if is_instance_valid(shared_world):
		if delta==0:shared_world.render_poses(self,0)
		a.preview.position=_position(0);b.preview.position=_position(1)
		a.place_effect();b.place_effect()
		if motion[0] in ["skill","chain"] and delta>0:
			tip_trail.push_front(presentation.spear_point(a))
			if tip_trail.size()>7:tip_trail.pop_back()
		elif motion[0] not in ["skill","chain"]:tip_trail.clear()
		battle_camera.hunters.assign([a.preview]);battle_camera.rules.attacker=0
		battle_camera.pose="strike" if start_cast_at>=0 and rules.elapsed-start_cast_at<.70 and accent.kind!="chain" else ""
		battle_camera.pose_clock=(rules.elapsed-start_cast_at)/.70*Hunt.RULES.POSE_SECONDS
		field.scale=camera_base_scale;field.position=camera_base_position
		if delta>0:battle_camera.update_camera(delta)
		camera_base_scale=field.scale;camera_base_position=field.position
		var focus:Vector2=(_position(0)+_position(1))*.5
		field.scale=camera_base_scale*accent.zoom
		field.position=camera_base_position+camera_base_scale*focus*(1-accent.zoom)
		if delta>0 and accent.zoom>1:
			var center:Vector2=arena.position+(camera_base_position+camera_base_scale*focus)*arena.scale
			ground.position=center+(ground.position-center)*accent.zoom;ground.scale*=accent.zoom
		return
	a.preview.position=_position(0);b.preview.position=_position(1)
	if a.key=="hangyeol":
		var run_heading:=atan2((Right-Left).x,(Right-Left).y)
		var settle:=smoothstep(APPROACH_TRAVEL,APPROACH_END,visual_clock)
		var heading:=lerp_angle(run_heading,presentation.thrust_yaw,settle) if approach_active else presentation.thrust_yaw
		if _prototype_duel() and motion[0] in ["idle","hit","death"]:heading=presentation.ready_yaw
		a.preview.pivot.rotation.y=run_heading if motion[0]=="chain" and not _prototype_duel() else heading
	presentation.sample(a,0,motion[0],_visual_age(0),INF if approach_active else float(next_attack[0])-rules.elapsed,delta)
	presentation.sample(b,1,motion[1],_visual_age(1),INF if approach_active else float(next_attack[1])-rules.elapsed,delta)
	if _prototype_duel():
		# Ground depth controls the compositing of independent 3D viewports.
		a.preview.z_index=2 if a.preview.position.y>=b.preview.position.y else 1
		b.preview.z_index=1 if a.preview.z_index==2 else 2
		for side in 2:
			presentation.recoil_age[side]+=delta
			var q:=clampf(presentation.recoil_age[side]/.28,0,1)
			var actor:=a if side==0 else b
			actor.preview.position+=presentation.recoil[side]*sin(PI*q)*(1-q)
		if motion[0] in ["skill","chain"]:
			if delta>0:
				tip_trail.push_front(presentation.spear_point(a))
				if tip_trail.size()>7:tip_trail.pop_back()
		else:tip_trail.clear()
	a.place_effect();b.place_effect()
	battle_camera.hunters.assign([a.preview]);battle_camera.rules.attacker=0
	battle_camera.pose="strike" if start_cast_at>=0 and rules.elapsed-start_cast_at<.70 else ""
	battle_camera.pose_clock=(rules.elapsed-start_cast_at)/.70*Hunt.RULES.POSE_SECONDS
	if delta>0:battle_camera.update_camera(delta)

func _advance_shared(delta:float)->void:
	# Render rate-independent continuous body/weapon integration. No timer can
	# call _land on this path: only a swept 3D hurt-volume contact can do so.
	while delta>.0000001:
		var dt:=minf(delta,SharedWorld.FIXED_STEP);delta-=dt
		visual_clock+=dt
		accent.advance(dt)
		if approach_active:
			for side in 2:age[side]+=dt
			shared_world.step(self,dt)
			if visual_clock>=APPROACH_TRAVEL*entrance_scale and motion[0]=="run":_react(0,"idle");_react(1,"idle")
			if visual_clock+.000001>=APPROACH_END*entrance_scale:approach_active=false
			_advance_ground_wave(dt)
			_render_actors(dt);_refresh();continue
		if not rules.advance(dt).is_empty():reset_round(true);return
		var prior_han_age:float=age[0]
		for side in 2:
			age[side]+=dt;frame_contact[side]=-1.0
		if motion[0]=="skill" and not shared_world.consumed[0]:
			var windup_end:=minf(HAN_SKILL_WINDUP_LIMIT,a.duration*.55)
			var sped_time:=clampf((windup_end-prior_han_age)/HAN_SKILL_WINDUP_RATE,0,dt)
			age[0]+=sped_time*(HAN_SKILL_WINDUP_RATE-1)
		var events:=shared_world.step(self,dt,prior_han_age)
		_sample_deer_wake()
		for event in events:_land(int(event.side),event.motion,event)
		if execute_at>=0 and age[1]>=execute_at:
			_sound(SoundNames[b.key]+"_skill");execute_at=-1
		for side in 2:
			var actor:=a if side==0 else b
			if side==1 and motion[1]=="walk":
				if shared_world.deer_return_offset().length()<.005 or age[1]>=1.2:
					_react(1,"idle")
			elif motion[side] not in ["idle","death"] and age[side]>=actor.duration:
				if side==1 and rules.living() and motion[1] in ["attack","skill","hit"] and shared_world.action_name[1] in ["attack","skill"] and shared_world.deer_return_offset().length()>.045:
					# The lunge and backwards hoof steps are one committed move.
					# Only the lunge has a contact window.
					_react(1,"walk")
				else:
					_react(side,"idle")
		if rules.living():
			if motion[0]=="idle" and rules.elapsed>=next_attack[0]:_act(0,"attack")
			if motion[1]=="idle" and rules.elapsed>=next_attack[1]:
				animal_attack_count+=1;_act(1,"skill" if animal_attack_count%3==0 else "attack")
		_render_actors(dt);_refresh(dt)
	effects_layer.queue_redraw()

func _flash(center: Vector2, key: String, tint: Color, duration: float) -> void:
	fx.append({"center":center,"name":key,"color":tint,"duration":duration,"at":visual_clock})

func _soft_light(center:Vector2,extent:Vector2,tint:Color,alpha:float,layer:Node2D=null)->void:
	if alpha<=0:return
	if not contact_glow:
		contact_glow=GradientTexture2D.new();contact_glow.width=64;contact_glow.height=64
		contact_glow.fill=GradientTexture2D.FILL_RADIAL;contact_glow.fill_from=Vector2(.5,.5);contact_glow.fill_to=Vector2(1,.5)
		var gradient:=Gradient.new();gradient.offsets=PackedFloat32Array([0,.18,.48,1])
		gradient.colors=PackedColorArray([Color(1,1,1,.95),Color(1,1,1,.65),Color(1,1,1,.18),Color(1,1,1,0)])
		contact_glow.gradient=gradient
	var target:=effects_layer if layer==null else layer
	target.draw_texture_rect(contact_glow,Rect2(center-extent*.5,extent),false,Color(tint,alpha))

func _location_ring(side:int)->PackedVector2Array:
	var path:=PackedVector2Array()
	if a==null or b==null or rules.hp[side]<=0:return path
	var center:=_position(side)
	for j in 41:
		var angle:=TAU*float(j)/40.0
		var unit:=Vector2.from_angle(angle)
		if is_instance_valid(shared_world):
			var radius:=.64
			var origin:Vector3=shared_world.bodies[side].position
			path.append(shared_world.project(origin+Vector3(unit.x*radius,.025,unit.y*radius)))
		else:
			var span:=Vector2(24,9)
			path.append(center+unit*span)
	return path

func _new_ring_light(stops:PackedFloat32Array,levels:PackedFloat32Array)->GradientTexture2D:
	var gradient:=Gradient.new()
	gradient.offsets=stops
	var colors:=PackedColorArray()
	for alpha in levels:colors.append(Color(1,1,1,alpha))
	gradient.colors=colors
	var texture:=GradientTexture2D.new()
	texture.width=128;texture.height=128
	texture.fill=GradientTexture2D.FILL_RADIAL
	texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(1,.5)
	texture.gradient=gradient
	return texture

func _ground_wave_profile()->Vector2:
	if not _can_request():return Vector2.ZERO
	if skill_hud.chain_ready:return Vector2(3.0,2.0)
	if skill_hud.normal_ready:return Vector2(2.0,1.5)
	return Vector2.ZERO

func _advance_ground_wave(delta:float)->void:
	if paused or delta<=0:return
	var profile:=_ground_wave_profile()
	if profile==Vector2.ZERO:
		ground_wave_phase=0.0
		ground_wave_span=2.0
		return
	ground_wave_phase=fposmod(ground_wave_phase+delta*profile.y/GROUND_WAVE_SECONDS,1.0)
	ground_wave_span=lerpf(ground_wave_span,profile.x,1.0-exp(-15.0*delta))

func _inward_ring_scale(phase:float,start:float=1.2)->float:
	return lerpf(start,.035,smoothstep(0.0,1.0,phase))

func _draw_location_rings()->void:
	for side in 2:
		var path:=_location_ring(side)
		if path.is_empty():continue
		var bounds:=Rect2(path[0],Vector2.ZERO)
		for point in path:bounds=bounds.expand(point)
		var center:=bounds.get_center()
		var tint:=HeadHUD.duel_team_color(side==0)
		var settled:=bounds.size*1.08
		var ring_box:=bounds.size/.68
		location_layer.draw_texture_rect(ring_halo,Rect2(center-settled*.5,settled),false,Color(tint,.54))
		location_layer.draw_texture_rect(ring_band,Rect2(center-ring_box*.5,ring_box),false,Color(tint,.97))
		if side!=0 or _ground_wave_profile()==Vector2.ZERO:continue
		var phase:=ground_wave_phase
		var closing_size:=ring_box*_inward_ring_scale(phase,ground_wave_span)
		var opacity:=.72*smoothstep(0,.14,phase)*(1.0-smoothstep(.86,1.0,phase))
		location_layer.draw_texture_rect(ring_band,Rect2(center-closing_size*.5,closing_size),false,Color(tint.lightened(.25),opacity))
		var focus:=smoothstep(.71,.93,phase)*(1.0-smoothstep(.95,1.0,phase))
		var dot_size:=Vector2(10,7)*lerpf(.6,1,focus)
		if focus>0:
			location_layer.draw_texture_rect(ring_halo,Rect2(center-dot_size*.5,dot_size),false,Color(tint.lightened(.45),focus*.84))

func _han_tip_light_position()->Vector2:
	if not is_instance_valid(shared_world) or rules.hp[0]<=0:return Vector2.INF
	return presentation.spear_point(a)

func _sample_deer_wake()->void:
	while not deer_wake.is_empty() and visual_clock-float(deer_wake[0].at)>.59:
		deer_wake.pop_front()
	if motion[1]!="skill" or not rules.living():return
	var anticipation:float=b.preview.length("req046_skill_anticipation")
	if age[1]<anticipation:return
	var foot:=_position(1)
	if not deer_wake.is_empty():
		var last:Vector2=deer_wake[-1].foot
		if foot.distance_squared_to(last)<8.0:return
	deer_wake.append({"foot":foot,"at":visual_clock})
	if deer_wake.size()>20:deer_wake.pop_front()

func _draw_duel_lights()->void:
	var tip:=_han_tip_light_position()
	if tip!=Vector2.INF:
		var breath:=.88+.12*sin(visual_clock*TAU*.75)
		var hand:=presentation.bone_point(a,"hand.R")
		var blade:=tip-hand
		var blade_length:=clampf(blade.length()*.24,10,21)
		var blade_center:=tip-blade.normalized()*blade_length*.42
		ready_light_layer.draw_set_transform(blade_center,blade.angle(),Vector2.ONE)
		_soft_light(Vector2.ZERO,Vector2(blade_length*1.68,13),Color("389fff"),.31*breath,ready_light_layer)
		_soft_light(Vector2(1,0),Vector2(blade_length*1.24,5.5),Color("96dcff"),.34*breath,ready_light_layer)
		ready_light_layer.draw_set_transform(Vector2.ZERO)
	_draw_deer_skill_lights()

func _draw_deer_skill_lights()->void:
	if not is_instance_valid(shared_world):return
	for j in deer_wake.size():
		var entry:=deer_wake[j]
		var elapsed:float=visual_clock-float(entry.at)
		var fade:=1.0-smoothstep(.01,.59,elapsed)
		var foot:Vector2=entry.foot
		if j>0:
			var prev:Vector2=deer_wake[j-1].foot
			ready_light_layer.draw_line(prev,foot,Color(1,.52,.13,.24*fade),lerpf(13,28,fade),true)
			ready_light_layer.draw_line(prev,foot,Color(1,.88,.46,.42*fade),lerpf(3,9,fade),true)
		_soft_light(foot,Vector2(lerpf(77,35,fade),lerpf(30,16,fade)),Color("ff8f22"),fade*.48,ready_light_layer)
		_soft_light(foot,Vector2(45,17),Color("ffc86a"),fade*.44,ready_light_layer)
	if motion[1]!="skill" or rules.hp[1]<=0:return
	var warning:float=maxf(.01,b.preview.length("req046_skill_anticipation"))
	var progress:=clampf(float(age[1])/warning,0,1)
	var drive:=float(age[1])>=warning
	var swell:=smoothstep(.02,.80,progress)
	var beat:=.77+.23*sin(float(age[1])*TAU*2.2)
	var intensity:=lerpf(.24,1.0,swell)*beat if not drive else 1.0
	var hoof:=_position(1)
	var head:=shared_world.bone_screen(1,"head")
	var sk:Skeleton3D=b.preview.skeleton
	var antlers:=sk.get_bone_global_pose(sk.find_bone("head"))
	for sign_x in [-1.0,1.0]:
		# The mesh has no antler bones; the two sockets follow its head pose.
		var socket:Vector3=sk.to_global(antlers*Vector3(.21*sign_x,.36,.06))
		var glow:=shared_world.project(socket)
		_soft_light(glow,Vector2(34,27),Color("ff9f2a"),intensity*.49,ready_light_layer)
		_soft_light(glow,Vector2(11,9),Color("ffdfa1"),intensity*.47,ready_light_layer)

	if drive:
		_soft_light(shared_world.project(shared_world.weapon_point(1)),Vector2(49,39),Color("ffd573"),.53,ready_light_layer)
		return
	var wave:=fposmod(float(age[1])*1.55,1.0)

	for j in 9:
		var angle:=float(j)*2.39996+float(age[1])*1.8
		var stream:=fposmod(wave+float(j)*.113,1.0)
		var point:=hoof.lerp(head,stream*.76)+Vector2(cos(angle)*58,sin(angle)*15)*(1-stream)
		_soft_light(point,Vector2(14,11),Color("fff0be"),sin(PI*stream)*intensity*.82,ready_light_layer)

func _draw_deer_impact(effect:Dictionary,p:float)->void:
	var at:Vector2=effect.center
	var flare:=1.0-smoothstep(.02,.62,p)
	var afterglow:=1.0-smoothstep(.06,1.0,p)
	var extent:=Vector2(112,76)
	_soft_light(at,extent*1.76,Color("ff8627"),afterglow*.91)
	_soft_light(at,extent*.82,Color("fff5d2"),flare)
	effects_layer.draw_texture_rect(Hunt.HEAVY_HIT,Rect2(at-extent*.5,extent),false,Color("ffe5a1",flare))
	var floor_point:Vector2=effect.floor_point
	var span:=Vector2(lerpf(60,177,p),lerpf(20,55,p))
	effects_layer.draw_texture_rect(Hunt.GROUND_PULSE,Rect2(floor_point-span*.5,span),false,Color(1,.64,.22,afterglow*.85))
	for j in 11:
		var angle:=float(j)*2.4
		var spark:=at+Vector2(cos(angle),sin(angle)*.62)*lerpf(7,62+float(j%3)*9,sqrt(p))
		_soft_light(spark,Vector2(16,11),Color("ffda7a"),afterglow*.72)

func _draw_han_skill_light(tip:Vector2,charge:float)->void:
	var hand:=presentation.bone_point(a,"hand.R")
	var foot:=_position(0)+Vector2(0,2)
	var power:=smoothstep(.03,.68,charge)
	_soft_light(foot,Vector2(78,28),Color("319cfd"),power*.56)
	_soft_light(hand,Vector2(44,39),Color("4ac5ff"),power*.66)
	for j in range(1,5):
		var f:=float(j)/5.0
		_soft_light(hand.lerp(tip,f),Vector2(29,18),Color("8ce8ff"),power*(.2+f*.18))
	for j in tip_trail.size():
		var tail:=1.0-float(j)/maxf(1,tip_trail.size())
		_soft_light(tip_trail[j],Vector2(49,27)*tail,Color("65bbff"),tail*power*.57)
	_soft_light(tip,Vector2(85,64),Color("56c6ff"),power*.96)
	_soft_light(tip,Vector2(35,31),Color("e3fbff"),power)

func _draw_han_impact(effect:Dictionary,p:float,basic:bool)->void:
	var at:Vector2=effect.center
	var flare:=1.0-smoothstep(.02,.67,p)
	var glow:=1.0-smoothstep(.05,1.0,p)
	var extent:=Vector2(37,25) if basic else Vector2(116,78)
	_soft_light(at,extent*(1.83 if basic else 2.0),Color("46baff"),glow*.91)
	_soft_light(at,extent*.82,Color("ebfdff"),flare)
	if basic:
		effects_layer.draw_texture_rect(Hunt.BASIC_HIT,Rect2(at-extent*.5,extent),false,Color("d7f5ff",flare))
		return
	var axis:=(_position(1)-_position(0)).angle()
	effects_layer.draw_set_transform(at,axis,Vector2.ONE)
	_soft_light(Vector2(-14,0),Vector2(145,24),Color("369cff"),flare*.90)
	_soft_light(Vector2(-10,0),Vector2(80,9),Color("d8f6ff"),flare*.94)
	_soft_light(Vector2(0,0),Vector2(24,29),Color("ecfbff"),flare*.86)
	effects_layer.draw_set_transform(Vector2.ZERO)
	var ground_mark:Vector2=effect.floor_point
	var spread:=Vector2(lerpf(62,178,p),lerpf(20,50,p))
	effects_layer.draw_texture_rect(Hunt.GROUND_PULSE,Rect2(ground_mark-spread*.5,spread),false,Color(.45,.81,1,glow*.8))
	_soft_light(ground_mark,spread*.89,Color("49b5ff"),glow*.63)
	for j in 15:
		var angle:=float(j)*2.39996
		var spark:=at+Vector2(cos(angle),sin(angle)*.62)*lerpf(9,59+float(j%3)*7,sqrt(p))
		_soft_light(spark,Vector2(14,10)*lerpf(1,.4,p),Color("b8eeff"),glow*.72)

func _draw_contact_effects()->void:
	# Reuse the campaign's painted contact/ground assets, anchored to the sampled
	# mesh and actual collision. No free-floating debug lines, circles or dots.
	if motion[0] in ["skill","chain"]:
		var tip:=presentation.spear_point(a)
		var p:=clampf(_visual_age(0)/maxf(.01,motion_contact[0]),0,1)
		if motion[0]=="chain" and _visual_age(0)<motion_contact[0]:
			var foot:=_position(0)
			var hand:=presentation.bone_point(a,"hand.R")
			var chest:=a.screen_anchor()
			var gather:=smoothstep(0,.7,p)
			_soft_light(foot,Vector2(66,23),Color("69bbff"),sin(PI*p)*.65)
			_soft_light(foot.lerp(chest,smoothstep(.1,.55,p)),Vector2(34,48),Color("65baff"),sin(PI*p)*.55)
			_soft_light(chest.lerp(hand,smoothstep(.35,.75,p)),Vector2(33,33),Color("8bdcff"),gather*.5)
			_soft_light(hand.lerp(tip,smoothstep(.55,1,p)),Vector2(31,31),Color("a6eaff"),gather*.75)
		if motion[0]=="skill" and is_instance_valid(shared_world):
			var release:=1.0 if not shared_world.consumed[0] else 1.0-smoothstep(motion_contact[0],motion_contact[0]+.29,age[0])
			if release>0:_draw_han_skill_light(tip,p*release)
		elif p>.65:
			for j in tip_trail.size():
				_soft_light(tip_trail[j],Vector2(19,12)*(1.0-float(j)/10),Color("9bdfff"),.32*(1.0-float(j)/7))
			_soft_light(tip,Vector2(24,24),Color("d8f7ff"),.6)
	for i in range(fx.size()-1,-1,-1):
		var effect:=fx[i]
		var p:float=(visual_clock-float(effect.at))/float(effect.duration)
		if p>=1:fx.remove_at(i);continue
		if effect.name=="han_chain_impact":
			var index:=clampi(floori((visual_clock-float(effect.at))*30),0,20)
			var factor:=.58
			var burst:=1.0-smoothstep(.04,.71,p)
			_soft_light(effect.center,Vector2(173,108),Color("43aaff"),burst*.90)
			_soft_light(effect.center,Vector2(42,37),Color("ebfcff"),burst*.9)
			var ground_point:Vector2=effect.get("floor_point",effect.center+Vector2(0,17))
			var wake_size:=Vector2(lerpf(86.0,208.0,p),lerpf(28.0,66.0,p))
			_soft_light(ground_point,wake_size,Color("79cdff"),.75*(1.0-smoothstep(0,1,p)))
			effects_layer.draw_texture_rect(chain_impact_frames[index],Rect2(effect.center-Vector2(192,243)*factor,Vector2(384,384)*factor),false)
			continue
		if not String(effect.name).begins_with("contact_"):continue
		var basic:bool=effect.name=="contact_attack"
		var strong:bool=effect.name=="contact_chain"
		if is_instance_valid(shared_world) and effect.get("attacker",-1)==1 and effect.name=="contact_skill":
			_draw_deer_impact(effect,clampf(p,0,1))
			continue
		if is_instance_valid(shared_world) and effect.get("attacker",-1)==0 and (basic or effect.name=="contact_skill"):
			_draw_han_impact(effect,clampf(p,0,1),basic)
			continue
		if strong and is_instance_valid(shared_world):continue # Replace only the shared-world pilot impact.
		var at:Vector2=effect.center
		var fade:=1.0-smoothstep(.05,1,p)
		var extent:=Vector2(22,19) if basic else Vector2(74,58) if strong else Vector2(51,38)
		var texture:Texture2D=Hunt.BASIC_HIT if basic else Hunt.HEAVY_HIT
		if is_instance_valid(shared_world):
			extent*=1.28
			_soft_light(at,extent*1.75,effect.color,fade*.65)
		effects_layer.draw_texture_rect(texture,Rect2(at-extent*.5,extent),false,Color(effect.color,fade))
		if not basic:
			_soft_light(at,extent*1.35,Color("74c9ff"),fade*.55)
			if strong:
				var ground_size:=Vector2(96,34)*lerpf(.55,1.4,p)
				effects_layer.draw_texture_rect(Hunt.GROUND_PULSE,Rect2(_position(1)-ground_size*.5,ground_size),false,Color(.65,.85,1,fade))

func _draw_effects() -> void:
	if _prototype_duel():
		_draw_contact_effects()
		return
	for i in range(fx.size()-1,-1,-1):
		var effect := fx[i]
		var p := (visual_clock-float(effect.at))/maxf(.01,float(effect.duration))
		if p>=1.0:
			fx.remove_at(i)
			continue
		var color: Color = effect.color
		var center: Vector2 = effect.center
		if effect.name in ["cast_hangyeol","cast_uram","cast_saebom"]:
			var alpha := sin(PI*p)
			var hand := center+Vector2(29,-40)
			match effect.name:
				"cast_hangyeol":
					# Weapon trail follows the sampled mesh; no unrelated down-right beam.
					if a.key=="hangyeol" and motion[0]=="skill":
						var head:=presentation.spear_point(a)
						var tail:=head+head.direction_to(_position(0))*12.0
						effects_layer.draw_line(tail,head,Color(color,alpha*.5),3.0*alpha,true)
				"cast_uram":
					var at := hand+Vector2(18,2)
					effects_layer.draw_arc(at,41,lerpf(-2.2,-.4,p),lerpf(-.8,1.3,p),30,Color(color,alpha*.55),16.0*alpha,true)
					effects_layer.draw_arc(at,41,lerpf(-2.2,-.4,p),lerpf(-.8,1.3,p),30,Color(color,alpha),4.0*alpha,true)
				"cast_saebom":
					var at := hand+Vector2(-33,-17)
					if p < .72:
						var begin := TAU*2.0*pow(p/.72,1.7)
						effects_layer.draw_arc(at,25.0,begin,begin+3.9,30,Color("#ef5553",alpha*.85),6.0*alpha,true)
					else:
						var head := at+Vector2(35+125*((p-.72)/.28),18)
						effects_layer.draw_line(at,head,Color("#ef5553",alpha),7.0*alpha,true)
		elif effect.name in ["gather","boss_gather"] or String(effect.name).begins_with("chain_"):
			var chain := String(effect.name).begins_with("chain_")
			var boss: bool = effect.name=="boss_gather"
			var phase := clampf(p/.45,0,1) if chain else p
			if chain and p > .43:
				var lift := (p-.43)/.57
				var tip := center+Vector2(28,-53)
				if effect.name=="chain_hangyeol":
					tip = center+Vector2(37,-100*sin(PI*lift)-29)
				var body := center.lerp(tip,clampf(lift*1.7,0,1))
				effects_layer.draw_line(center.lerp(body,.25),body,Color(color,.37*(1-lift)),15,true)
				effects_layer.draw_circle(body,lerpf(17,39,lift),Color(color,.62*(1-lift)))
			if boss:
				var beat := fposmod(p*3.0,1.0)
				for j in 22:
					var dir := Vector2.from_angle(float(j)*TAU/22.0)
					var trail := dir * lerpf(182.0,14.0,beat)
					effects_layer.draw_line(center+trail,center+trail*.80,Color("#ed6962",.58*(1.0-p*.35)),2.4,true)
			for j in 12:
				var dir := Vector2.from_angle(float(j)*TAU/12.0)
				var offset := dir * lerpf(138 if boss else 86,6,phase) * Vector2(1,.35)
				effects_layer.draw_circle(center+offset,2.0+2.0*p,Color(color,.6))
			effects_layer.draw_set_transform(center,0,Vector2(1,.36))
			effects_layer.draw_arc(Vector2.ZERO,lerpf(82 if boss else 49,10,phase),0,TAU,38,Color(color,.55),3.0,true)
			effects_layer.draw_set_transform(Vector2.ZERO)
		else:
			var radius := lerpf(6,(67 if b.key=="adult" else 43) if effect.name=="burst" else 21,p)
			effects_layer.draw_circle(center,radius,Color(color,.33*(1.0-p)))
			for j in 11:
				var dir := Vector2.from_angle(float(j)*TAU/7.0+.16)
				effects_layer.draw_line(center+dir*radius*.5,center+dir*radius,Color(color,1.0-p),3.0*(1.0-p),true)
