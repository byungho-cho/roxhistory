extends SceneTree
## Real Main and GUI paths, with a bounded one-resource fake for repeatable faults only.
const Preloader := preload("res://scripts/hunt_resource_preload.gd")
const Model := preload("res://scripts/model_motion_profile.gd")
const FOREST: String = Model.ANIMAL_MODELS["forest"]
const STAG: String = Model.ANIMAL_MODELS["stag"]
const JUVENILE: String = Model.ANIMAL_MODELS["juvenile"]
const ADULT: String = Model.ANIMAL_MODELS["adult"]
class Controlled extends "res://scripts/hunt_resource_preload.gd":
	var target := ""
	var mode := "hold"
	var requests := 0
	var collected_failures := 0
	func _cached(path: String) -> Resource:
		return null if path == target else super._cached(path)
	func _request(path: String) -> Error:
		if path != target:return super._request(path)
		requests += 1
		return OK
	func _status(path: String) -> int:
		if path != target:return super._status(path)
		if mode == "hold":return ResourceLoader.THREAD_LOAD_IN_PROGRESS
		if mode == "fail":return ResourceLoader.THREAD_LOAD_FAILED
		return ResourceLoader.THREAD_LOAD_LOADED
	func _collect(path: String) -> Resource:
		if path != target:return super._collect(path)
		if mode == "fail":
			collected_failures += 1
			return null
		return ResourceLoader.load(path)

var app
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func ck(ok: bool, desc: String) -> void:
	checks += 1
	if not ok:failures += 1
	print(("PASS " if ok else "FAIL ")+desc)

func frames(n: int) -> void:
	for i in n: await process_frame

