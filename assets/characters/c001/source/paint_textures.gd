extends SceneTree
# Reproducible UV material painting source, no external texture licensing.
func _initialize():
	DirAccess.make_dir_recursive_absolute("res://textures")
	var source:=FileAccess.get_file_as_string("res://hybrid_character.gd")
	var regex:=RegEx.new();regex.compile('material\\("([a-f0-9]{6})"\\)')
	var noise:=FastNoiseLite.new();noise.seed=19611;noise.frequency=.034
	var painted:={}
	for match in regex.search_all(source):
		var hex:=match.get_string(1)
		if painted.has(hex):continue
		painted[hex]=true
		var base:=Color(hex);var im:=Image.create(256,256,false,Image.FORMAT_RGB8)
		var hair:=hex in ["57301f","754328","965c36"]
		for y in 256:
			for x in 256:
				var grain:=noise.get_noise_2d(x,y)*(.018 if hex=="f3b589" else .06)
				var stroke:=sin(x*.22+sin(y*.015)*1.8)*.07 if hair else sin(x*.15+y*.09)*(.004 if hex=="f3b589" else .018)
				var wash:=sin(float(y)/255*PI)*.055-.025
				var tint:=base*(1+grain+stroke+wash)
				tint.a=1;im.set_pixel(x,y,tint)
		im.save_png("res://textures/"+hex+".png")
	print("Painted material textures: ",painted.size());quit()
