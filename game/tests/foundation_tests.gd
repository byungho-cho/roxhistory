extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var store:=SaveStore.new("user://foundations_%s"%Time.get_ticks_usec());var model:=GameState.new(store);model.start_new()
	var state:Dictionary=model.state.duplicate(true);state.wood=300;state.stone=300;model.commit(state)
	for id in [0,1,2]:model.build(Vector2.ZERO,id)
	model.build_outpost(Vector2.ZERO,3)
	var layout:=VillageLayout.new(model);root.add_child(layout)
	for level in [1,2,3,4]:
		state=model.state.duplicate(true);state.chief_level=level;model.commit(state)
		var before:=model.state.duplicate(true);var count:=0
		for child in layout.get_children():
			if not child.has_meta("foundation_level"):continue
			count+=1
			var cell:Vector2=child.get_meta("foundation_cell");var span:int=child.get_meta("foundation_span");var target:int=level if cell==VillageLayout.CHIEF else 1
			check(child.get_meta("foundation_level")==target,"Saved chief level or default L1 mapped correctly")
			check(child.texture==AssetCatalog.texture("GROUND-PAD-L%d"%target),"Exact approved image used")
			check(child.position==VillageLayout.project(cell)+Vector2(0,span*6),"Previous ground anchor preserved")
			var bounds:Array=AssetCatalog.entry("GROUND-PAD-L%d"%target).alpha_bounds
			check((Vector2(bounds[2],bounds[3])*child.scale).is_equal_approx(Vector2(span*64.0,span*64.0*676/1088*.81)),"Old visible ground extent preserved")
			check(child.get_child_count()==0,"Foundation adds no collision or gameplay nodes")
		check(count==5,"Chief three huts and outpost each have one foundation")
		check(model.state==before,"Rendering does not mutate save")
	var restored:=GameState.new(store);check(restored.chief_level()==4 and restored.outposts().size()==1,"Level mapping restored from existing save data")
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
