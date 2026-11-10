extends SceneTree
const ASSETS := "assets/characters/residents/"
const PREFIX := "res://"
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var atlas := args[0]
	var output := args[1]
	for id in ["T0","T1","T2","T3"]:
		var pack := PCKPacker.new()
		if pack.pck_start(output.path_join("Roxhistory_%s_0.2.91.pck"%id)) != OK: quit(1);return
		var marker := output.path_join(id+".txt")
		var file := FileAccess.open(marker,FileAccess.WRITE)
		file.store_string(id)
		file.close()
		if pack.add_file("res://performance/active-mode.txt",marker) != OK: quit(2);return
		var sprites := ["sturdy-male"] if id=="T1" else ["sturdy-male","female"] if id=="T2" else []
		for sprite in sprites:
			var remap := ASSETS+str(sprite)+"-trial-atlas.png.import"
			var physical := atlas.path_join(remap)
			var config := ConfigFile.new()
			if config.load(physical) != OK: quit(3);return
			var texture := str(config.get_value("remap","path"))
			if pack.add_file(PREFIX+remap,physical)!=OK or pack.add_file(texture,atlas.path_join(texture.trim_prefix(PREFIX)))!=OK:
				quit(4);return
		if pack.flush()!=OK: quit(5);return
	quit()

