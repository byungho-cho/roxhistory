class_name UpgradeConfirmation
extends Control
## S40100 1427:6916. Background dismissal is retained by BuildingWorkflow.
var app:Node
var key:String
var cost:Dictionary
var confirm:Callable
var cost_display:BuildCostDisplay
func _init(owner_app:Node,building_key:String,price:Dictionary,callback:Callable)->void:
	app=owner_app;key=building_key;cost=price;confirm=callback
func _ready()->void:
	name="UpgradeConfirmation";size=Vector2(380,65);mouse_filter=Control.MOUSE_FILTER_STOP
	cost_display=BuildCostDisplay.new();add_child(cost_display);cost_display.update_cost(cost)
	cost_display.confirm_button.name="ConfirmUpgrade";cost_display.confirm_button.pressed.connect(confirm)
func _process(_delta:float)->void:
	if not is_instance_valid(app.world):return
	var sprite:Sprite2D=app.world.building_sprite(key)
	if not is_instance_valid(sprite):app.close_modal();return
	var bounds:Rect2=sprite.get_global_transform_with_canvas()*sprite.get_rect()
	var available:float=app.w-app.safe.x*2
	var factor:=minf(1.0,available/380.0);scale=Vector2.ONE*factor
	position=Vector2(clampf(bounds.get_center().x-190*factor,app.safe.x,maxf(app.safe.x,app.w-app.safe.x-380*factor)),clampf(bounds.position.y-65*factor,app.safe.y+85,maxf(app.safe.y+85,app.h-app.safe.y-65*factor)))
