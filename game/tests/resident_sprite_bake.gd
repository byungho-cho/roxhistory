extends SceneTree
## Offline baker. Run with the graphical Godot editor binary, not --headless.

const FRAME_SIZE:=Vector2i(96,120)
const DIRECTIONS:=4
const STATES:=[
	["idle",2,""],["walk",6,""],["wood",4,""],["stone",4,""],
	["walk",6,"wood"],["walk",6,"stone"],["walk",6,"grain"],
]

func _initialize()->void:
	call_deferred("bake")

func bake()->void:
	var source:=HybridCharacter.new()
	source.model_path="res://assets/characters/residents/sturdy_male.glb"
	source.render_size_factor=.5
	root.add_child(source)
	source.set_enabled(true)
	source.ambient_allowed=false
	var cargo:=ResidentLoadVisual.new()
	cargo.bone_name="spine"
	source.rig.add_child(cargo)
	var atlas:=Image.create_empty(FRAME_SIZE.x*DIRECTIONS,FRAME_SIZE.y*34,false,Image.FORMAT_RGBA8)
	var row:=0
	for state:Array in STATES:
		var action:String=state[0]
		var frames:int=state[1]
		cargo.update_load({"kind":state[2]})
		for facing in DIRECTIONS:
			var heading:=TAU*facing/DIRECTIONS
			var movement:=Vector2(sin(heading),cos(heading))
			source.heading=heading
			source.target_heading=heading
			for frame in frames:
				var fraction:=float(frame)/frames
				var working:=action in ["wood","stone"]
				source.clock=fraction*1.2
				source.work_kind=action
				source.walk_blend=1.0 if action=="walk" else 0.0
				source.action_blend=1.0 if working else 0.0
				source.animate(0.0,movement,fraction*TAU,action=="walk",action if working else "",fraction*1.2,false)
				await process_frame
				await RenderingServer.frame_post_draw
				var pose:=source.viewport.get_texture().get_image()
				pose.convert(Image.FORMAT_RGBA8)
				pose.resize(FRAME_SIZE.x,FRAME_SIZE.y,Image.INTERPOLATE_LANCZOS)
				atlas.blit_rect(pose,Rect2i(Vector2i.ZERO,FRAME_SIZE),Vector2i(facing,row+frame)*FRAME_SIZE)
		row+=frames
	var error:=atlas.save_png("res://assets/characters/residents/sturdy-male-trial-atlas.png")
	print("Resident sprite atlas rows: ",row,"; status: ",error)
	quit(error)
