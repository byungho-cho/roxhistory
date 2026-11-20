extends Control
signal exited

const SkillHUD = preload("res://scripts/duel_skill_hud.gd")
const Rules = preload("res://scripts/hunt_duel_rules.gd")
const Actor = preload("res://scripts/model_test_actor.gd")
const ModelTest = preload("res://scripts/model_test.gd")
const Profile = preload("res://scripts/model_motion_profile.gd")
const Hunt = preload("res://scripts/deer_hunt_screen.gd")
const HuntArt = preload("res://scripts/hunt_match_art.gd")
const Ground = preload("res://assets/ui/hunting-formation/clearing-dirt.png")
const UIFont = preload("res://assets/fonts/NotoSansKR.ttf")
const SceneSize := Vector2(960,540)
const Left := Vector2(397,333)
const Right := Vector2(563,351)
const SP_COST := {"skill":2,"chain":3}
const SoundPath := "res://assets/audio/hunt-duel-lab/"
const SoundNames := {"hangyeol":"han", "uram":"uram", "saebom":"bom", "forest":"deer", "adult":"boar"}

var app: Node
var rules := Rules.new()
var arena := Control.new()
var field := Node2D.new()
var effects_layer := Node2D.new()
var a: Actor
var b: Actor
var motion: Array[String] = ["idle","idle"]
var age := [0.0,0.0]
var contact_at := [-1.0,-1.0]
var start_cast_at := -1.0
var execute_at := -1.0
var next_attack := [0.4,1.6]
var animal_attack_count := 0
var visual_clock := 0.0
var fx: Array[Dictionary] = []
var controls: Dictionary = {}
var timer: Label
var bars: Array[ProgressBar] = []
var skill_hud: SkillHUD
var skill_button: Button
var chain_button: Button
var audio_pool: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var cues: Array[String] = []
var pool_index := 0
var closing := false
var touch_pointer := -1
var touch_target: Button
var touch_buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Theme.new()
	var bold:=FontVariation.new();bold.base_font=UIFont;bold.variation_opentype={"wght":700}
	theme.default_font = bold
	var backdrop := ColorRect.new()
	backdrop.color = Color("#1d1712")
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(arena)
	arena.size = SceneSize
	arena.clip_contents = true
	arena.add_child(field)
	var ground := Sprite2D.new()
	ground.texture = Ground
	ground.position = SceneSize * .5
	ground.scale = Vector2.ONE * maxf(SceneSize.x/Ground.get_width(), SceneSize.y/Ground.get_height())
	field.add_child(ground)
	var header:=ColorRect.new();header.color=Color(.08,.10,.10,.86)
	header.mouse_filter=MOUSE_FILTER_IGNORE;header.size=Vector2(960,119);arena.add_child(header)
	field.add_child(effects_layer)
	effects_layer.z_index = 10
	effects_layer.draw.connect(_draw_effects)
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.volume_db = -9.0
		add_child(player)
		audio_pool.append(player)
	_setup_ui()
	resized.connect(_fit)
	_fit()
	reset_round()

func _fit() -> void:
	var fit := minf(size.x/SceneSize.x,size.y/SceneSize.y)
	arena.scale = Vector2.ONE * fit
	arena.position = (size - SceneSize*fit)*.5

func _label(value: String, rect: Rect2, font_size: int) -> Label:
	var item := Label.new()
	item.position = rect.position
	item.size = rect.size
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.text = value
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_shadow_color", Color.BLACK)
	item.add_theme_constant_override("shadow_offset_y", 2)
	arena.add_child(item)
	return item

func _button(value: String, rect: Rect2, pressed: Callable) -> Button:
	var item := Button.new()
	item.text = value
	item.position = rect.position
	item.size = rect.size
	item.pressed.connect(pressed)
	item.focus_mode=Control.FOCUS_NONE
	var texture=ModelTest.ROUND_RUBY if value=="↻" else ModelTest.ROUND_GOLD
	if value in ["×","↻",""]:
		for state in ["normal","hover","pressed","focus","disabled"]:
			var style:=StyleBoxTexture.new();style.texture=texture
			item.add_theme_stylebox_override(state,style)
	arena.add_child(item)
	touch_buttons.append(item)
	return item

