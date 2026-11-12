class_name UnassignedBuildingIndicator
extends Node2D
## Presentation only. Assignment, production and saved clocks remain authoritative.
const CYCLE := 5.5
const LETTER_INTERVAL := 1.1
const LETTER_LIFETIME := 2.5
const INK:=Color("ecf7ff")
var model:GameState
var key:String
var sprite:Sprite2D
var world:DemoWorld
var clock:=0.0

func _init(game:GameState,building_key:String,image:Sprite2D)->void:
	model=game;key=building_key;sprite=image
	name="UnassignedBuildingIndicator";visibility_layer=2;z_index=3
	# Nearby empty buildings breathe at different phases without random gameplay state.
	clock=float(posmod(key.hash(),997))/997.0*CYCLE

func _ready()->void:
	world=get_parent().get_parent() as DemoWorld
	refresh()

func refresh()->void:
	var found:=model.lookup_building(key)
	visible=not found.is_empty() and ResidentJobs.BUILDING_JOBS.has(found.kind) and not found.data.has("upgrade") and ResidentJobs.new(model).assigned_ids(key).is_empty()
	set_process(visible)
	if not visible or not is_instance_valid(sprite):return
	var bounds:Rect2=sprite.transform*BuildingVisuals.visible_rect(sprite)
	# The assignment bubble owns the roof center; crops/progress sit below the farm.
	position=Vector2(bounds.end.x-16,bounds.position.y+14)
	queue_redraw()

func _process(delta:float)->void:
	if not is_visible_in_tree() or (world!=null and world.simulation_paused):return
	clock=fposmod(clock+delta,CYCLE)
	queue_redraw()

func glyph_sample(index:int)->Dictionary:
	var elapsed := clock-float(index)*LETTER_INTERVAL
	var progress := clampf(elapsed/LETTER_LIFETIME,0.0,1.0)
	var alpha := smoothstep(0.0,.22,progress)*(1.0-smoothstep(.42,1.0,progress))*.9
	return {
		"position": Vector2(34.0,-10.0)*float(index)+Vector2(52.0,-15.0)*progress,
		"size": roundi(44.0+progress*28.0),
		"alpha": alpha,
	}


func _draw()->void:
	var font:=DemoArt.theme().default_font
	for index in 3:
		var glyph:=glyph_sample(index)
		if glyph.alpha<=0.0:continue
		var ink:=INK;ink.a=glyph.alpha
		draw_string(font,glyph.position,"z",HORIZONTAL_ALIGNMENT_LEFT,-1,glyph.size,ink)
