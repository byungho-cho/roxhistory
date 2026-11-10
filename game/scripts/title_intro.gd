extends Control
# The approved MP4 is archived outside game/. Godot's stock runtime plays Theora.
const VIDEO_PATH := "res://assets/video/history_intro_15s_v0.2.94_20261111.ogv"
var app: Node
var player: VideoStreamPlayer
var skip: Button
var elapsed := 0.0
var completed := false
var active := true

func _ready() -> void:
	name = "TitleIntro"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player = VideoStreamPlayer.new()
	player.name = "IntroVideo"
	player.expand = true
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player)
	player.finished.connect(finish)
	skip = app.button(self,"화면을 터치하여 스킵",finish)
	skip.name = "SkipIntro"
	skip.custom_minimum_size = Vector2.ZERO
	for state in ["normal","hover","pressed","focus"]:
		skip.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	skip.add_theme_font_size_override("font_size",24)
	skip.add_theme_color_override("font_color",Color("fff0d0"))
	skip.add_theme_color_override("font_outline_color",Color("49321e"))
	skip.add_theme_constant_override("outline_size",3)
	resized.connect(layout)
	layout()
	if not ResourceLoader.exists(VIDEO_PATH):
		push_warning("Title intro unavailable; continuing the game.")
		call_deferred("finish")
		return
	player.stream = load(VIDEO_PATH) as VideoStream
	if player.stream == null:
		call_deferred("finish")
		return
	player.play()
	set_active(app.application_active)

func layout() -> void:
	if not is_instance_valid(player):return
	var fitted := Vector2(854,480) * minf(size.x/854.0,size.y/480.0)
	player.position = (size-fitted)*.5
	player.size = fitted
	var safe_bottom := 18.0
	if OS.has_feature("android"):
		var area := DisplayServer.get_display_safe_area()
		var physical := DisplayServer.screen_get_size()
		if physical.y > 0:
			safe_bottom=maxf(18,maxf(area.position.y,physical.y-area.end.y)*size.y/physical.y)
	var rect: Rect2 = app.title_prompt_rect(size,safe_bottom)
	skip.position = rect.position
	skip.size = rect.size

func _process(delta: float) -> void:
	if not active or completed:return
	elapsed += delta
	# Failsafe for decoder/start failures; paused background time does not count.
	if elapsed >= 20.0:finish()

func set_active(value: bool) -> void:
	active = value
	if is_instance_valid(player):player.paused = not value

func stop() -> void:
	completed = true
	if is_instance_valid(player):player.stop()

func finish() -> void:
	if completed or app.screen != "intro":return
	stop()
	app.finish_title_intro()