func _setup_ui() -> void:
	_label("1대1 전투 · 실험실",Rect2(365,14,230,34),26)
	timer = _label("00:00",Rect2(808,16,84,36),23)
	_button("×",Rect2(904,16,40,38),_exit)
	_button("↻",Rect2(746,16,44,42),reset_round).tooltip_text = "같은 조합으로 다시 시작"
	var ids := ["hangyeol","uram","saebom","forest","adult"]
	for i in ids.size():
		var key: String = ids[i]
		var item := _button("",Rect2(20+58*i+(24 if i>=3 else 0),16,48,48),_select.bind(key,i>=3))
		item.icon = ModelTest.portrait(key)
		item.expand_icon = true
		item.tooltip_text = ["한결","우람","새봄","꽃사슴","큰 멧돼지"][i]
		item.toggle_mode = true
		controls[key] = item
	for i in 2:
		var bar := ProgressBar.new()
		bar.position = Vector2(270+264*i,95)
		bar.size = Vector2(156,8)
		bar.show_percentage = false
		bar.add_theme_font_size_override("font_size",1)
		bar.mouse_filter=MOUSE_FILTER_IGNORE
		for style_key in ["background","fill"]:
			var box:=StyleBoxFlat.new();box.set_corner_radius_all(4)
			box.bg_color=Color("4a5550") if style_key=="background" else Color("76ae8e" if i==0 else "bf665c")
			bar.add_theme_stylebox_override(style_key,box)
		arena.add_child(bar)
		bars.append(bar)
	_label("평타 자동",Rect2(38,462,110,38),17)
	if app != null:
		_button("받아치기",Rect2(24,503,92,25),_open_parry)
	skill_hud=SkillHUD.new()
	skill_hud.position=Vector2(447,450)
	arena.add_child(skill_hud)
	skill_hud.requested.connect(_try_player)
	skill_button=skill_hud.portrait_button
	chain_button=skill_hud.chain_button
	touch_buttons.append(chain_button)
	touch_buttons.append(skill_button)

func _open_parry() -> void:
	var owner_app:=app
	_exit()
	owner_app.call_deferred("start_parry_lab")

func _exit_tree() -> void:
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

func reset_round() -> void:
	touch_pointer=-1;touch_target=null
	rules.reset(rules.ally_id,rules.enemy_id)
	for item in audio_pool:
		item.stop()
	if a == null or b == null or a.key != rules.ally_id or b.key != rules.enemy_id:
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
		a.preview.scale = Vector2.ONE * (1.08 if a.key == "uram" else .90)
		b.preview.scale = Vector2.ONE * .92
	motion = ["idle","idle"]
	age = [0.0,0.0]
	contact_at = [-1.0,-1.0]
	start_cast_at = -1.0
	execute_at = -1.0
	visual_clock = 0.0
	next_attack = [0.4,1.6]
	animal_attack_count = 0
	fx.clear()
	a.play("idle")
	b.play("idle")
	a.preview.position = Left
	b.preview.position = Right
	field.scale = Vector2.ONE
	field.position = Vector2.ZERO
	skill_hud.reset(a.key)
	cues.clear()
	effects_layer.queue_redraw()
	_refresh()

func _refresh(delta := 0.0) -> void:
	timer.text = rules.elapsed_label()
	for i in 2:
		bars[i].max_value = rules.full_hp(i)
		bars[i].value = rules.hp[i]
	skill_hud.sync(rules.sp,rules.hp[0],rules.full_hp(0),rules.living(),motion[0]=="idle",delta)
	for key in controls:
		controls[key].set_pressed_no_signal(key in [rules.ally_id,rules.enemy_id])

func _try_player(key: String) -> void:
	if motion[0] != "idle" or not rules.spend(int(SP_COST[key])):
		return
	_act(0,key)
	_refresh() # Consume SP and hide readiness in the same input frame.

func _act(side: int, key: String) -> void:
	var actor := a if side == 0 else b
	motion[side] = key
	age[side] = 0.0
	actor.play(key)
	var duration: float = actor.duration
	contact_at[side] = duration * (.55 if key == "attack" else .63)
	if side == 0 and key != "attack":
		start_cast_at = rules.elapsed
	if side == 1 and key == "skill":
		contact_at[side] = minf(duration-.03,float(Profile.CONTACT[actor.key]))
		execute_at = float(actor.preview.length("req046_skill_anticipation"))
		_sound("warning")
		_flash(Right,"boss_gather" if b.key=="adult" else "gather",Color("#61bbff"),execute_at)
	else:
		var kind := "basic" if key == "attack" else key
		_sound(SoundNames[actor.key]+"_"+kind)
		if key != "attack":
			var ground := Left if side==0 else Right
			var name := "chain_"+actor.key if key == "chain" else "cast_"+actor.key
			_flash(ground,name,_ally_color(), duration if key == "chain" else minf(1.25,duration*.8))
	# A support cast and the shield preview have no fictitious target damage.
	if side == 0 and key == "chain" and actor.key != "hangyeol":
		contact_at[side] = -1.0
	next_attack[side] = rules.elapsed+maxf(Rules.BASIC_EVERY,duration+.26)

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

