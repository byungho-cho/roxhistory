extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize()->void:
	call_deferred("run")
func run()->void:
	check(BrushRoadNetwork.assets_available(),"all 16 assets imported")
	for mask in 16:
		var graph:Dictionary={Vector2i.ZERO:true}
		for i in 4:
			if mask&(1<<i):graph[BrushRoadNetwork.DIRECTIONS[i]]=true
		check(BrushRoadNetwork.neighbor_masks(graph)[Vector2i.ZERO]==mask,"mask %d"%mask)
	var buildings:Array=[{"cell":VillageLayout.CHIEF,"span":6}]
	for at in VillageLayout.PLOTS:buildings.append({"cell":at,"span":4})
	var result:=BrushRoadNetwork.plan(buildings)
	check(result.ok,"default village routable")
	if result.ok:
		check(result.masks==BrushRoadNetwork.plan(buildings).masks,"deterministic rebuild")
		for at in result.masks:
			check(BrushRoadNetwork.walkable(at,buildings),"clear footprint %s"%at)
			for i in 4:
				var neighbor:Vector2i=at+BrushRoadNetwork.DIRECTIONS[i]
				var connected:bool=bool(int(result.masks[at])&(1<<i))
				check(connected==result.masks.has(neighbor),"reciprocal graph")
				if connected:check(bool(int(result.masks[neighbor])&(1<<((i+2)%4))),"opposite port")
		var art:=BrushRoadNetwork.new(result.masks)
		root.add_child(art)
		check(art.get_child_count()==result.masks.size(),"one sprite per cell incl junction")
		for tile in art.get_children():
			check(tile.scale==Vector2(.25,.25),"contract scale")
			check(tile.texture.get_size()==Vector2(520,264),"contract dimensions")
		art.free()
	var moved:Array=[{"cell":Vector2(-5.25,-4.75),"span":6},{"cell":Vector2(6.3,3.7),"span":4},{"cell":Vector2(-8.2,6.4),"span":4}]
	var moved_result:=BrushRoadNetwork.plan(moved)
	check(moved_result.ok,"fractional saved placements")
	if moved_result.ok:
		for at in moved_result.masks:check(BrushRoadNetwork.walkable(at,moved),"moved footprint clear")
	var blocked:Array=[{"cell":Vector2.ZERO,"span":100},{"cell":Vector2(4,4),"span":4}]
	check(not BrushRoadNetwork.plan(blocked).ok,"impossible routing requests full fallback")
	check(BrushRoadNetwork.plan([]).masks.is_empty(),"empty map no roads")
	check(BrushRoadNetwork.plan([buildings[0]]).masks.is_empty(),"chief only no road")
	ProjectSettings.set_setting("roxhistory/visuals/brush_roads",false)
	check(not BrushRoadNetwork.enabled(),"legacy setting")
	ProjectSettings.set_setting("roxhistory/visuals/brush_roads",true)
	check(BrushRoadNetwork.enabled(),"default brush mode")
	print("Brush road checks: %d, failures: %d"%[checks,failures])
	quit(1 if failures else 0)
