extends SceneTree
func _initialize()->void:
	assert(VillageBounds.WORLD_RECT==Rect2(-728,-410,3856,2170))
	assert(VillageBounds.navigation_cells()==Vector2i(161,91))
	assert(VillageBounds.valid_saved_position(Vector2(2380,1330)))
	assert(VillageBounds.valid_saved_position(Vector2(-500,-200)))
	assert(not VillageBounds.valid_saved_position(Vector2(-800,0)))
	for zoom in [.56,1.0,1.6]:
		assert(VillageLayout.ground_ok(Vector2(-600,-250)))
		assert(not VillageLayout.ground_ok(Vector2(-800,0)))
	print("Expanded fixed bounds, negative save coordinates and legacy save range: PASS")
	quit()
