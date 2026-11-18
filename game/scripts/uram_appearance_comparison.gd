extends Control

const UramRig := preload("res://scripts/uram_lab_rig.gd")
const DETAILED_MODEL := "res://assets/characters/d0048/uram-appearance-60k.glb"
const LABELS := [
	"① 11,839 폴리곤 · 현재 조명",
	"② 11,839 폴리곤 · 개선 조명",
	"③ 약 6만 폴리곤 · 현재 조명",
	"④ 약 6만 폴리곤 · 개선 조명",
]
const CARD := Vector2(382,164)
const VIEW := Vector2i(432,156)

var previews: Array[UramRig] = []

func build() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var theme := StyleBoxFlat.new()
	theme.bg_color = Color("241b15")
	theme.border_color = Color("b49669")
	theme.set_border_width_all(1)
	theme.set_corner_radius_all(8)
	var natural_material: Material
	for i in LABELS.size():
		var panel := Panel.new()
		panel.name = "AppearanceOption%d" % (i+1)
		panel.position = Vector2(92+(i%2)*394,181+(i/2)*172)
		panel.size = CARD
		panel.clip_contents = true
		panel.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel",theme)
		add_child(panel)
		var caption := FigmaArt.text(panel,LABELS[i],Rect2(8,4,CARD.x-16,28),17,FigmaArt.BODY,Color("fff1d8"))
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var preview := UramRig.new()
		preview.use_retouch = true
		preview.render_size_factor = .5
		if i>=2: preview.comparison_model_path = DETAILED_MODEL
		panel.add_child(preview)
		var body := preview.skeleton.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
		if i==0: natural_material = body.get_active_material(0)
		body.set_surface_override_material(0,natural_material)
		preview.viewport.size = VIEW
		preview.camera.position = Vector3(0,3.6,6)
		preview.camera.look_at(Vector3(0,.99,0))
		preview.camera.size = 2.12
		preview.pivot.rotation.y = deg_to_rad(29.0)
		preview.display.scale = Vector2.ONE*(126.0/VIEW.y)
		preview.display.position = Vector2((CARD.x-VIEW.x*preview.display.scale.x)*.5,33)
		preview.show_pose("idle",0.0)
		if i%2==1: improve_light(preview)
		preview.set_enabled(true)
		preview.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		previews.append(preview)

func improve_light(preview: UramRig) -> void:
	var scene := preview.camera.get_parent()
	var environment := scene.find_children("*","WorldEnvironment",false,false)[0] as WorldEnvironment
	environment.environment.ambient_light_color = Color("eff2ff")
	environment.environment.ambient_light_energy = .61
	var lights := scene.find_children("*","DirectionalLight3D",false,false)
	var key := lights[0] as DirectionalLight3D
	key.rotation_degrees = Vector3(-42,-22,0)
	key.light_color = Color("fff4e5")
	key.light_energy = .92
	var fill := lights[1] as DirectionalLight3D
	fill.rotation_degrees = Vector3(-18,39,0)
	fill.light_color = Color("e6ecff")
	fill.light_energy = .38
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-34,158,0)
	rim.light_color = Color("fff1d7")
	rim.light_energy = .35
	scene.add_child(rim)
