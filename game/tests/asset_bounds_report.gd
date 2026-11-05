extends SceneTree
func _initialize()->void:
	var result:Dictionary={}
	for file in DirAccess.get_files_at("res://assets/refactor-v035"):
		if not file.ends_with(".png"):continue
		var im:=Image.load_from_file("res://assets/refactor-v035/"+file)
		var lo:=Vector2i(im.get_width(),im.get_height());var hi:=Vector2i.ZERO
		for y in range(0,im.get_height(),2):
			for x in range(0,im.get_width(),2):
				if im.get_pixel(x,y).a>.5:lo=lo.min(Vector2i(x,y));hi=hi.max(Vector2i(x,y))
		result[file]={"size":[im.get_width(),im.get_height()],"alpha_bounds":[lo.x,lo.y,hi.x-lo.x+2,hi.y-lo.y+2]}
	print(JSON.stringify(result));quit()
