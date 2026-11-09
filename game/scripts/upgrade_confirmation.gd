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
	name="UpgradeConfirmation";size=Vector2(420,65);mouse_filter=Control.MOUSE_FILTER_IGNORE
	cost_display=BuildCostDisplay.new();add_child(cost_display);cost_display.update_cost(cost)
	cost_display.confirm_button.name="ConfirmUpgrade";cost_display.confirm_button.pressed.connect(confirm)
	cost_display.cancel_button.name="CancelUpgrade";cost_display.cancel_button.pressed.connect(app.close_modal)
func _process(_delta:float)->void:
	if not is_instance_valid(app.world):return
	var sprite:Sprite2D=app.world.building_sprite(key)
	if not is_instance_valid(sprite):app.close_modal();return
	var bounds:Rect2=sprite.get_global_transform_with_canvas()*BuildingVisuals.visible_rect(sprite)
	var viewport:=Rect2(Vector2.ZERO,Vector2(app.w,app.h))
	if not bounds.intersects(viewport.grow(4)):app.close_modal();return
	cost_display.set_world_scale(app.world.get_global_transform_with_canvas().get_scale().x)
	var extent:=cost_display.screen_extent
	position=Vector2(clampf(bounds.get_center().x-extent.x*.5,app.safe.x,maxf(app.safe.x,app.w-app.safe.x-extent.x)),maxf(app.safe.y,bounds.position.y-extent.y-8))