func touch(at: Vector2, down: bool, finger := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = finger
	e.position = at
	e.pressed = down
	root.push_input(e,true)

func press(at: Vector2, finger := 0) -> void:
	touch(at,true,finger)
	touch(at,false,finger)

func button_pos(name: String) -> Vector2:
	var b := app.stage.find_child(name,true,false) as Control
	return b.get_global_rect().get_center() if b else Vector2.INF

func selector() -> Node:
	return app.stage.find_child("HuntStageSelection",true,false)

func open_selector(initial: int) -> Node:
	app.hunt_stage = initial
	app.show_screen("hunt_select")
	await frames(2)
	return selector()

func finish_intro(current: Node) -> void:
	if not current.entry_finished:
		press(root.get_visible_rect().get_center())
		await frames(1)

func wait_for_prep() -> Node:
	var until := Time.get_ticks_msec()+12000
	while app.hunt_preparing and Time.get_ticks_msec()<until:
		await process_frame
		OS.delay_usec(900)
	return app.hunt if app.screen=="hunt" else null

func includes_all(list: PackedStringArray, paths: Array) -> bool:
	return paths.all(func(path): return list.has(path))

func unique(list: PackedStringArray) -> bool:
	var seen := {}
	for path in list:
		if seen.has(path):return false
		seen[path] = true
	return true

func pending_any(list: PackedStringArray) -> bool:
	for path in list:
		if app.hunt_preloader.state(path)==Preloader.State.PENDING:return true
	return false

func run() -> void:
	var safe := OS.get_environment("APPDATA").replace("\\","/").to_lower()
	if not safe.contains("hunt-preload-qa") or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(safe+"/"):
		quit(90)
		return
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if not app.model.start_new({},true):quit(91);return
	await app.enter_game()
	await frames(30)
	# Earliest real 1-1 entry in a fresh process, while threaded assets may still be cold.
	var start_ms := Time.get_ticks_msec()
	var s := await open_selector(0)
	var prep_paths:PackedStringArray = app.hunt_preparation_paths(0)
	ck(not s.entry_finished and app.hunt_preloader.wanted.has(FOREST),"selector constructor queued actual resources while entry animation is still running")
	ck(includes_all(prep_paths,app.HUNT_PREP_MODELS) and prep_paths.has(FOREST) and not prep_paths.has(ADULT) and not prep_paths.has(JUVENILE),"cold 1-1 queues real shared rigs and only its actual prey")
	ck(unique(prep_paths) and Array(prep_paths).all(func(path):return not path.contains("success") and not path.contains("failure") and not path.contains("meshy6k")),"first-open manifest deduplicates and excludes result media or generic models")
	await finish_intro(s)
	var possible_wait := pending_any(prep_paths)
	var tap_ms := Time.get_ticks_msec()
	press(button_pos("PrepareHunt"))
	var actual := await wait_for_prep()
	ck(is_instance_valid(actual) and actual.preparation.visible and not actual.running,"cold animation skip then immediate real touch opens the correct preparation, not VS")
	ck(app.hunt_loading==null,"cold transition leaves no obsolete loading layer")
	print("MEASURE cold_selector_to_prep_ms=",Time.get_ticks_msec()-start_ms," cold_click_to_prep_ms=",Time.get_ticks_msec()-tap_ms," pending_before_click=",possible_wait)

	# Real normal animation, warm repeat (no simulated loader). First tap transitions synchronously.
	s = await open_selector(0)
	var warm_deadline := Time.get_ticks_msec()+12000
	while not s.entry_finished and Time.get_ticks_msec()<warm_deadline:
		await process_frame
		OS.delay_usec(1000)
	ck(s.entry_finished,"normal entry animation can finish without being touched")
	ck(not pending_any(prep_paths),"normal repeat uses retained finished handles")
	tap_ms = Time.get_ticks_msec()
	press(button_pos("PrepareHunt"))
	ck(app.screen=="hunt" and app.hunt_loading==null and not app.hunt_preparing,"already-ready click enters the scene immediately without a loading frame")
	print("MEASURE warm_click_return_ms=",Time.get_ticks_msec()-tap_ms)

	# Select an actual different, unlocked roster; dedup duplicated stag/forest.
	app.model.state.hunt_cleared=3
	s = await open_selector(0)
	await finish_intro(s)
	press(button_pos("HuntStage2"))
	ck(app.hunt_stage==2 and app.hunt_preloader.wanted.has(STAG) and app.hunt_preloader.wanted.has(FOREST) and not app.hunt_preloader.wanted.has(JUVENILE),"touching unlocked 1-3 warms only that catalog prey pair")
	prep_paths = app.hunt_preparation_paths(1)
	ck(app.hunt_preparation_paths(2).count(STAG)==1 and prep_paths.count(FOREST)==1,"repeated prey appearances still request each actual resource once")
	press(button_pos("PrepareHunt"))
	actual = await wait_for_prep()
	ck(is_instance_valid(actual) and actual.chapter_story_number==3 and actual.chapter_prep_foes.size()==2 and actual.chapter_prep_foes[0].native_species=="stag" and actual.chapter_prep_foes[1].native_species=="forest","selected stage builds its exact native roster")

	# Repeatably slow resource: intro skip and repeated press must await one request and not double-enter.
	var fake := Controlled.new()
	fake.target = FOREST
	app.hunt_preloader = fake
	s = await open_selector(0)
	ck(fake.requests==1,"one request queued for actual prey before the opening animation ends")
	await finish_intro(s)
	var prepare_at := button_pos("PrepareHunt")
	press(prepare_at)
	press(prepare_at,1)
	ck(app.screen=="hunt_select" and app.hunt_preparing and is_instance_valid(app.hunt_loading) and fake.requests==1,"fast touch after skip waits on the same screen; duplicate touch does not restart loader")
	fake.mode = "ready"
	actual = await wait_for_prep()
	ck(is_instance_valid(actual) and actual.stage_one_one and fake.requests==1 and app.hunt_loading==null,"one cold request completes and enters once")

	# Old selection invalidated mid-wait; no stale navigation or pinned off-stage pack after completion.
	fake = Controlled.new()
	fake.target = STAG
	app.hunt_preloader = fake
	s = await open_selector(2)
	await finish_intro(s)
	press(button_pos("PrepareHunt"))
	ck(app.hunt_preparing,"stage-change check begins with a real pending request")
	s.choose(0) # A selection update from another input path while the earlier request is still in flight.
	await frames(3)
	ck(app.screen=="hunt_select" and app.hunt_stage==0 and not app.hunt_preparing and app.hunt_loading==null,"superseded request cannot enter the old stage")
	fake.mode = "ready"
	await frames(3)
	ck(not fake.held.has(STAG) and not fake.in_flight.has(STAG),"obsolete stage task is drained without holding its resource")
	press(button_pos("PrepareHunt"))
	actual = await wait_for_prep()
	ck(is_instance_valid(actual) and actual.stage_one_one,"new choice prepares correctly after stale request is rejected")

	# Terminal resource failure has one retry, then a friendly same-screen error and usable Back.
	fake = Controlled.new()
	fake.target = FOREST
	app.hunt_preloader = fake
	s = await open_selector(0)
	await finish_intro(s)
	press(button_pos("PrepareHunt"))
	fake.mode = "fail"
	await frames(8)
	ck(fake.requests==2 and fake.collected_failures==2 and not app.hunt_preparing,"failed resource is drained and retried only once this attempt")
	ck(app.screen=="hunt_select" and app.hunt_loading==null and app.toast_time>0.0,"hard failure keeps the selector usable with a friendly retry message")
	fake.mode = "ready"
	press(button_pos("PrepareHunt"))
	actual = await wait_for_prep()
	ck(is_instance_valid(actual) and actual.stage_one_one and fake.requests==3,"a later explicit retry can finish successfully")
	# An engine lifecycle pause is separate from dismissing the selector animation.
	fake = Controlled.new()
	fake.target = FOREST
	app.hunt_preloader = fake
	s = await open_selector(0)
	await finish_intro(s)
	press(button_pos("PrepareHunt"))
	app.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	fake.mode = "ready"
	await frames(8)
	ck(app.screen=="hunt_select" and app.hunt_preparing and not app.application_active,"background completion never navigates while the app is inactive")
	app.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	actual = await wait_for_prep()
	ck(is_instance_valid(actual) and app.application_active and app.hunt_loading==null,"same still-current preparation opens only after application resumes")

	# Physical Back while pending must cancel navigation, not block the next attempt.
	fake = Controlled.new()
	fake.target = FOREST
	app.hunt_preloader = fake
	s = await open_selector(0)
	await finish_intro(s)
	press(button_pos("PrepareHunt"))
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	fake.mode = "ready"
	await frames(8)
	ck(not app.hunt_preparing and app.screen=="hunt_select" and app.hunt_loading==null,"Back cancels a pending preparation without exiting or re-opening")

	if "--watchdog" in OS.get_cmdline_user_args():
		fake = Controlled.new()
		fake.target = FOREST
		app.hunt_preloader = fake
		s = await open_selector(0)
		await finish_intro(s)
		press(button_pos("PrepareHunt"))
		var watchdog_start:=Time.get_ticks_msec()
		actual = await wait_for_prep()
		var timed_out_ms:=Time.get_ticks_msec()-watchdog_start
		ck(actual==null and app.screen=="hunt_select" and not app.hunt_preparing and app.hunt_loading==null and timed_out_ms>=9500 and timed_out_ms<12000,"stalled worker is bounded by the current-screen watchdog")
		fake.mode = "ready"
		await frames(8)

	app.queue_free()
	await frames(7)
	print("RESULT ",checks-failures,"/",checks)
	quit(failures)
