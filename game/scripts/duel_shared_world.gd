extends Node2D
## Han/forest laboratory only. One renderer and metric space own both rigs,
## body capsules, floor and swept weapon/hurt-volume contacts. No screen tests.
const FIXED_STEP:=1.0/120.0
const ENGAGE_DISTANCE:=2.25
const START_DISTANCE:=7.5
const BODY_RADII:=[.29,.46]
const WEAPON_RADIUS:=.055
var viewport:SubViewport
var scene:Node3D
var camera:Camera3D
var display:Sprite2D
var actors:Array=[]
var bodies:Array[AnimatableBody3D]=[]
var body_shapes:Array[CollisionShape3D]=[]
var body_guards:Array[CollisionShape3D]=[]
var hurt:Array[Area3D]=[]
var originals:Array=[]
var facing:=[0.0,0.0]
var aim_bias:=[0.0,0.0]
var aim_by_motion:Dictionary={}
var action_origin:=[Vector3.ZERO,Vector3.ZERO]
var previous_root:=[Vector3.ZERO,Vector3.ZERO]
var previous_weapon:=[Vector3.ZERO,Vector3.ZERO]
var previous_hurt:Array=[]
var consumed:=[false,false]
var action_id:=[0,0]
var action_name:=["idle","idle"]
var contacts:Array[Dictionary]=[]
var body_contacts:=0
var knockback:=[Vector3.ZERO,Vector3.ZERO]
var max_body_penetration:=0.0
var fade_materials:Array=[[],[]]
var last_alpha:=[1.0,1.0]
var direction:=Vector3(1,0,-.88).normalized()
var screen_origin:=Vector2.ZERO

func configure(left,right,center:Vector2)->void:
	actors=[left,right]
	viewport=SubViewport.new();viewport.name="SharedDuel3DViewport"
	viewport.size=Vector2i(1280,720);viewport.own_world_3d=true;viewport.transparent_bg=true
	viewport.msaa_3d=Viewport.MSAA_2X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	scene=Node3D.new();viewport.add_child(scene)
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0,0,0,0)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("fff0d9");env.environment.ambient_light_energy=.5
	scene.add_child(env)
	for spec in [[Vector3(-38,-35,0),Color("fff1d1"),1.05],[Vector3(-25,145,0),Color("e7edda"),.22]]:
		var light:=DirectionalLight3D.new();light.rotation_degrees=spec[0];light.light_color=spec[1];light.light_energy=spec[2];scene.add_child(light)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=15.2
	scene.add_child(camera);camera.position=Vector3(0,8.4,9);camera.look_at(Vector3.ZERO)
	var floor:=StaticBody3D.new();floor.name="SharedGround";floor.collision_layer=4
	var floor_shape:=CollisionShape3D.new();var plane:=BoxShape3D.new();plane.size=Vector3(40,.1,40)
	floor_shape.shape=plane;floor.position.y=-.05;floor.add_child(floor_shape);scene.add_child(floor)
	display=Sprite2D.new();display.texture=viewport.get_texture();display.centered=false;display.scale=Vector2(.75,.75)
	add_child(display);display.position=center-camera.unproject_position(Vector3.ZERO)*display.scale
	screen_origin=display.position
	for i in 2:
		var actor=actors[i];var p=actor.preview
		originals.append({"parent":p.pivot.get_parent(),"transform":p.pivot.transform,"viewport_size":p.viewport.size})
		var body:=AnimatableBody3D.new();body.name="HanBody" if i==0 else "DeerBody";body.sync_to_physics=false;body.collision_layer=1;body.collision_mask=5
		scene.add_child(body);bodies.append(body)
		var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=BODY_RADII[i];capsule.height=1.65 if i==0 else 1.45
		shape.shape=capsule;shape.position.y=.85;body.add_child(shape);body_shapes.append(shape)
		var guard:=CollisionShape3D.new();guard.name="HipAndForelegEnvelope";guard.shape=capsule
		guard.position.y=.85;body.add_child(guard);body_guards.append(guard)
		var area:=Area3D.new();area.name="HanHurt" if i==0 else "DeerHurt";area.collision_layer=2;area.collision_mask=0;body.add_child(area);hurt.append(area)
		var hs:=CollisionShape3D.new();var hc:=CapsuleShape3D.new();hc.radius=.30 if i==0 else .36;hc.height=1.55 if i==0 else 1.5
		hs.shape=hc;area.add_child(hs)
		if i==1:hs.rotation.x=PI*.5
		area.position.y=1.0
		p.pivot.reparent(body,false);p.pivot.transform=Transform3D.IDENTITY
		for mesh in p.pivot.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var material=mesh.get_active_material(surface)
				if material is StandardMaterial3D:
					var copy:StandardMaterial3D=material.duplicate()
					mesh.set_surface_override_material(surface,copy)
					fade_materials[i].append({"material":copy,"mode":copy.transparency})
		p.display.hide();p.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		p.viewport.size=Vector2i(2,2) # Adapter API stays valid without two unused large render targets.
		p.set_meta("duel_world",self);p.set_meta("duel_side",i)
		actor.death_effect.z_index=4
	_calibrate_weapon_axis()
	reset()

