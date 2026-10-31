extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var hero:=HybridCharacter.new();root.add_child(hero)
	await process_frame
	hero.tool_3d.visible=false
	var document:=GLTFDocument.new()
	var state:=GLTFState.new()
	var result:=document.append_from_scene(hero.pivot,state)
	if result!=OK:
		push_error("GLB scene export failed: %s"%result);quit(1);return
	result=document.write_to_filesystem(state,"res://c001-study.glb")
	print("STUDY_GLB_EXPORT_RESULT=",result)
	quit(0 if result==OK else 1)
