extends SceneTree
## Run: godot --headless --path game --script res://tests/approved_assets_v0151_tests.gd
## Uses only shipped catalog entries and runtime presentation helpers.
var failures:Array[String]=[]
var checks:int=0
func check(value:bool,reason:String)->void:
	checks+=1
	if not value:failures.append(reason)
func _initialize()->void:
	var result:Dictionary={"assets":[],"icons":{}}
	for kind in ["chief","hut","outpost","training","shrine","hearth"]:
		var previous_height:=0.0
		for level in range(1,5):
			var id:=BuildingVisuals.asset_id(kind,level)
			var e:=AssetCatalog.entry(id)
			check(e.get("approved",false),id+" approved")
			var source:=BuildingVisuals.texture(kind,level)
			check(source!=null,id+" real texture exists")
			if source==null:continue
			var sprite:=Sprite2D.new()
			var width:=340.0 if kind=="chief" else 230.0
			BuildingVisuals.apply(sprite,kind,level,width)
			check(is_equal_approx(sprite.scale.x,sprite.scale.y),id+" uniform scale")
			var rect:=BuildingVisuals.display_rect(kind,level,width)
			check(is_equal_approx(rect.get_center().x,0.0),id+" horizontal center")
			if kind in ["training","shrine"]:check(is_equal_approx(rect.end.y,width*.12),id+" stable bottom")
			if kind=="shrine":check(rect.size.y>previous_height,id+" progressive height")
			previous_height=rect.size.y
			result.assets.append({"kind":kind,"level":level,"id":id,"size":[rect.size.x,rect.size.y],"position":[sprite.position.x,sprite.position.y],"bottom":rect.end.y,"scale":sprite.scale.x})
			sprite.free()
	for key in ["resident","tokens"]:
		var texture:=DemoArt.icon(key)
		check(texture!=null,"icon "+key)
		if texture!=null:result.icons[key]=[texture.get_width(),texture.get_height()]
	for kind in ["training","shrine","hearth"]:
		check(DemoArt.facility_icon(kind)!=null,"facility icon "+kind)
	for level in range(1,5):
		var e:=AssetCatalog.entry("GROUND-PAD-L%d"%level)
		check(e.get("approved",false),"foundation approval")
		check(not e.has("crop"),"foundation canvas preserved")
	for action in ["move","upgrade","demolish"]:
		var texture:=AssetCatalog.texture("UI-BUILDING-MENU-"+action.to_upper()+"-DISABLED")
		var im:=texture.get_image();var alpha_max:=0.0
		for y in im.get_height():
			for x in im.get_width():alpha_max=maxf(alpha_max,im.get_pixel(x,y).a)
		check(is_equal_approx(alpha_max,89.0/255.0),action+" disabled 35% opacity")
	result["checks"]=checks;result["failures"]=failures
	DirAccess.make_dir_recursive_absolute("res://reports")
	var f:=FileAccess.open("res://reports/approved-assets-v0151-tests.json",FileAccess.WRITE)
	if f!=null:
		f.store_string(JSON.stringify(result,"  "));f.close()
	else:push_warning("Could not save optional asset report; test result is printed below.")
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