func detach()->void:
	for i in actors.size():
		var p=actors[i].preview
		if not is_instance_valid(p):continue
		p.pivot.reparent(originals[i].parent,false);p.pivot.transform=originals[i].transform
		p.viewport.size=originals[i].viewport_size
		p.remove_meta("duel_world");p.remove_meta("duel_side");p.display.show()

func _calibrate_weapon_axis()->void:
	# Authored local attack headings differ between jab and downward jump.
	# Read their actual weapon trajectory once, without translating either rig.
	var actor=actors[0];var p=actor.preview
	for key in ["attack","skill","chain"]:
		actor.play(key);actor.sample(actor.duration*(.48 if key=="chain" else .5),false)
		var root:int=p.root_bone;var pose:Vector3=p.skeleton.get_bone_pose_position(root)
		pose.x=0;pose.z=0;p.skeleton.set_bone_pose_position(root,pose)
		p.skeleton.force_update_all_bone_transforms()
		var weapon:=weapon_point(0)-bodies[0].position
		aim_by_motion[key]=atan2(weapon.x,weapon.z)
	aim_bias[0]=aim_by_motion.attack
	actor.play("idle");actors[1].play("idle")

func reset()->void:
	contacts.clear();body_contacts=0;max_body_penetration=0
	knockback=[Vector3.ZERO,Vector3.ZERO]
	previous_hurt.clear();consumed=[false,false];action_name=["idle","idle"];action_id=[0,0]
	for i in 2:
		bodies[i].position=direction*START_DISTANCE*.5*(-1 if i==0 else 1)
		facing[i]=atan2(direction.x,direction.z)+(0 if i==0 else PI)
		action_origin[i]=bodies[i].position;previous_root[i]=Vector3.ZERO
		previous_weapon[i]=weapon_point(i);previous_hurt.append(hurt_capsule(i))

func begin_action(side:int,key:String)->void:
	action_id[side]+=1;action_name[side]=key;consumed[side]=false
	action_origin[side]=bodies[side].position;previous_root[side]=Vector3.ZERO
	previous_weapon[side]=weapon_point(side)
	previous_hurt[side]=hurt_capsule(1-side)
	if side==0 and aim_by_motion.has(key):aim_bias[0]=aim_by_motion[key]

func project(point:Vector3)->Vector2:
	return display.position+camera.unproject_position(point)*display.scale

func body_screen(side:int)->Vector2:return project(bodies[side].position)

func bone_world(side:int,bone:String)->Vector3:
	var sk:Skeleton3D=actors[side].preview.skeleton
	var index:=sk.find_bone(bone)
	if index<0:index=0
	return sk.to_global(sk.get_bone_global_pose(index).origin)

func bone_screen(side:int,bone:String)->Vector2:return project(bone_world(side,bone))

func weapon_point(side:int)->Vector3:
	if side==1:
		# Head-mounted nose/horn probe, transformed by the actual sampled rig.
		var sk:Skeleton3D=actors[1].preview.skeleton
		var head:=sk.find_bone("head")
		return sk.to_global(sk.get_bone_global_pose(head)*Vector3(0,0,.23))
	var p=actors[0].preview
	var presenter=actors[0].preview.get_meta("duel_presenter",null)
	if presenter==null:return bone_world(0,"hand.R")
	return p.skeleton.global_transform*p.skeleton.get_bone_global_pose(presenter.hand)*presenter.tip_in_hand

func hurt_capsule(side:int)->Dictionary:
	var shape:CapsuleShape3D=hurt[side].get_child(0).shape
	var axis:Vector3=hurt[side].get_child(0).global_basis.y.normalized()
	var half:=maxf(0,shape.height*.5-shape.radius)
	return {"a":hurt[side].global_position-axis*half,"b":hurt[side].global_position+axis*half,"radius":shape.radius}

