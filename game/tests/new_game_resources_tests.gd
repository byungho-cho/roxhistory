extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func _initialize()->void:
	var store:=SaveStore.new("user://new_resources_%s"%Time.get_ticks_usec())
	var model:=GameState.new(store)
	check(model.state.is_empty(),"No implicit new game on load")
	check(model.start_new(),"Explicit new game created")
	check(model.state.wood==500 and model.state.stone==500,"Fresh game has 500 wood and stone")
	check(model.build(Vector2.ZERO,0),"Fresh test resources support normal building")
	var old:=model.state.duplicate(true);old.wood=73;old.stone=29;model.commit(old)
	var before:Dictionary=JSON.parse_string(JSON.stringify(model.state))
	var restored:=GameState.new(store)
	check(restored.state.wood==73 and restored.state.stone==29,"Continue does not grant resources again")
	check(JSON.parse_string(JSON.stringify(restored.state))==before,"Existing buildings progress rewards and inventory preserved")
	var zero:=restored.state.duplicate(true);zero.wood=0;zero.stone=0;restored.commit(zero)
	check(GameState.new(store).state.wood==0,"Existing zero-resource save is not treated as new")
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
