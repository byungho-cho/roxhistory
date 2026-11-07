class_name BuildingLifeEffects
extends Node2D
## Presentation-only accents; never change footprint, save data or work clocks.
var sprite:Sprite2D
var kind:String
var level:int
var clock:=0.0
func _init(image:Sprite2D,category:String,tier:int)->void:
	sprite=image;kind=category;level=tier;name="BuildingLifeEffects";visibility_layer=2
func _process(delta:float)->void:
	clock+=delta
	queue_redraw()
func _draw()->void:
	if not is_instance_valid(sprite):return
	if kind=="hearth":draw_hearth()
	elif kind=="shrine" and level>=3:draw_shrine()
	elif kind=="training" and level>=2:draw_training()
func pixel(uv:Vector2)->Vector2:
	return sprite.transform*(sprite.get_rect().position+uv*sprite.texture.get_size())
func glow_line(points:PackedVector2Array,strength:float)->void:
	var gold:=Color(.88,1.0,.38,strength)
	for layer in [3,2,1]:
		var color:=gold;color.a*=.18 if layer>1 else .85
		draw_polyline(points,color,float(layer)*1.2,true)
func draw_shrine()->void:
	var strength:float=(.35 if level==3 else .52)*(.8+.2*sin(clock*1.7))
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
			draw_circle(at,.6,Color(1,.86,.36,sin(t*PI)*.48))
func draw_hearth()->void:
	# Source fire is retained; animated small flames and smoke follow its center.
	var base:=pixel(Vector2(.5,.53))
	var scale_factor:=.65+level*.18
	for i in 3:
		var sway:=sin(clock*4.3+i*2.1)*2.5
		var height:float=(8+i*3)*scale_factor*(.85+.15*sin(clock*7+i))
		var x:=float(i-1)*4*scale_factor
		var points:=PackedVector2Array([base+Vector2(x-3,1),base+Vector2(x-4,-height*.4),base+Vector2(x+sway,-height),base+Vector2(x+3,-height*.35),base+Vector2(x+3,1)])
		draw_colored_polygon(points,Color(1,.49+.08*i,.06,.55))
	for i in 7:
		var t:=fmod(clock*(.22+level*.018)+i/7.0,1.0)
		var p:=base+Vector2(sin(t*3+i)*5+t*10,-15-t*(26+level*5))
		var radius:float=(2.5+t*7)*scale_factor
		for layer in [3,2,1]:draw_circle(p,radius*layer/2.0,Color(.69,.66,.60,sin(t*PI)*.023))
func draw_training()->void:
	# Reserve the lower half of the common foundation for future tree retouches.
	var count:=1 if level==2 else 2
	for pair in count:
		var center:=Vector2(-30+pair*58,43+pair*5)
		var beat:=sin(clock*3.6+pair*2.2)
		for side in [-1,1]:
			var feet:=center+Vector2(side*(10-beat*1.2),0)
			draw_set_transform(feet,0,Vector2.ONE)
			draw_circle(Vector2(0,-11),2.1,Color("b98a58"))
			draw_line(Vector2(0,-8),Vector2(side*.8,-3),Color("705538"),3,true)
			draw_line(Vector2(0,-3),Vector2(-2,1),Color("735233"),1.4,true)
			draw_line(Vector2(0,-3),Vector2(2,-beat),Color("735233"),1.4,true)
			var tip:=Vector2(-side*12,-8-beat*3)
			draw_line(Vector2(side*3,-5),tip,Color("ae9365"),1,true)
			draw_circle(tip,.8,Color("b7b6a1"))
			draw_set_transform(Vector2.ZERO)
		var t:=fmod(clock*.8+pair*.5,1.0)
		for j in 3:draw_circle(center+Vector2((j-1)*5+t*3,-t*5),1+t*3,Color(.72,.61,.40,(1-t)*.1))
