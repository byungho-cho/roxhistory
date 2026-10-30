extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		push_error(description)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var dir := "user://tests/state_%s" % Time.get_ticks_usec()
	var store := SaveStore.new(dir)
	var model := GameState.new(store)
	check(model.state.is_empty(),"Fresh installation has no continue state")
	check(not model.gather("wood_1"),"Collection before starting a game is rejected")
	check(model.start_new(),"Create new saved game")
	check(not model.build(),"Insufficient resources cannot build")
	check(not model.claim_reward(),"Cannot claim before construction")
	check(not model.gather("missing"),"Unknown resource IDs rejected")
	for n in DemoConfig.get_data().nodes:
		for i in int(n.charges):
			check(model.gather(n.id),"Collect charge %s %d" % [n.id,i])
		var before: int = model.state[n.kind]
		for i in 30:
			check(not model.gather(n.id),"Rapid repeated exhausted-node collection rejected")
		check(model.state[n.kind] == before,"No duplicate resource credit")
	check(model.can_build(),"All resources meet build cost")
	check(model.build(),"Construction succeeds")
	check(model.state.wood == 0 and model.state.stone == 0,"Construction deducts exact cost")
	for i in 30:
		check(not model.build(),"Repeated construction rejected")
	check(model.claim_reward(),"Reward claimed")
	for i in 30:
		check(not model.claim_reward(),"Repeated reward rejected")
	check(model.state.tokens == 10,"Exactly one reward")
	check(model.save_position(Vector2(1024,1110)),"Position checkpoint saves")
	var restored := GameState.new(SaveStore.new(dir))
	check(restored.state == JSON.parse_string(JSON.stringify(model.state)),"All state restored by new instance")
	var file := FileAccess.open(dir.path_join("save.json"),FileAccess.WRITE)
	file.store_string("broken write")
	file.close()
	var recovered_store := SaveStore.new(dir)
	var recovered := GameState.new(recovered_store)
	check(recovered_store.recovered and not recovered.state.is_empty(),"Corruption recovers valid backup")
	check(recovered.save_position(Vector2(1000,1050)),"Recovered save can safely checkpoint")
	check(not recovered_store._read(dir.path_join("save.backup.json")).is_empty(),"Valid backup not replaced by corrupt primary")
	for name in ["save.json","save.backup.json"]:
		file = FileAccess.open(dir.path_join(name),FileAccess.WRITE)
		file.store_string("unreadable")
		file.close()
	var locked := GameState.new(SaveStore.new(dir))
	check(locked.store.blocked,"Both corrupt files block implicit overwrite")
	check(not locked.commit(DemoConfig.fresh()),"Automatic overwrite blocked")
	check(FileAccess.get_file_as_string(dir.path_join("save.json")) == "unreadable","Corrupt original preserved")
	check(locked.start_new(),"Explicit confirmed new game can reset")
	check(not FileAccess.file_exists(dir.path_join("save.backup.json")),"New game archives previous campaign backup")
	file = FileAccess.open(dir.path_join("save.json"),FileAccess.WRITE)
	file.store_string("interrupted new save")
	file.close()
	var restarted := GameState.new(SaveStore.new(dir))
	check(restarted.state.is_empty() and restarted.store.blocked,"Corrupt new campaign cannot revive an older campaign")
	var invalid := DemoConfig.fresh()
	invalid.position = [NAN,0]
	check(not store.valid(invalid),"Non-finite position rejected")
	invalid = DemoConfig.fresh()
	invalid.wood = -1
	check(not store.valid(invalid),"Negative inventory rejected")
	invalid = DemoConfig.fresh()
	invalid.reward_claimed = true
	check(not store.valid(invalid),"Reward without construction rejected")
	var badstore := SaveStore.new(dir.path_join("unwritable"))
	var badmodel := GameState.new(badstore)
	check(badmodel.start_new(),"Failure test initial save")
	badstore.directory = dir.path_join("missing/not_created")
	var original := badmodel.state.duplicate(true)
	check(not badmodel.gather("wood_1"),"Write failure rejects collection")
	check(badmodel.state == original,"Write failure does not credit resources")
	var report := {"checks":checks,"failed":failures,"engine":Engine.get_version_info().string,"utc":Time.get_datetime_string_from_system(true)}
	DirAccess.make_dir_recursive_absolute("res://reports")
	file = FileAccess.open("res://reports/state-tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