static func capsule_hit(from:Vector3,to:Vector3,a:Vector3,b:Vector3,radius:float)->float:
	# Continuous segment vs capsule: finite cylinder plus its two end spheres.
	# This also catches fast tips that enter AND leave between rendered frames.
	var axis:=b-a;var offset:=from-a;var travel:=to-from
	var aa:=axis.length_squared()
	var closest:=a+axis*clampf(offset.dot(axis)/maxf(aa,.000001),0,1)
	if from.distance_squared_to(closest)<=radius*radius:return 0.0
	var best:=INF
	var v:=travel.length_squared()
	if v<.000000001:return best
	for center in [a,b]:
		var oc:Vector3=from-center;var q:=travel.dot(oc);var discriminant:=q*q-v*(oc.length_squared()-radius*radius)
		if discriminant>=0:
			var t:=(-q-sqrt(discriminant))/v
			if t>=0 and t<=1:best=minf(best,t)
	if aa>.000001:
		var ad:=axis.dot(travel);var ao:=axis.dot(offset)
		var qa:=aa*v-ad*ad;var qb:=aa*travel.dot(offset)-ao*ad
		var qc:=aa*offset.length_squared()-ao*ao-radius*radius*aa
		var discriminant:=qb*qb-qa*qc
		if absf(qa)>.00000001 and discriminant>=0:
			var t:=(-qb-sqrt(discriminant))/qa
			var axial:=ao+t*ad
			if t>=0 and t<=1 and axial>=0 and axial<=aa:best=minf(best,t)
	return best

func resolve_bodies(next:Array,previous_centers:Array=[],previous_guards:Array=[])->void:
	# Relative swept upright capsules in XYZ (Minkowski sum), resolved together.
	# The shapes follow the sampled torsos, including airborne jump poses.
	var old0:Vector3=bodies[0].position;var old1:Vector3=bodies[1].position
	var r:float=BODY_RADII[0]+BODY_RADII[1]+.025
	var half:float=0
	for shape in body_shapes:half+=shape.shape.height*.5-shape.shape.radius
	var proxies:=[body_shapes,body_guards,[body_shapes[0],body_guards[1]],[body_guards[0],body_shapes[1]]]
	var histories:=[previous_centers,previous_guards,[],[]]
	if previous_centers.size()==2 and previous_guards.size()==2:
		histories[2]=[previous_centers[0],previous_guards[1]];histories[3]=[previous_guards[0],previous_centers[1]]
	var t:=INF
	for j in proxies.size():
		var center0:Vector3=proxies[j][0].global_position;var center1:Vector3=proxies[j][1].global_position
		var before0:Vector3=histories[j][0] if histories[j].size()==2 else center0
		var before1:Vector3=histories[j][1] if histories[j].size()==2 else center1
		var rel:=before0-before1
		var motion:Vector3=(center0+next[0]-old0)-(center1+next[1]-old1)-rel
		t=minf(t,capsule_hit(rel,rel+motion,Vector3.DOWN*half,Vector3.UP*half,r))
	if t!=INF:
		body_contacts+=1
		var at0:Vector3=old0+(next[0]-old0)*maxf(0,t-.0001)
		var at1:Vector3=old1+(next[1]-old1)*maxf(0,t-.0001)
		var normal:Vector3=(at0-at1).normalized();normal.y=0;normal=normal.normalized()
		if normal.length_squared()<.5:normal=-direction
		var remain0:Vector3=next[0]-at0;var remain1:Vector3=next[1]-at1
		var move0:Vector3=next[0]-old0;var move1:Vector3=next[1]-old1
		var head_on:=move0.dot(old1-old0)>0 and move1.dot(old0-old1)>0 and move0.normalized().dot(move1.normalized())<-.75
		if head_on:
			# Opposing straight charges stop at contact. Do not synthesize sideways
			# motion that lets offset torso centers slide the actors past each other.
			remain0=Vector3.ZERO;remain1=Vector3.ZERO
		else:
			if remain0.dot(normal)<0:remain0-=normal*remain0.dot(normal)
			if remain1.dot(normal)>0:remain1-=normal*remain1.dot(normal)
		next=[at0+remain0,at1+remain1]
	for i in 2:bodies[i].position=Vector3(next[i].x,0,next[i].z)
	# Robustly separate an externally repositioned overlap before the next step.
	for iteration in 3:
		for proxy in proxies:
			var gap:Vector3=proxy[1].global_position-proxy[0].global_position
			var vertical:=maxf(0,absf(gap.y)-half);gap.y=0
			var required:=sqrt(maxf(0,r*r-vertical*vertical))
			if gap.length()<required:
				var normal:=gap.normalized() if gap.length()>.0001 else direction
				var overlap:=required-gap.length()
				bodies[0].position-=normal*overlap*.5;bodies[1].position+=normal*overlap*.5
	for proxy in proxies:
		var end_gap:Vector3=proxy[1].global_position-proxy[0].global_position
		var vertical:=maxf(0,absf(end_gap.y)-half);end_gap.y=0
		var separation:=sqrt(end_gap.length_squared()+vertical*vertical)
		max_body_penetration=maxf(max_body_penetration,maxf(0,r-separation))

