class_name HearthParticles
extends Node2D
## Independent soft flame/ember emitters; the approved base PNG never warps.
var flames:CPUParticles2D
var core:CPUParticles2D
var embers:CPUParticles2D
var tier:=0
static func soft_texture()->GradientTexture2D:
	var texture:=GradientTexture2D.new();texture.width=32;texture.height=32
	texture.fill=GradientTexture2D.FILL_RADIAL;texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(1,.5)
	var gradient:=Gradient.new();gradient.set_color(0,Color.WHITE);gradient.set_color(1,Color(1,1,1,0));gradient.add_point(.42,Color(1,1,1,.65));texture.gradient=gradient
	return texture
func _ready()->void:
	name="IndependentFireParticles";visibility_layer=2
	flames=emitter("Flames",26,.65,Vector2(7,2),18,37,5,11,[Color(1,.17,.015,0),Color(1,.3,.025,.7),Color(1,.65,.10,.8),Color(1,.2,.01,0)])
	core=emitter("FlameCore",16,.42,Vector2(4,1),14,26,3,6,[Color(1,.9,.35,0),Color(1,.95,.55,.85),Color(1,.55,.04,.6),Color(1,.3,.01,0)])
	embers=emitter("Embers",9,1.2,Vector2(5,2),24,48,.7,1.5,[Color(1,.8,.2,0),Color(1,.8,.3,.85),Color(1,.25,.025,.6),Color(1,.15,.01,0)])
	embers.spread=24;embers.gravity=Vector2(3,-6)
func emitter(id:String,count:int,life:float,extent:Vector2,slow:float,fast:float,small:float,large:float,colors:Array)->CPUParticles2D:
	var node:=CPUParticles2D.new();node.name=id;node.visibility_layer=2
	node.amount=count;node.lifetime=life;node.preprocess=life;node.local_coords=true
	node.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE;node.emission_rect_extents=extent
	node.direction=Vector2.UP;node.spread=16;node.gravity=Vector2(0,-12)
	node.initial_velocity_min=slow;node.initial_velocity_max=fast
	node.texture=soft_texture();node.scale_amount_min=small/32;node.scale_amount_max=large/32
	var curve:=Curve.new();curve.add_point(Vector2(0,.65));curve.add_point(Vector2(.22,1));curve.add_point(Vector2(1,.05));node.scale_amount_curve=curve
	var ramp:=Gradient.new();ramp.colors=PackedColorArray(colors);ramp.offsets=PackedFloat32Array([0,.16,.5,1]);node.color_ramp=ramp
	var material:=CanvasItemMaterial.new();material.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;node.material=material
	add_child(node);return node
func set_tier(value:int)->void:
	if value==tier:return
	tier=value;scale=Vector2.ONE*(.75+.12*value)
func set_paused(value:bool)->void:
	for node in [flames,core,embers]:
		if is_instance_valid(node):node.speed_scale=0 if value else 1