func _land(side: int, key: String) -> void:
	if not rules.living():
		return
	var defender := 1-side
	var impact_point := _position(defender)-Vector2(0,33)
	var skill := key != "attack"
	# Forward approach moves the actor to its strike distance. Check the
	# simulation positions at contact instead of firing a hit from a timer alone.
	var origin := _position(side)
	var target := _position(defender)
	var reach := 180.0 if (side==0 and a.key=="saebom") else 104.0
	if origin.distance_to(target) > reach:
		return
	if side == 1 and skill:
		_flash(_position(0),"burst",Color("#ffad26"),.40)
	if skill:
		_sound("ally_hit" if defender==0 else SoundNames[b.key]+"_hit")
	# Han is a light glint, Uram dust, Saebom stone fragments. The inbound
	# ordinary hit reads as the agreed short white glint.
	var tone := Color("#fff5df") if defender == 0 or a.key=="hangyeol" else Color("#cf9862")
	if not skill:
		_flash(impact_point,"hit",tone,.21)
	if rules.damage(defender,38 if key=="chain" else 27 if skill else 11 if side==0 else 13):
		_die(defender)
		return
	# Do not cut off a concurrently committed attack for a cosmetic reaction.
	if motion[defender] == "idle":
		_react(defender,"hit")

func _react(side: int, key: String) -> void:
	var actor := a if side==0 else b
	motion[side] = key
	age[side] = 0.0
	actor.play(key)

func _die(side: int) -> void:
	_react(side,"death")
	contact_at = [-1.0,-1.0]
	execute_at = -1.0
	_sound("ally_death" if side==0 else "enemy_death")

func _position(side: int) -> Vector2:
	var place := Left if side==0 else Right
	if motion[side] not in ["attack","skill","chain"]:
		return place
	if side==0 and a.key=="saebom":
		return place
	if side==0 and motion[side]=="chain" and a.key=="uram":
		return place
	var elapsed := float(age[side])
	var duration := a.duration if side==0 else b.duration
	var impact := float(contact_at[side])
	if impact <= 0.0:
		impact = duration*.59 if side==0 or motion[side]!="skill" else float(Profile.CONTACT[b.key])
	var windup := float(b.preview.length("req046_skill_anticipation")) if side==1 and motion[side]=="skill" else 0.0
	var p := (elapsed-windup)/maxf(.04,impact-windup) if elapsed < impact else 1.0-(elapsed-impact)/maxf(.04,duration-impact)
	var direction := Left.direction_to(Right)*(1.0 if side==0 else -1.0)
	return place + direction*78.0*smoothstep(0.05,0.96,clampf(p,0,1))

func _process(delta: float) -> void:
	if app != null and not app.application_active:
		return
	advance(delta)

func advance(delta: float) -> void:
	visual_clock += delta
	var revived := rules.advance(delta)
	if not revived.is_empty():
		reset_round()
		return
	for side in 2:
		age[side] += delta
		if side==1 and execute_at>=0.0 and float(age[side])>=execute_at:
			_sound(SoundNames[b.key]+"_skill")
			execute_at = -1.0
		var hit: float = contact_at[side]
		if hit >= 0.0 and float(age[side]) >= hit:
			_land(side,motion[side])
			contact_at[side] = -1.0
		var actor := a if side==0 else b
		if motion[side] not in ["idle","death"] and float(age[side])>=actor.duration:
			_react(side,"idle")
	if rules.living():
		if motion[0]=="idle" and rules.elapsed>=float(next_attack[0]):
			_act(0,"attack")
		if motion[1]=="idle" and rules.elapsed>=float(next_attack[1]):
			animal_attack_count += 1
			_act(1,"skill" if animal_attack_count%3==0 else "attack")
	a.preview.position = _position(0)
	b.preview.position = _position(1)
	a.sample(float(age[0]),false)
	b.sample(float(age[1]),false)
	a.place_effect()
	b.place_effect()
	var focus := 0.0
	if start_cast_at>=0.0:
		focus = sin(PI*clampf((rules.elapsed-start_cast_at)/.70,0.0,1.0))
	field.scale = Vector2.ONE*(1.0+.12*focus)
	field.position = -Left*(field.scale-Vector2.ONE)
	effects_layer.queue_redraw()
	_refresh(delta)

func _flash(center: Vector2, key: String, tint: Color, duration: float) -> void:
	fx.append({"center":center,"name":key,"color":tint,"duration":duration,"at":visual_clock})

func _draw_effects() -> void:
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
					var head := hand+Vector2(25+90*p,11+14*p)
					effects_layer.draw_line(hand,head,Color(color,alpha*.27),22.0*alpha,true)
					effects_layer.draw_line(hand,head,Color(Color.WHITE,alpha*.85),4.0*alpha,true)
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
			for j in 7:
				var dir := Vector2.from_angle(float(j)*TAU/7.0+.16)
				effects_layer.draw_line(center+dir*radius*.5,center+dir*radius,Color(color,1.0-p),3.0*(1.0-p),true)
