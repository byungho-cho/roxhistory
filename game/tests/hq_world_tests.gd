extends SceneTree
func _initialize()->void:
	for level in range(1,5):
		var rect:=VillageBounds.rect_for_level(level)
		assert(rect.get_center().is_equal_approx(VillageBounds.WORLD_RECT.get_center()))
		assert(is_equal_approx(rect.size.x/VillageBounds.WORLD_SIZE.x,(.5+.1*level)/.9))
		for seed_value in range(50):
			var points:=ResourcePlacement.generate(seed_value,level,20)
			assert(points.size()==20)
			assert(points==ResourcePlacement.generate(seed_value,level,20))
			var occupied:Array=[]
			for point in points:
				assert(ResourcePlacement.clear(point,level,occupied))
				occupied.append(point)
	assert(VillageBounds.rect_for_level(4).is_equal_approx(VillageBounds.WORLD_RECT))
	print("HQ world bounds and 4,000 seeded placements clear of reserved geometry: PASS")
	quit()
