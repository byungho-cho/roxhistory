extends SceneTree
var frame:=0
func _initialize()->void:root.unfocusable=true;root.content_scale_size=Vector2i(1280,720);call_deferred("setup")
func setup()->void:
	var background:=ColorRect.new();background.color=Color("67734b");background.size=Vector2(1280,720);root.add_child(background)
	for row in 3:
		for stage in range(1,5):
			var kind:String=["hearth","shrine","training"][row]
			var body:=Node2D.new();body.position=Vector2(160+(stage-1)*320,160+row*220);root.add_child(body)
			var sprite:=Sprite2D.new();body.add_child(sprite);BuildingVisuals.apply(sprite,kind,stage,300)
			body.add_child(BuildingLifeEffects.new(sprite,kind,stage))
			if kind=="hearth":
				var flame:=ShaderMaterial.new();flame.shader=preload("res://shaders/hearth_flame.gdshader");flame.set_shader_parameter("strength",.55+stage*.15);sprite.material=flame
			var label:=Label.new();label.theme=DemoArt.theme();label.text="%s %d단계"%[BuildingWorkflow.building_name(kind),stage];label.position=Vector2(body.position.x-65,body.position.y+60);root.add_child(label)
	process_frame.connect(step)
func step()->void:
	frame+=1
	if frame in [30,150]:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/v056-effects-%d.png"%frame)
	if frame>=180:quit()