func apply_hit(side:int,direction:Vector3,strong:bool)->void:
	direction.y=0
	knockback[side]=direction.normalized()*(.9 if strong else .45)

func _aim_thrust(key:String,age:float,duration:float)->void:
	if key not in ["attack","skill"]:return
	var phase:=age/maxf(.001,duration)
	var weight:=smoothstep(.15,.35,phase)*(1.0-smoothstep(.65,.85,phase))
	if weight<=0:return
	var sk:Skeleton3D=actors[0].preview.skeleton
	var upper:=sk.find_bone("upper.R")
	var tip:=weapon_point(0);var hand:=bone_world(0,"hand.R")
	var target:=bone_world(1,"trunk")
	var toward:=target-hand;toward.y=0
	if toward.length()<.01:return
	# A bounded shoulder pitch aims the existing thrust at torso height. This
	# changes the real rig/weapon, never translates the body to a desired FX pixel.
	var angle:=clampf(atan2(tip.y-target.y,maxf(.3,Vector2(tip.x-hand.x,tip.z-hand.z).length())),-.24,.24)*weight
	var axis:=Vector3.UP.cross(toward.normalized())
	var global_basis:=sk.global_basis*sk.get_bone_global_pose(upper).basis
	var parent_basis:=sk.global_basis*sk.get_bone_global_pose(sk.get_bone_parent(upper)).basis
	sk.set_bone_pose_rotation(upper,(parent_basis.inverse()*Basis(axis,angle)*global_basis).get_rotation_quaternion())
	sk.force_update_all_bone_transforms()

func render_poses(lab,delta:float)->Array:
	var root_motion:Array=[]
	for side in 2:
		var actor=actors[side];var key:String=lab.motion[side];var age:float=lab.age[side]
		var p=actor.preview
		var toward:=bodies[1-side].position-bodies[side].position;toward.y=0
		if toward.length()>.001:
			var heading:float=atan2(toward.x,toward.z)-(aim_bias[side] if side==0 else 0.0)
			facing[side]=lerp_angle(facing[side],heading,minf(1,delta*18)) if delta>0 else heading
		p.pivot.rotation.y=facing[side]
		# Reuse D0070 recovery blending and death-before-reward presentation.
		lab.presentation.sample(actor,side,key,age,INF if lab.approach_active else float(lab.next_attack[side])-lab.rules.elapsed,delta,false)
		var sk:Skeleton3D=p.skeleton
		var root:int=p.root_bone if side==0 else p.root_index
		var root_pose:=sk.get_bone_pose_position(root);var rest:=sk.get_bone_rest(root).origin
		root_motion.append(root_pose-rest)
		root_pose.x=rest.x;root_pose.z=rest.z;sk.set_bone_pose_position(root,root_pose)
		p.pivot.position=Vector3(0,.12,0)
		sk.force_update_all_bone_transforms()
		var feet:=["foot.R","foot.L"] if side==0 else ["front_foot.R","front_foot.L","hind_foot.R","hind_foot.L"]
		var bottom:=INF
		for foot in feet:bottom=minf(bottom,bone_world(side,foot).y)
		if bottom<0:p.pivot.position.y-=bottom;sk.force_update_all_bone_transforms()
		if side==0:_aim_thrust(key,age,actor.duration)
		p.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		var torso:=bone_world(side,"spine" if side==0 else "trunk")
		body_shapes[side].global_position=torso-Vector3(0,.12 if side==0 else .15,0)
		body_guards[side].position=Vector3(0,torso.y-.12 if side==0 else torso.y-.15,0)
		hurt[side].global_position=torso
		hurt[side].rotation.y=facing[side]
		p.modulate.a=1 # Shared native render owns visibility; only the rig is faded.
		var fade:=1.0-smoothstep(.78,1,age) if key=="death" else 1.0
		if not is_equal_approx(last_alpha[side],fade):
			for item in fade_materials[side]:
				item.material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if fade<.999 else item.mode
				item.material.albedo_color.a=fade
			last_alpha[side]=fade
		p.pivot.visible=fade>.02
	return root_motion

