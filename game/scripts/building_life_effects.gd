class_name BuildingLifeEffects
extends Node2D
## Presentation-only accents; never change footprint, save data or work clocks.
var sprite:Sprite2D
var kind:String
var level:int
var clock:=0.0
var fire:HearthParticles
var hunters:Array[TrainingHunter]=[]
func _init(image:Sprite2D,category:String,tier:int)->void:
	sprite=image;kind=category;level=tier;name="BuildingLifeEffects";visibility_layer=2
func _process(delta:float)->void:
	var world:=get_parent().get_parent() as DemoWorld
	var paused:bool=not is_visible_in_tree() or (world!=null and world.player.presentation_paused)
	if not paused:clock+=delta
	if kind=="hearth":
		if fire==null:fire=HearthParticles.new();add_child(fire)
		fire.position=pixel(Vector2(.5,.53));fire.set_tier(level);fire.set_paused(paused)
	if kind=="training":sync_training()
	queue_redraw()
func _draw()->void:
	if not is_instance_valid(sprite):return
	if kind=="shrine" and level>=3:draw_shrine()
func pixel(uv:Vector2)->Vector2:
	return sprite.transform*(sprite.get_rect().position+uv*sprite.texture.get_size())
func glow_line(points:PackedVector2Array,strength:float)->void:
	var gold:=Color(.12,.52,1.0,strength) if level>=4 else Color(1.0,.24,.06,strength)
	for layer in [3,2,1]:
		var color:=gold;color.a*=.10 if layer==3 else .28 if layer==2 else 1.0
		draw_polyline(points,color,[2.8,6.0,10.0][layer-1],true)
func draw_shrine()->void:
	var strength:float=(.86 if level==3 else .98)*(.88+.12*sin(clock*1.7))
	var center:=Vector2(.455,.435) if level==3 else Vector2(.485,.418)
	var radii:=Vector2(.073,.051) if level==3 else Vector2(.068,.048)
	var points:=PackedVector2Array()
	for i in 65:
		var a:=TAU*i/64.0
		var d:=Vector2(cos(a)*radii.x,sin(a)*radii.y)
		if level==3:d=d.rotated(-.65)
		points.append(pixel(center+d))
	glow_line(points,strength)
	if level==3:
		for pair in [[Vector2(.519,.348),Vector2(.546,.299)],[Vector2(.545,.366),Vector2(.593,.335)],[Vector2(.556,.397),Vector2(.607,.391)]]:
			glow_line(PackedVector2Array([pixel(pair[0]),pixel(pair[1])]),strength)
	else:
		for i in 8:
			var a:=TAU*i/8.0
			var direction:=Vector2(cos(a),sin(a))
			glow_line(PackedVector2Array([pixel(center+direction*Vector2(.09,.063)),pixel(center+direction*Vector2(.125,.098))]),strength)
		for i in 5:
			var t:=fmod(clock*.19+i*.21,1.0)
			var at:=pixel(center+Vector2(sin(i*2.3)*.12,.12-t*.24))
			draw_circle(at,1.7,Color(.2,.65,1.0,sin(t*PI)*.85))
func sync_training()->void:
	var wanted:=1 if level==1 else 2
	while hunters.size()>wanted:hunters.pop_back().queue_free()
	while hunters.size()<wanted:
		var index:=hunters.size();var actor:=TrainingHunter.new(1 if index==0 else -1,index*1.1)
		add_child(actor);hunters.append(actor)
	for i in hunters.size():hunters[i].position=Vector2(-58 if i==0 else 58,56 if i==0 else 62)
