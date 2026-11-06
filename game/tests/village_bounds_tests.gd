extends SceneTree
func _initialize()->void:
	assert(VillageBounds.WORLD_SIZE==Vector2(2400,1350))
	assert(VillageBounds.navigation_cells()==Vector2i(100,56))
	assert(VillageLayout.PLAYABLE==VillageBounds.PLAYABLE)
	assert(DemoPlayer.WORLD_SIZE==VillageBounds.WORLD_SIZE)
	assert(VillageBounds.valid_saved_position(Vector2(2380,1330)))
	assert(not VillageBounds.valid_saved_position(Vector2(2380.01,1330)))
	var reference:=PackedVector2Array([Vector2(-100,-50),Vector2(100,-50),Vector2(100,50),Vector2(-100,50)])
	var fixed:=VillageBounds.inset_reference_polygon(reference,Vector2.ZERO)
	assert(fixed==PackedVector2Array([Vector2(-90,-45),Vector2(90,-45),Vector2(90,45),Vector2(-90,45)]))
	for zoom in [.56,1.0,1.6]:
		var projected:=Transform2D(0,Vector2.ONE*zoom,0,Vector2(32,12))*fixed
		assert(projected.size()==fixed.size())
		assert(VillageBounds.inset_reference_polygon(reference,Vector2.ZERO)==fixed)
	print("Village bounds: legacy dimensions/save endpoints preserved; 90 percent planning polygon independent of zoom: PASS")
	quit()