func step(lab,delta:float)->Array[Dictionary]:
	var old_hurt:=[hurt_capsule(0),hurt_capsule(1)]
	var old_weapon:=[weapon_point(0),weapon_point(1)]
	var old_centers:=[body_shapes[0].global_position,body_shapes[1].global_position]
	var old_guards:=[body_guards[0].global_position,body_guards[1].global_position]
	var roots:=render_poses(lab,delta)
	var desired:=[bodies[0].position,bodies[1].position]
	for side in 2:
		var key:String=lab.motion[side]
		var toward:Vector3=bodies[1-side].position-bodies[side].position;toward.y=0
		var distance:=toward.length();toward=toward.normalized()
		if lab.approach_active:
			var gap:=lerpf(START_DISTANCE,ENGAGE_DISTANCE,smoothstep(0,lab.APPROACH_TRAVEL,lab.visual_clock))
			desired[side]=direction*gap*.5*(-1 if side==0 else 1)
		elif key in ["attack","skill","chain"]:
			var forward:=maxf(0,float(roots[side].z-previous_root[side].z))*1.24
			var safe:=1.75 if side==0 and key=="skill" else 1.85 if key=="chain" else .85
			if side==1 and key=="attack" and lab.age[side]<actors[side].duration*.55:
				forward=maxf(forward,minf(maxf(0,distance-1.15),delta*2.4))
			desired[side]+=toward*minf(forward,maxf(0,distance-safe))
		previous_root[side]=roots[side]
		desired[side]+=knockback[side]*delta
		knockback[side]=knockback[side].move_toward(Vector3.ZERO,delta*5)
	resolve_bodies(desired,old_centers,old_guards)
	var events:Array[Dictionary]=[]
	for side in 2:
		var now:=weapon_point(side)
		var target:=hurt_capsule(1-side)
		var key:String=lab.motion[side]
		var length:float=actors[side].duration
		var opens:float=length*(.24 if key=="attack" else .31)
		var closes:float=length*(.70 if key=="attack" else .74)
		if side==1 and key=="skill":
			opens=actors[side].preview.length("req046_skill_anticipation");closes=length*.94
		var prior_age:float=lab.age[side]-delta
		var active:bool=lab.age[side]>=opens and prior_age<=closes
		if not lab.approach_active and key in ["attack","skill","chain"] and not consumed[side] and active and lab.rules.living():
			# Substeps follow articulated motion; relative target travel is included.
			var shift:Vector3=(target.a+target.b-old_hurt[1-side].a-old_hurt[1-side].b)*.5
			var start_fraction:=clampf((opens-prior_age)/maxf(.000001,delta),0,1)
			var end_fraction:=clampf((closes-prior_age)/maxf(.000001,delta),0,1)
			var from:Vector3=(old_weapon[side]+shift).lerp(now,start_fraction)
			var to:Vector3=(old_weapon[side]+shift).lerp(now,end_fraction)
			var t:=capsule_hit(from,to,target.a,target.b,float(target.radius)+WEAPON_RADIUS)
			if t!=INF:
				consumed[side]=true
				var fraction:=lerpf(start_fraction,end_fraction,t)
				var probe:Vector3=from.lerp(to,t)
				var axis:Vector3=target.b-target.a
				var nearest:Vector3=target.a+axis*clampf((probe-target.a).dot(axis)/maxf(.0001,axis.length_squared()),0,1)
				var point:Vector3=nearest+nearest.direction_to(probe)*float(target.radius)
				var event:={"side":side,"motion":key,"point":point,"probe":probe,"hurt":target.duplicate(),"weapon_from":from,"weapon_to":to,"normal":(bodies[1-side].position-bodies[side].position).normalized(),"action":action_id[side],"time":lab.rules.elapsed-delta+fraction*delta,"attack_age":prior_age+fraction*delta,"active_from":opens,"active_to":closes}
				events.append(event);contacts.append(event)
		previous_weapon[side]=now
	events.sort_custom(func(first,second):return first.time<second.time)
	return events
