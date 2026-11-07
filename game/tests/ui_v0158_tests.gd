extends SceneTree
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,title:String)->void:
	checks+=1
	if not ok:failures.append(title);push_error(title)
func frames(n:int=4)->void:
	for i in n:await process_frame;await physics_frame
func run()->void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
	app.model=GameState.new(SaveStore.new("user://v0158_ui_%s"%Time.get_ticks_usec()));app.model.state.clear()
	app.show_screen("title");await frames()
	check(app.stage.find_child("StartGame",true,false)!=null,"single start entry")
	check(app.stage.find_child("TitleSettings",true,false)!=null,"settings icon entry")
	app.start_or_continue();await frames()
	check(app.screen=="chapter","fresh game goes through chapters")
	check(app.stage.find_child("Chapter1",true,false)!=null,"chapter cards")
	check(app.stage.find_child("Chapter2",true,false).disabled,"future chapter locked")
	app.model.start_new();app.model.changed.connect(app.update_hud);app.show_screen("title");app.start_or_continue();await frames(8)
	check(app.screen=="play","existing save skips chapter")
	check(app.quest_arrow is TextureRect,"quest arrow image not glyph")
	app.toggle_quest();check(not app.quest_detail.visible,"quest collapses")
	app.toggle_quest();check(app.quest_detail.visible,"quest expands")
	app.quest_details();await frames();check(app.overlay.find_child("QuestScreen",true,false)!=null,"composed quest screen")
	check(app.overlay.find_child("TrackQuest",true,false)!=null,"quest tracking action")
	app.close_modal();check(not app.modal,"quest close")
	for level in range(1,5):
		var job:=BuildingRules.new_job("hut",level-1,100,true)
		check(is_equal_approx(job.clock_duration,BuildingRules.duration(level)/10.0),"10x level %d"%level)
	var job:=BuildingRules.new_job("hut",1,100,false)
	BuildingRules.set_clock_mode(job,250,true)
	check(is_equal_approx(job.finishes_at-250,45.0),"toggle preserves25 percent progress")
	BuildingRules.set_clock_mode(job,265,false)
	check(is_equal_approx(job.finishes_at-265,300.0),"toggle back preserves50 percent progress")
	app.queue_free();await frames()
	print("V0158 UI: %d checks, %d failures"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
