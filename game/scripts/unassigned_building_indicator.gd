class_name UnassignedBuildingIndicator
extends Node2D
## Presentation only. Assignment, production and saved clocks remain authoritative.
const CYCLE:=2.8
const INK:=Color("ecf7ff")
const OUTLINE:=Color("334b59")
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
	var progress:=fposmod(clock+float(index)*CYCLE/3.0,CYCLE)/CYCLE
	return {"position":Vector2(progress*30,-progress*52),"size":roundi(22+progress*14),"alpha":sin(progress*PI)*.9}

func _draw()->void:
	var font:=DemoArt.theme().default_font
	for index in 3:
		var glyph:=glyph_sample(index)
		var ink:=INK;ink.a=glyph.alpha
		var outline:=OUTLINE;outline.a=glyph.alpha*.85
		draw_string_outline(font,glyph.position,"z",HORIZONTAL_ALIGNMENT_LEFT,-1,glyph.size,4,outline)
		draw_string(font,glyph.position,"z",HORIZONTAL_ALIGNMENT_LEFT,-1,glyph.size,ink)
