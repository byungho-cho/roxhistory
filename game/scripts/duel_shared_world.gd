extends Node2D
## Han/forest laboratory only. One renderer and metric space own both rigs,
## body capsules, floor and swept weapon/hurt-volume contacts. No screen tests.
const FIXED_STEP:=1.0/120.0
const ENGAGE_DISTANCE:=2.45
const RECOVER_SPEED:=2.7
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
const URAM_FLOOR_CONTACT:=.85
const URAM_FLOOR_HOLD:=.70
const URAM_FLOOR_TRAVEL:=.16
var uram_floor_trace_advance:=0.0
var uram_floor_original_tip:=Vector3.ZERO
var uram_floor_hit:Dictionary={}
var uram_floor_emitted:=false
var uram_floor_emit_age:=-1.
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
var deer_spear_reaction:=false
var fade_materials:Array=[[],[]]
var last_alpha:=[1.0,1.0]
var direction:=Vector3(1,0,-.88).normalized()
var screen_origin:=Vector2.ZERO
var floor_bounce_lights:Array[OmniLight3D]=[]
var uram_planted_feet:Dictionary={}
var forest_input_face:=Transform3D.IDENTITY
var forest_input_pending:=false
var forest_guard_close_brace:=false
var uram_basic_feet_start:=Vector3.ZERO
var uram_basic_anchor:=false
var uram_entry_shield_revealed:=false

func configure(left,right,center:Vector2,local_ranged_boar:=false,local_uram_forest:=false)->void:
	actors=[left,right]
	uram_forest_pair=left.key=="uram" and right.key=="forest" and local_uram_forest
	uram_pair=left.key=="uram" and (right.key=="adult" or uram_forest_pair)
	saebom_pair=left.key=="saebom" and (right.key=="forest" or (local_ranged_boar and right.key=="adult"))
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
		if left.key=="hangyeol" and right.key=="forest":
			var glow:=OmniLight3D.new()
			glow.name="TeamRingBounce"
			glow.light_color=Color("54b8ff") if i==0 else Color("ff6b46")
			glow.light_energy=.95 if i==0 else .63
			glow.light_specular=.14
			glow.omni_range=1.18
			glow.omni_attenuation=1.65
			glow.position=Vector3(0,.13,.16)
			body.add_child(glow);floor_bounce_lights.append(glow)
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
	if uram_forest_pair:
		# This lab already samples the authored clip explicitly on every
		# simulation step. Prevent native auto-processing from replacing the
		# final visual blend after the actor keys switch to walk or idle.
		var driver:AnimationPlayer=actors[0].preview.animator
		uram_previous_animator_mode=driver.callback_mode_process
	if not uram_pair and not saebom_pair:_calibrate_weapon_axis()
	if saebom_pair:_setup_projectile()
	reset()

func detach()->void:
	if uram_previous_animator_mode>=0 and not actors.is_empty() and is_instance_valid(actors[0].preview):
		actors[0].preview.animator.callback_mode_process=uram_previous_animator_mode
		uram_previous_animator_mode=-1
	_restore_sling_stone()
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
	restore_uram_outgoing_display()
	uram_out_started=-1.0;uram_out_snapshot.clear();uram_out_bridge.clear();uram_out_basic_return=false
	uram_trade_last_strike=-INF;uram_trade_pending_hit=-INF;uram_trade_at=-INF;uram_trade_feet.clear()
	restore_uram_intake_display()
	uram_intake_age=-1.0;uram_return_age=-1.0;uram_return_pose.clear();uram_intake_seeds.clear();uram_last_drawn_hit.clear()
	restore_uram_ram_display()
	uram_ram_visual_anchors.clear()
	uram_planted_feet.clear()
	uram_displayed_feet.clear()
	forest_input_pending=false
	forest_guard_close_brace=false
	uram_basic_anchor=false
	uram_entry_shield_revealed=false
	if local_melee_polish and uram_pair:actors[0].preview.shield.hide()
	bom_close=false;bom_shove=false;bom_near_skill=false;knife_beat=0;bom_hop=0.;bom_prev=0.
	basic_rope_empty=false
	_end_projectile();projectile_releases.clear();_restore_sling_stone()
	contacts.clear();body_contacts=0;max_body_penetration=0;deer_spear_reaction=false
	knockback=[Vector3.ZERO,Vector3.ZERO]
	previous_hurt.clear();consumed=[false,false];action_name=["idle","idle"];action_id=[0,0]
	for i in 2:
		bodies[i].position=direction*START_DISTANCE*.5*(-1 if i==0 else 1)
		facing[i]=atan2(direction.x,direction.z)+(0 if i==0 else PI)
		action_origin[i]=bodies[i].position;previous_root[i]=Vector3.ZERO
		previous_weapon[i]=weapon_point(i);previous_hurt.append(hurt_capsule(i))

func begin_action(side:int,key:String)->void:
	if side==0 and uram_pair:
		uram_floor_trace_advance=0.0
		uram_floor_original_tip=weapon_point(0)
		uram_floor_hit.clear()
		uram_floor_emitted=false
		uram_floor_emit_age=-1.
		if key=="skill":_capture_uram_feet()
	if uram_forest_pair:
		if side==1 and key=="skill":_capture_uram_feet()
		if side==0:
			uram_basic_anchor=key=="attack"
			if uram_basic_anchor:
				uram_basic_feet_start=(bone_world(0,"foot.R")+bone_world(0,"foot.L"))*.5
			if key=="chain" and uram_planted_feet.is_empty():_capture_uram_feet()
			elif key not in ["chain","counter","skill"]:uram_planted_feet.clear()
	if side==0 and saebom_pair and local_melee_polish:
		update_knife_latch()
		bom_shove=key=="attack" and bom_close
		bom_near_skill=key=="skill" and bom_close
		knife_beat=0
		bom_hop=0.
		bom_prev=0.
		bom_dir=((bodies[0].position-bodies[1].position)*Vector3(1,0,1)).normalized()
	action_id[side]+=1;action_name[side]=key;consumed[side]=false
	action_origin[side]=bodies[side].position;previous_root[side]=Vector3.ZERO
	previous_weapon[side]=weapon_point(side)
	previous_hurt[side]=hurt_capsule(1-side)
	if side==0 and aim_by_motion.has(key):aim_bias[0]=aim_by_motion[key]

func update_knife_latch()->void:
	if not saebom_pair or not local_melee_polish:return
	bom_close=saebom_close_at(bodies[0].position.distance_to(bodies[1].position),bom_close,1.52,1.82)

func _knife_unit(side:int)->Dictionary:
	return {"actor":actors[side],"feet":body_screen(side)}

func _knife_tip_world(screen:Vector2)->Vector3:
	var depth:float=-camera.to_local(bone_world(0,"hand.R")).z
	return Knife.unproject(actors[0].preview,screen,depth)

func knife_skill_active(key:String)->bool:
	return local_melee_polish and saebom_pair and key=="skill" and bom_near_skill

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
	if saebom_pair and side==0:
		if bom_shove and actors[0].preview.has_meta("saebom_melee_blade"):
			var prop:Array=actors[0].preview.get_meta("saebom_melee_blade")
			return _knife_tip_world(prop[0][2])
		if not bom_shove:return sling_point()
		var sk:Skeleton3D=actors[0].preview.skeleton
		var hand:=sk.find_bone("hand.R")
		var tip:=bone_world(0,"hand.R")
		if hand<0:return tip
		var elbow:=sk.get_bone_parent(hand)
		return tip+(tip-sk.to_global(sk.get_bone_global_pose(elbow).origin)).normalized()*.105
	if uram_pair and side==0:
		var p=actors[0].preview
		if action_name[0]=="counter":return p.shield.to_global(Vector3(0,0,.035))
		var club:MeshInstance3D=p.club
		var box:=club.get_aabb()
		return club.to_global(Vector3(box.end.x*.85,0,0))
	if side==1:
		# Head-mounted nose/horn probe, transformed by the actual sampled rig.
		var sk:Skeleton3D=actors[1].preview.skeleton
		var head:=sk.find_bone("head")
		if uram_pair:
			var crown:=bone_world(1,"head")
			var forward:=crown-bone_world(1,"trunk");forward.y=0.0
			if forward.length_squared()<.0001:forward=-direction
			return crown+forward.normalized()*.46+Vector3.UP*.025
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
	if side==1:deer_spear_reaction=not strong

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

func _rig_alpha(side:int,fade:float)->void:
	if not is_equal_approx(last_alpha[side],fade):
		for item in fade_materials[side]:
			item.material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if fade<.999 else item.mode
			item.material.albedo_color.a=fade
		last_alpha[side]=fade
	actors[side].preview.pivot.visible=fade>.02

func render_poses(lab,delta:float)->Array:
	var root_motion:Array=[]
	for side in 2:
		var actor=actors[side];var key:String=lab.motion[side];var age:float=lab.age[side]
		var p=actor.preview
		if side==0 and uram_forest_pair:
			# Only the ordinary club→return→idle presentation owns a manual
			# mixer. Guard, charge intake, counter and other moves stay stock.
			var manual:=key=="attack" or (key=="walk" and uram_out_basic_return) or (key=="idle" and uram_out_started>=0. and not uram_return_contact_pose.is_empty())
			var callback:=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if manual else uram_previous_animator_mode
			if p.animator.callback_mode_process!=callback:p.animator.callback_mode_process=callback
		if side<floor_bounce_lights.size():floor_bounce_lights[side].visible=key!="death"
		if key=="death":
			# Hold the pose from the lethal contact; only opacity changes.
			root_motion.append(Vector3.ZERO)
			_rig_alpha(side,1.0-smoothstep(.09,.63,age))
			if age>=.36:
				# Let the existing dust and meat outlive the fading rig.
				actor.death_effect.sample(age-.36+.08)
				actor.death_effect.modulate.a=smoothstep(.36,.47,age)
			continue
		var toward:=bodies[1-side].position-bodies[side].position;toward.y=0
		if toward.length()>.001:
			var heading:float=atan2(toward.x,toward.z)-(aim_bias[side] if side==0 else 0.0)
			facing[side]=lerp_angle(facing[side],heading,minf(1,delta*18)) if delta>0 else heading
		p.pivot.rotation=Vector3(0,facing[side],0)
		# Reuse D0070 recovery blending and death-before-reward presentation.
		var sample_age:float=age/float(lab.entrance_scale) if lab.approach_active else age
		if uram_forest_pair and side==0 and key=="chain":
			# Settle on one visible braced posture. The shield quad and hand still
			# come from the same rig; the old idle of the clip could drop the shield.
			sample_age=.14 if lab.uram_guard_active() else minf(sample_age,.14)
		if side==0 and uram_forest_pair and key=="walk":
			sample_age=fposmod(-age*1.40,actor.duration)
		if side==1 and key=="walk":
			# Reverse the authored hoof cycle while keeping the deer facing Han.
			sample_age=fposmod(-age*1.65,actor.duration)
		if side==0 and key=="chain" and not uram_pair and not saebom_pair:sample_age=lab.Accent.chain_pose(age,actor.duration)
		var directional_hit:=side==1 and key=="hit" and deer_spear_reaction and not uram_pair
		lab.presentation.sample(actor,side,key,sample_age,INF if lab.approach_active else float(lab.next_attack[side])-lab.rules.elapsed,delta,false,directional_hit)
		if uram_forest_pair and side==1 and key=="run" and not lab.approach_active and bodies[0].position.distance_to(bodies[1].position)<LOCAL_BASIC_READY_MIN:
			var length:float=p.length("walk")
			_blend_forest_backstep(p,fposmod(-age*1.4,maxf(.01,length)),1.)
		if uram_forest_pair and side==1 and key=="skill" and age<FOREST_RAISED_AT:
			# Uram keeps the retreat, then releases the presentation to the same
			# actual anticipation + ram clip as Han. No planted artificial dip.
			_blend_forest_pose(p,p.animation.get_animation("idle"),0.,1.)
			if age>=FOREST_RETREAT_AT and age<FOREST_RETREAT_END:
				var gait:float=p.length("walk")
				var reverse_time:=fposmod(-((age-FOREST_RETREAT_AT)*1.65),maxf(.001,gait))
				_blend_forest_backstep(p,reverse_time,smoothstep(FOREST_RETREAT_AT,FOREST_RETREAT_AT+.08,age)*(1.0-smoothstep(FOREST_RETREAT_END-.10,FOREST_RETREAT_END,age)))
			if age>=FOREST_RETREAT_END:
				var native_at:float=sample_age*p.motion_rate("req046_skill_anticipation")
				_blend_forest_pose(p,p.animation.get_animation("req046_skill_anticipation"),native_at,smoothstep(FOREST_RETREAT_END,FOREST_RAISED_AT,age))
		var sk:Skeleton3D=p.skeleton
		var root:int=p.root_bone if side==0 else p.root_index
		var root_pose:=sk.get_bone_pose_position(root);var rest:=sk.get_bone_rest(root).origin
		root_motion.append(root_pose-rest)
		root_pose.x=rest.x;root_pose.z=rest.z;sk.set_bone_pose_position(root,root_pose)
		p.pivot.position=Vector3(0,.12,0)
		if directional_hit:
			# Lift the forequarters along the incoming thrust, then settle on
			# the hind feet. The actor root still follows normal collision.
			var lift:=smoothstep(0,.083,age)*(1.0-smoothstep(.10,.31,age))
			p.pivot.rotation.x=-.21*lift
			p.pivot.position-=toward.normalized()*.105*lift
		sk.force_update_all_bone_transforms()
		var feet:=["foot.R","foot.L"] if side==0 else ["front_foot.R","front_foot.L","hind_foot.R","hind_foot.L"]
		var bottom:=INF
		for foot in feet:bottom=minf(bottom,bone_world(side,foot).y)
		if bottom<0:p.pivot.position.y-=bottom;sk.force_update_all_bone_transforms()
		if side==0 and uram_forest_pair and uram_basic_anchor and key in ["attack","walk"]:
			# Cap actual rendered boot/pelvis travel, including gait posing,
			# rather than only the body's numerical step.
			var feet_center:=(bone_world(0,"foot.R")+bone_world(0,"foot.L"))*.5
			var drift:=(feet_center-uram_basic_feet_start).dot(direction)
			if drift>.502:
				p.pivot.position-=direction*(drift-.502)
				sk.force_update_all_bone_transforms()
		if side==0 and saebom_pair and local_melee_polish:
			if key=="attack" and bom_shove:Knife.show_basic(_knife_unit(0),_knife_unit(1),clampf(age/maxf(.01,actor.duration),0.,1.))
			elif knife_skill_active(key):Knife.sample_skill(_knife_unit(0),_knife_unit(1),age)
			elif key in ["idle","walk","run","hit"] and bom_close:Knife.blade(p,Vector2.ZERO,0.,0.)
			elif p.has_meta("saebom_melee_blade"):p.remove_meta("saebom_melee_blade")
		if side==0:
			if uram_pair:
				if uram_forest_pair:
					if key in ["chain","counter"] or (key=="idle" and lab.motion[1]=="skill"):
						_keep_uram_feet_anchored(sk)
					if key=="chain" and toward.length_squared()>.001:
						_aim_uram_forest_guard(sk,toward.normalized(),age,lab.uram_guard_active())
				if local_melee_polish and key=="skill":_keep_uram_feet_anchored(sk)
				p.update_equipment()
				if local_melee_polish and key=="skill":
					# Preserve the v293 sweep from the original sampled animation.
					uram_floor_original_tip=weapon_point(0)
					var visible_at:=uram_floor_visible_age(sample_age,uram_floor_emit_age,actor.duration)
					if absf(visible_at-sample_age)>.00001:
						var settled_pivot:Transform3D=p.pivot.transform
						actor.sample(visible_at,false)
						p.pivot.transform=settled_pivot
						var visible_root:=sk.get_bone_pose_position(root)
						visible_root.x=rest.x;visible_root.z=rest.z
						sk.set_bone_pose_position(root,visible_root)
					weight_uram_floor_pose(p,visible_at)
					_keep_uram_feet_anchored(sk)
					p.update_equipment()
					aim_uram_floor_club(p,toward.normalized(),visible_at)
				if local_melee_polish and not uram_entry_shield_revealed:
					# Entrants are still travelling toward the ring slots. Reveal
					# the now-posed forearm shield only on actual face-off, once.
					if not lab.approach_active or (lab.visual_clock>=lab.APPROACH_TRAVEL*lab.entrance_scale and key=="idle" and lab.motion[1]=="idle"):
						uram_entry_shield_revealed=true
						p.shield.show()
					else:p.shield.hide()
				if uram_forest_pair and key not in ["chain","counter"]:
					# Bind the passive shield directly to its moving wrist and
					# forearm mid-point. Never leave a free quad where he started.
					var wrist:=bone_world(0,"hand.L")
					var elbow:=bone_world(0,"forearm.L")
					var shield:MeshInstance3D=p.shield
					shield.global_position=wrist.lerp(elbow,.68)+shield.global_basis.z.normalized()*.042
				if key in ["chain","counter"] and toward.length_squared()>.001:
					# Use the actual shield quad, facing charging animal, not a detached invisible collider.
					var shield:MeshInstance3D=p.shield
					var tr:=shield.global_transform
					var guard_normal:=toward.normalized().lerp(tr.basis.z,.18).normalized()
					var right:=Vector3.UP.cross(guard_normal).normalized()
					tr.basis=Basis(right,guard_normal.cross(right),guard_normal)
					tr.origin+=toward.normalized()*.07
					if key=="chain" and not uram_forest_pair:
						var lower:=smoothstep(0,.085,age)*(1.0-smoothstep(.26,.43,age))
						tr.origin-=tr.basis.x*.20*lower
						tr.origin.y-=.43*lower
					shield.global_transform=tr
				if key=="attack":_aim_uram_club(age)
			elif not saebom_pair:_aim_thrust(key,age,actor.duration)
		p.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		var torso:=bone_world(side,"spine" if side==0 else "trunk")
		body_shapes[side].global_position=torso-Vector3(0,.12 if side==0 else .15,0)
		body_guards[side].position=Vector3(0,torso.y-.12 if side==0 else torso.y-.15,0)
		hurt[side].global_position=torso.lerp(bone_world(1,"head"),.32) if uram_pair and side==1 else torso
		hurt[side].rotation.y=facing[side]
		p.modulate.a=1 # Shared native render owns visibility; only the rig is faded.
		_rig_alpha(side,1.0-smoothstep(.78,1,age) if key=="death" else 1.0)
	return root_motion

func _limit_uram_visible_boots()->void:
	# After root translation the visible gait may still advance a sole beyond
	# the intended half-step. Keep this correction in the leg chain only.
	var p=actors[0].preview
	var sk:Skeleton3D=p.skeleton
	var center:=(bone_world(0,"foot.R")+bone_world(0,"foot.L"))*.5
	var excess:=maxf(0.,(center-uram_basic_feet_start).dot(direction)-.50)
	if excess<=.0001:return
	var shift:=sk.global_basis.inverse()*direction*excess
	for label in ["foot.R","foot.L"]:
		var foot:=sk.find_bone(label)
		if foot<0:continue
		var knee:=sk.get_bone_parent(foot)
		var foot_pose:=sk.get_bone_global_pose(foot)
		if knee>=0:
			var kp:=sk.get_bone_global_pose(knee)
			kp.origin-=shift*.46
			sk.set_bone_global_pose(knee,kp)
			sk.force_update_all_bone_transforms()
		foot_pose.origin-=shift
		sk.set_bone_global_pose(foot,foot_pose)
		sk.force_update_all_bone_transforms()


func _limit_local_basic_closure(proposal:Array)->void:
	# Sum both actors' closing travel before handing it to the actual shared
	# body solver. This spacing floor is unrelated to hurt radii.
	var axis:=bodies[0].position.direction_to(bodies[1].position)
	var start_gap:=bodies[0].position.distance_to(bodies[1].position)
	var first:float=(proposal[0]-bodies[0].position).dot(axis)
	var second:float=(bodies[1].position-proposal[1]).dot(axis)
	var move_sum:=maxf(first,0.)+maxf(second,0.)
	var spread:=maxf(-first,0.)+maxf(-second,0.)
	var permitted:=maxf(0.,start_gap-LOCAL_BASIC_CONTACT_MIN)+spread
	if move_sum<=permitted or move_sum<.000001:return
	var reduction:=1.-permitted/move_sum
	proposal[0]-=axis*(maxf(0.,first)*reduction)
	proposal[1]+=axis*(maxf(0.,second)*reduction)

func local_basic_in_range(side:int)->bool:
	var a:=bodies[0].position
	var b:=bodies[1].position
	var gap:=a.distance_to(b)
	return gap>=LOCAL_BASIC_READY_MIN-.0001 and gap<=LOCAL_BASIC_START[side]+.0001

func local_basic_too_far(side:int)->bool:
	return bodies[0].position.distance_to(bodies[1].position)>LOCAL_BASIC_START[side]+.0001

func uram_attack_return_offset()->Vector3:
	# Only an ordinary attack that stepped in can walk back to its start.
	var advance:float=(bodies[0].position-action_origin[0]).dot(direction)
	return -direction*maxf(0.,advance)

func deer_return_offset()->Vector3:
	# Convex return path constrained to the shared floor; preserve incidental
	# lateral displacement and hit knockback rather than undoing them.
	var remaining:float=(action_origin[1]-bodies[1].position).dot(direction)
	return direction*maxf(0,remaining)

func step(lab,delta:float,prior_han_age:float=-1.0)->Array[Dictionary]:
	var old_hurt:=[hurt_capsule(0),hurt_capsule(1)]
	var old_weapon:=[weapon_point(0),weapon_point(1)]
	var old_floor_tip:=uram_floor_original_tip
	var old_floor_advance:=uram_floor_trace_advance
	var planted:bool=local_melee_polish and uram_pair and lab.motion[0]=="skill"
	var old_shield:=_shield_transform() if uram_pair else Transform3D.IDENTITY
	if forest_input_pending:
		old_shield=forest_input_face
		forest_input_pending=false
	var old_boar_head:=boar_head_hurt() if uram_pair else {}
	var old_centers:=[body_shapes[0].global_position,body_shapes[1].global_position]
	var old_guards:=[body_guards[0].global_position,body_guards[1].global_position]
	var roots:=render_poses(lab,delta)
	var desired:=[bodies[0].position,bodies[1].position]
	for side in 2:
		var key:String=lab.motion[side]
		var toward:Vector3=bodies[1-side].position-bodies[side].position;toward.y=0
		var distance:=toward.length();toward=toward.normalized()
		if lab.approach_active:
			var gap:=lerpf(START_DISTANCE,URAM_FOREST_GAP if uram_forest_pair else URAM_PAIR_GAP if uram_pair else SAEBOM_GAP if saebom_pair else ENGAGE_DISTANCE,smoothstep(0,lab.APPROACH_TRAVEL*lab.entrance_scale,lab.visual_clock))
			desired[side]=direction*gap*.5*(-1 if side==0 else 1)
		elif uram_forest_pair and key=="run" and lab.rules.living() and not lab._local_ram_busy():
			if side==1 and distance<LOCAL_BASIC_READY_MIN:
				desired[side]-=toward*minf(1.66*delta,LOCAL_BASIC_READY_MIN-distance)
			else:
				desired[side]+=toward*minf(2.35*delta,maxf(0.,distance-LOCAL_BASIC_START[side]))
		elif saebom_pair and side==1 and key=="run" and lab.rules.living():
			# Use native run until the deer reaches its own actual attack range.
			desired[side]+=toward*minf(2.9*delta,maxf(0,distance-SAEBOM_DEER_APPROACH_GAP))
		elif uram_forest_pair and side==0 and key=="walk" and lab.rules.living():
			var offset:=uram_attack_return_offset()
			var speed:=lerpf(.72,2.45,smoothstep(0.,.26,offset.length()))
			desired[side]+=offset.limit_length(speed*delta)
		elif side==1 and key=="walk" and lab.rules.living():
			var offset:=deer_return_offset()
			var speed:=RECOVER_SPEED*lerpf(.30,1.0,smoothstep(0,.22,offset.length()))
			desired[side]+=offset.limit_length(speed*delta)
		elif uram_forest_pair and side==1 and key=="skill" and lab.age[1]<actors[1].preview.length("req046_skill_anticipation"):
			var age:float=lab.age[1]
			var pre:float=age-delta
			var back:=FOREST_RETREAT_DIST*(smoothstep(FOREST_RETREAT_AT,FOREST_RETREAT_END,age)-smoothstep(FOREST_RETREAT_AT,FOREST_RETREAT_END,pre))
			desired[side]-=toward*back
		elif key in ["attack","skill","chain"] or (uram_pair and key=="counter"):
			var forward:=maxf(0,float(roots[side].z-previous_root[side].z))*1.24
			var safe:=1.75 if side==0 and key=="skill" else 1.85 if key=="chain" else .85
			if side==1 and key=="attack" and lab.age[side]<actors[side].duration*.55:
				forward=maxf(forward,minf(maxf(0,distance-1.15),delta*2.4))
			if side==1 and key=="skill":
				var charge_age:float=lab.age[1]-actors[1].preview.length("req046_skill_anticipation")
				if charge_age>=0 and charge_age<.62 and not consumed[1]:
					# Plant during the warning; advance only with the headbutt.
					var drive:=lerpf(8.0,12.4,smoothstep(0,.07,charge_age)) if uram_forest_pair else lerpf(7.0,8.4,smoothstep(0,.10,charge_age))
					forward=maxf(forward,minf(maxf(0,distance-.95),delta*drive))
			if uram_pair and side==0:
				if key=="chain":forward=0.0
				elif key=="counter":
					# The forest counter is a planted shield motion, not a chase
					# followed by a second backstep. Other targets keep their path.
					forward=0.0 if uram_forest_pair else maxf(forward,1.8*delta)
					safe=1.10
				else:forward=maxf(forward,(3.5 if uram_forest_pair else 2.0)*delta if lab.age[0]<actors[0].duration*.55 else 0.0);safe=1.38
			if saebom_pair and side==0:
				forward=0.0
				if key=="skill" and bom_hop>0.:
					var hop:=bom_hop*saebom_hop_envelope(float(lab.age[0])/maxf(.01,float(actors[0].duration)))
					desired[0]+=bom_dir*(hop-bom_prev);bom_prev=hop
			if uram_forest_pair and side==0 and key in ["attack","skill"]:
				var walked:float=uram_floor_trace_advance if planted else (bodies[0].position-action_origin[0]).dot(direction)
				forward=minf(forward,maxf(0.,(.50 if key=="attack" else 1.345)-walked))
			if planted and side==0:
				# Keep former advancing weapon reach only as a non-rendered,
				# bounded hit trace. The physical boot/root never follows it.
				uram_floor_trace_advance+=minf(forward,maxf(0.,distance-uram_floor_trace_advance-safe))
			else:desired[side]+=toward*minf(forward,maxf(0,distance-safe))
		previous_root[side]=roots[side]
		if key=="death":knockback[side]=Vector3.ZERO
		desired[side]+=knockback[side]*delta
		knockback[side]=knockback[side].move_toward(Vector3.ZERO,delta*5)
	if uram_forest_pair and not lab.approach_active and not lab._local_ram_busy() and (lab.motion[0]=="attack" or (lab.motion[1]=="attack" and lab.motion[0]!="skill")):
		_limit_local_basic_closure(desired)
	resolve_bodies(desired,old_centers,old_guards)
	if uram_forest_pair and uram_basic_anchor and lab.motion[0] in ["attack","walk"]:_limit_uram_visible_boots()
	var events:Array[Dictionary]=[]
	for side in 2:
		var now:=weapon_point(side)
		var target:=hurt_capsule(1-side)
		var key:String=lab.motion[side]
		var length:float=actors[side].duration
		var opens:float=length*(.24 if key=="attack" else .31)
		var closes:float=length*(.70 if key=="attack" else .74)
		if uram_pair and side==0 and key=="counter":
			opens=.34;closes=minf(length,.58)
		if side==1 and key=="skill":
			opens=actors[side].preview.length("req046_skill_anticipation");closes=length*.94
		var prior_age:float=prior_han_age if side==0 and prior_han_age>=0 else lab.age[side]-delta
		var age_span:=maxf(.000001,lab.age[side]-prior_age)
		var active:bool=lab.age[side]>=opens and prior_age<=closes
		var committed_basic:=uram_forest_pair and key=="attack"
		var impact:=.261 if side==0 else length*.53
		if committed_basic:active=prior_age<impact and lab.age[side]>=impact
		var can_strike:=key in ["attack","skill","chain"]
		if uram_pair and side==0:can_strike=key in ["attack","skill","counter"]
		if saebom_pair and side==0:can_strike=bom_shove and key=="attack"
		if not lab.approach_active and can_strike and not consumed[side] and active and lab.rules.living():
			# Substeps follow articulated motion; relative target travel is included.
			var shift:Vector3=(target.a+target.b-old_hurt[1-side].a-old_hurt[1-side].b)*.5
			var start_fraction:=clampf((opens-prior_age)/age_span,0,1)
			var end_fraction:=clampf((closes-prior_age)/age_span,0,1)
			var from:Vector3=(old_weapon[side]+shift).lerp(now,start_fraction)
			var to:Vector3=(old_weapon[side]+shift).lerp(now,end_fraction)
			var t:=capsule_hit(from,to,target.a,target.b,float(target.radius)+WEAPON_RADIUS)
			if planted and side==0:
				var axis:Vector3=(bodies[1].position-bodies[0].position)*Vector3(1,0,1)
				axis=axis.normalized()
				var old_trace:=old_floor_tip+axis*old_floor_advance
				var trace:=uram_floor_original_tip+axis*uram_floor_trace_advance
				from=(old_trace+shift).lerp(trace,start_fraction)
				to=(old_trace+shift).lerp(trace,end_fraction)
				t=capsule_hit(from,to,target.a,target.b,float(target.radius)+WEAPON_RADIUS)
			if uram_pair and side==0:
				var head_hurt:=boar_head_hurt()
				var head_shift:Vector3=(head_hurt.a+head_hurt.b-old_boar_head.a-old_boar_head.b)*.5
				var hf:Vector3=(old_weapon[side]+head_shift).lerp(now,start_fraction)
				var ht:Vector3=(old_weapon[side]+head_shift).lerp(now,end_fraction)
				if planted and side==0:
					var axis:Vector3=((bodies[1].position-bodies[0].position)*Vector3(1,0,1)).normalized()
					var old_trace:=old_floor_tip+axis*old_floor_advance
					var trace:=uram_floor_original_tip+axis*uram_floor_trace_advance
					hf=(old_trace+head_shift).lerp(trace,start_fraction)
					ht=(old_trace+head_shift).lerp(trace,end_fraction)
				var hit_head:=capsule_hit(hf,ht,head_hurt.a,head_hurt.b,float(head_hurt.radius)+WEAPON_RADIUS)
				if hit_head<t:
					t=hit_head;target=head_hurt;from=hf;to=ht
			if uram_pair and side==0 and key=="counter":
				var live_face:=_shield_transform()
				var dimensions:Vector2=actors[0].preview.shield.mesh.size
				for offset in [Vector3(0,-dimensions.y*.38,.035),Vector3(-dimensions.x*.24,-dimensions.y*.32,.035),Vector3(dimensions.x*.24,-dimensions.y*.32,.035)]:
					for envelope in [hurt_capsule(1),boar_head_hurt()]:
						var old_envelope:Dictionary=old_boar_head if envelope.radius<.30 else old_hurt[1]
						var shift_rim:Vector3=(envelope.a+envelope.b-old_envelope.a-old_envelope.b)*.5
						var previous_rim:Vector3=old_shield*offset+shift_rim
						var live_rim:Vector3=live_face*offset
						var rim_from:=previous_rim.lerp(live_rim,start_fraction)
						var rim_to:=previous_rim.lerp(live_rim,end_fraction)
						var hit_rim:=capsule_hit(rim_from,rim_to,envelope.a,envelope.b,float(envelope.radius)+WEAPON_RADIUS)
						if hit_rim<t:
							t=hit_rim;target=envelope;from=rim_from;to=rim_to
			var shield_kind:=false
			var late_profile:=Vector3.ZERO
			var late_pose:=false
			if uram_pair and side==1 and key=="skill" and lab.has_method("uram_guard_active") and lab.uram_guard_active():
				var current_shield:=_shield_transform()
				var half_size:Vector2=actors[0].preview.shield.mesh.size*.5
				var shield_from:=old_shield.interpolate_with(current_shield,start_fraction)
				var shield_to:=old_shield.interpolate_with(current_shield,end_fraction)
				# Use the upper muzzle rather than the boar's low central nose as the shield contact candidate.
				var crown_offset:=Vector3.UP*(.02 if uram_forest_pair else .10)
				var shield_t:=shield_sweep(old_weapon[side].lerp(now,start_fraction)+crown_offset,old_weapon[side].lerp(now,end_fraction)+crown_offset,shield_from,shield_to,half_size)
				# A final-tick guard can physically meet the length of the ram's
				# muzzle after its foremost probe has passed the extended face.
				# Only the same, not-yet-committed body hit can enter this priority.
				var final_guard:bool=uram_forest_pair and lab.age[0]<=delta+.001 and t!=INF
				if final_guard and shield_t==INF:
					var skull:=bone_world(1,"head")
					var horn_line:=(now-skull).normalized()
					for depth in [.12,.23,.34,.43]:
						var profile:Vector3=horn_line*float(depth)
						var first:Vector3=old_weapon[side].lerp(now,start_fraction)+crown_offset-profile
						var last:Vector3=old_weapon[side].lerp(now,end_fraction)+crown_offset-profile
						var candidate:=shield_sweep(first,last,shield_to,shield_to,half_size)
						if candidate<shield_t:
							shield_t=candidate
							late_profile=profile
							late_pose=true
				if shield_t!=INF and (shield_t<=t or final_guard):
					t=minf(shield_t,t);shield_kind=true
			var authored_only:=committed_basic and t==INF
			if authored_only:t=clampf((impact-prior_age)/age_span,0.,1.)
			if t!=INF:
				consumed[side]=true
				var fraction:=lerpf(start_fraction,end_fraction,t)
				var probe:Vector3=from.lerp(to,t)
				var axis:Vector3=target.b-target.a
				var nearest:Vector3=target.a+axis*clampf((probe-target.a).dot(axis)/maxf(.0001,axis.length_squared()),0,1)
				var point:Vector3=now if authored_only else nearest+nearest.direction_to(probe)*float(target.radius)
				if shield_kind:
					probe=old_weapon[side].lerp(now,fraction)+Vector3.UP*(.02 if uram_forest_pair else .10)-late_profile
					var face:=_shield_transform() if late_pose else old_shield.interpolate_with(_shield_transform(),fraction)
					var local:=face.affine_inverse()*probe
					local.z=0.0;point=face*local
				var event:={"side":side,"motion":key,"point":point,"probe":probe,"hurt":target.duplicate(),"weapon_from":from,"weapon_to":to,"normal":(bodies[1-side].position-bodies[side].position).normalized(),"action":action_id[side],"time":lab.rules.elapsed-delta+fraction*delta,"attack_age":prior_age+fraction*age_span,"active_from":opens,"active_to":closes}
				if uram_pair:event["kind"]="shield" if shield_kind else "body"
				if committed_basic:
					event["committed_basic"]=true
					event["visual_contact"]=not authored_only
				if planted and side==0:uram_floor_hit=event
				else:events.append(event);contacts.append(event)
		previous_weapon[side]=now
	if planted and lab.age[0]>=URAM_FLOOR_CONTACT and not uram_floor_emitted:
		uram_floor_emitted=true
		uram_floor_emit_age=lab.age[0]
		lab._uram_ground_contact(uram_ground_screen_mark(camera,weapon_point(0),0.),bodies[1].position)
	if planted and not uram_floor_hit.is_empty() and uram_floor_emitted and lab.age[0]>=uram_floor_emit_age+URAM_FLOOR_TRAVEL:
		var event:=uram_floor_hit.duplicate()
		uram_floor_hit.clear()
		event.time=lab.rules.elapsed
		events.append(event);contacts.append(event)
	if knife_skill_active(lab.motion[0]) and lab.rules.living() and not lab.approach_active:
		while knife_beat<Knife.contacts.size() and lab.age[0]+.00001>=Knife.contacts[knife_beat]:
			var beat:=knife_beat
			knife_beat+=1
			if bodies[0].position.distance_to(bodies[1].position)>1.68:continue
			var edge:=Knife.shoulder(_knife_unit(1),body_screen(0))+Vector2(0.,[-2.,3.,-1.,0.][beat])
			var hit:Dictionary={"side":0,"motion":"skill","kind":"saebom_knife","beat":beat,"point":_knife_tip_world(edge),"normal":(bodies[1].position-bodies[0].position).normalized(),"action":action_id[0],"time":lab.rules.elapsed-delta+clampf((Knife.contacts[beat]-float(lab.age[0])+delta)/maxf(.0001,delta),0.,1.)*delta}
			events.append(hit)
			if beat==3:contacts.append(hit)
	if saebom_pair:
		var hit:=_projectile_step(lab,delta,old_hurt[1],old_weapon[0],prior_han_age if prior_han_age>=0 else lab.age[0]-delta)
		if not hit.is_empty():events.append(hit);contacts.append(hit)
	events.sort_custom(func(first,second):return first.time<second.time)
	return events

const URAM_PAIR_GAP:=2.22
const URAM_FOREST_GAP:=2.82
const LOCAL_BASIC_START:=[2.90,3.02]
const LOCAL_BASIC_READY_MIN:=2.34
const LOCAL_BASIC_CONTACT_MIN:=2.29
const FOREST_RETREAT_DIST:=.69
const FOREST_RETREAT_AT:=.01
const FOREST_RETREAT_END:=.53
const FOREST_RAISED_AT:=.68
const FOREST_PLANT_AT:=1.68
var uram_pair:=false
var uram_forest_pair:=false

func capture_forest_shield_input_face()->void:
	forest_input_face=_shield_transform()
	forest_input_pending=true
	var line:=bodies[0].position.direction_to(bodies[1].position)
	var muzzle_depth:float=(weapon_point(1)-bodies[0].position).dot(line)
	# At the end of a ram the incoming nose can already be inside the fully
	# extended guard's depth. Raise the same arm as a tight, visible close guard.
	forest_guard_close_brace=muzzle_depth<.65

func _shield_transform()->Transform3D:
	var shield:MeshInstance3D=actors[0].preview.shield
	return shield.global_transform

static func shield_sweep(old_probe:Vector3,new_probe:Vector3,old_face:Transform3D,new_face:Transform3D,half_size:Vector2)->float:
	var a:=old_face.affine_inverse()*old_probe
	var b:=new_face.affine_inverse()*new_probe
	# Only approach the visible outer face, including first active surface overlap.
	const NOSE_RADIUS:=.15
	if a.z < -NOSE_RADIUS or b.z>a.z+.0001:return INF
	if b.z>NOSE_RADIUS:return INF
	var t:=0.0 if a.z<=NOSE_RADIUS else (a.z-NOSE_RADIUS)/(a.z-b.z)
	var at:=a.lerp(b,t)
	var radial:=Vector2(at.x,at.y)/(half_size+Vector2.ONE*NOSE_RADIUS)
	return t if radial.length_squared()<=1.0 else INF

func boar_head_hurt()->Dictionary:
	var crown:=bone_world(1,"head")
	var muzzle:=weapon_point(1)
	# A short head capsule joins poll and muzzle; the trunk stays independent.
	return {"a":crown-Vector3.UP*.04,"b":crown.lerp(muzzle,.64),"radius":.27}

func _blend_forest_backstep(p,at:float,weight:float)->void:
	_blend_forest_pose(p,p.animation.get_animation("walk"),at*p.motion_rate("walk"),weight)

func _blend_forest_pose(p,gait:Animation,native_at:float,weight:float)->void:
	if gait==null or weight<=0.:return
	var sk:Skeleton3D=p.skeleton
	for i in gait.get_track_count():
		var path:=gait.track_get_path(i)
		if path.get_subname_count()!=1:continue
		var bone:=sk.find_bone(str(path.get_subname(0)))
		if bone<0:continue
		if gait.track_get_type(i)==Animation.TYPE_ROTATION_3D:
			sk.set_bone_pose_rotation(bone,sk.get_bone_pose_rotation(bone).slerp(gait.rotation_track_interpolate(i,native_at),weight))
		elif gait.track_get_type(i)==Animation.TYPE_POSITION_3D and bone!=p.root_index:
			sk.set_bone_pose_position(bone,sk.get_bone_pose_position(bone).lerp(gait.position_track_interpolate(i,native_at),weight))

func _capture_uram_feet()->void:
	var sk:Skeleton3D=actors[0].preview.skeleton
	uram_planted_feet.clear()
	for label in ["foot.R","foot.L"]:
		var foot:=sk.find_bone(label)
		if foot<0:continue
		var knee:=sk.get_bone_parent(foot)
		var thigh:=sk.get_bone_parent(knee) if knee>=0 else -1
		# Keep the captured pose of the whole planted leg, in parent-to-child order.
		for joint in [thigh,knee,foot]:
			if joint>=0:uram_planted_feet[joint]=sk.global_transform*sk.get_bone_global_pose(joint)

## The hit clip releases the planted legs; hold only their planar display
## correction briefly. Contact sweeps never use this transient display pose.
const URAM_RAM_FEET_RELEASE := .10
var uram_ram_visual_anchors:Dictionary={}
var uram_ram_visual_restore:Dictionary={}
var uram_ram_hit_origin:=Vector3.ZERO

func capture_uram_ram_hit_pose()->void:
	if not uram_forest_pair or uram_planted_feet.is_empty():return
	uram_ram_visual_anchors=uram_planted_feet.duplicate()
	uram_ram_hit_origin=bodies[0].position

func restore_uram_ram_display()->void:
	if uram_ram_visual_restore.is_empty():return
	var sk:Skeleton3D=actors[0].preview.skeleton
	for joint in uram_ram_visual_restore:
		sk.set_bone_pose_position(joint,uram_ram_visual_restore[joint])
	sk.force_update_all_bone_transforms()
	uram_ram_visual_restore.clear()

func present_uram_ram_hit_pose(key:String,age:float)->void:
	if uram_ram_visual_anchors.is_empty():return
	if key!="hit" or age>=URAM_RAM_FEET_RELEASE:
		uram_ram_visual_anchors.clear()
		return
	var sk:Skeleton3D=actors[0].preview.skeleton
	var weight:=1.0-smoothstep(0.0,URAM_RAM_FEET_RELEASE,age)
	var drift:=bodies[0].position-uram_ram_hit_origin
	drift.y=0.0
	var targets:Dictionary={}
	for joint in uram_ram_visual_anchors:
		var current:Transform3D=sk.global_transform*sk.get_bone_global_pose(joint)
		var goal:Vector3=uram_ram_visual_anchors[joint].origin+drift
		current.origin.x=lerpf(current.origin.x,goal.x,weight)
		current.origin.z=lerpf(current.origin.z,goal.z,weight)
		targets[joint]=sk.global_transform.affine_inverse()*current
		uram_ram_visual_restore[joint]=sk.get_bone_pose_position(joint)
	for joint in targets:
		sk.set_bone_global_pose(joint,targets[joint])
	sk.force_update_all_bone_transforms()

# Overlay the visible rig after all combat work and unwind before the next sweep.
# Never let this continuity correction enter the contact or sweep pose.
var uram_intake_age := -1.0
var uram_intake_ordinary := false
var uram_intake_seeds:Dictionary={}
var uram_displayed_feet:Dictionary={}
var uram_return_age := -1.0
var uram_return_pose:Dictionary={}
var uram_last_drawn_hit:Dictionary={}
var uram_last_drawn_hit_height:=0.0
var uram_return_height:=0.0
var uram_intake_restore_height:=INF
var uram_intake_restore:Dictionary={}
var uram_intake_props:Dictionary={}

func mark_uram_intake(at:float,ordinary:bool)->void:
	uram_intake_age=at
	uram_intake_ordinary=ordinary
	uram_return_age=-1.0
	uram_return_pose.clear()
	uram_intake_seeds.clear()
	uram_last_drawn_hit.clear()
	for label in ["foot.R","foot.L"]:
		uram_intake_seeds[label]=uram_displayed_feet.get(label,bone_world(0,label)-bodies[0].position)

func mark_uram_intake_recovery(at:float)->void:
	if uram_intake_age<0.0:return
	uram_return_pose=uram_last_drawn_hit.duplicate()
	uram_return_height=uram_last_drawn_hit_height
	uram_last_drawn_hit.clear()
	uram_return_age=at

func _save_uram_intake_pose(sk:Skeleton3D,joint:int)->void:
	if not uram_intake_restore.has(joint):
		uram_intake_restore[joint]=[sk.get_bone_pose_position(joint),sk.get_bone_pose_rotation(joint),sk.get_bone_pose_scale(joint)]

func restore_uram_intake_display()->void:
	if uram_intake_restore.is_empty():return
	var p=actors[0].preview
	if is_finite(uram_intake_restore_height):
		p.pivot.position.y=uram_intake_restore_height
		uram_intake_restore_height=INF
	var sk:Skeleton3D=p.skeleton
	for joint in uram_intake_restore:
		var v:Array=uram_intake_restore[joint]
		sk.set_bone_pose_position(joint,v[0])
		sk.set_bone_pose_rotation(joint,v[1])
		sk.set_bone_pose_scale(joint,v[2])
	sk.force_update_all_bone_transforms()
	for prop in uram_intake_props:
		if is_instance_valid(prop):prop.global_transform=uram_intake_props[prop]
	uram_intake_restore.clear()
	uram_intake_props.clear()

func present_uram_intake(at:float,key:String)->void:
	for label in ["foot.R","foot.L"]:
		uram_displayed_feet[label]=bone_world(0,label)-bodies[0].position
	if uram_intake_age<0.0:return
	if key not in ["walk","hit","idle"]:
		uram_intake_age=-1.0;uram_return_age=-1.0;uram_return_pose.clear()
		return
	if key=="hit":
		# The motion adapter can already sample idle during the transition
		# substep, so take the last actual rendered hit rather than that pose.
		var shown:Skeleton3D=actors[0].preview.skeleton
		uram_last_drawn_hit_height=actors[0].preview.pivot.position.y
		uram_last_drawn_hit.clear()
		for joint in shown.get_bone_count():
			uram_last_drawn_hit[joint]=[shown.get_bone_pose_position(joint),shown.get_bone_pose_rotation(joint)]
	var since:=at-uram_intake_age
	var weight:=smoothstep(0.0,.038,since)*(1.0-smoothstep(.08,.21,since)) if uram_intake_ordinary else 0.0
	var recover:=1.0-smoothstep(0.0,.16,at-uram_return_age) if uram_return_age>=0.0 else 0.0
	if weight<=.0001 and recover<=.0001:
		if uram_return_age>=0.0 or since>.80:uram_intake_age=-1.0;uram_return_age=-1.0;uram_return_pose.clear()
		return
	var p=actors[0].preview
	var sk:Skeleton3D=p.skeleton
	var old_wrists:Dictionary={}
	for entry in [[p.shield,"hand.L"],[p.club,"hand.R"]]:
		var prop:MeshInstance3D=entry[0]
		var wrist:=sk.find_bone(entry[1])
		if not is_instance_valid(prop) or wrist<0:continue
		uram_intake_props[prop]=prop.global_transform
		old_wrists[prop]=[wrist,sk.global_transform*sk.get_bone_global_pose(wrist)]
	if recover>.0001 and not uram_return_pose.is_empty():
		uram_intake_restore_height=p.pivot.position.y
		p.pivot.position.y=lerpf(p.pivot.position.y,uram_return_height,recover)
		for joint in uram_return_pose:
			_save_uram_intake_pose(sk,joint)
			var from:Array=uram_return_pose[joint]
			sk.set_bone_pose_position(joint,sk.get_bone_pose_position(joint).lerp(from[0],recover))
			sk.set_bone_pose_rotation(joint,sk.get_bone_pose_rotation(joint).slerp(from[1],recover))
	if weight>.0001:
		var spine:=sk.find_bone("spine")
		if spine>=0:
			_save_uram_intake_pose(sk,spine)
			var q:=sk.get_bone_pose_rotation(spine)
			sk.set_bone_pose_rotation(spine,q*Quaternion(Vector3.RIGHT,-.105*weight))
		sk.force_update_all_bone_transforms()
		var inv:=sk.global_transform.affine_inverse()
		for label in uram_intake_seeds:
			var joint:=sk.find_bone(label)
			if joint<0:continue
			var now:=sk.global_transform*sk.get_bone_global_pose(joint)
			var hold:Vector3=uram_intake_seeds[label]+bodies[0].position
			now.origin.x=lerpf(now.origin.x,hold.x,weight)
			now.origin.z=lerpf(now.origin.z,hold.z,weight)
			_save_uram_intake_pose(sk,joint)
			sk.set_bone_global_pose(joint,inv*now)
	sk.force_update_all_bone_transforms()
	for prop in old_wrists:
		var original:Array=old_wrists[prop]
		var wrist:=sk.global_transform*sk.get_bone_global_pose(original[0])
		prop.global_transform=wrist*(original[1] as Transform3D).affine_inverse()*uram_intake_props[prop]

# Uram's normal follow-through and its props are display-only. The swept
# collision rig always gets the unmodified gameplay pose on the next substep.
var uram_out_snapshot:Dictionary={}
var uram_out_bridge:Dictionary={}
var uram_out_restore:Dictionary={}
var uram_out_props:Dictionary={}
var uram_out_height:=0.0
var uram_out_bridge_height:=0.0
var uram_previous_animator_mode:=-1
var uram_out_stock_position:=Vector3.INF
var uram_last_drawn_return:Dictionary={}
var uram_return_contact_pose:Dictionary={}

func capture_uram_visible_return(key:String)->void:
	uram_last_drawn_return.clear()
	if not uram_forest_pair or key not in ["attack","walk"]:return
	for joint in ["pelvis","foot.R","foot.L"]:
		uram_last_drawn_return[joint]=bone_world(0,joint)-bodies[0].position
var uram_out_started:=-1.0
var uram_out_duration:=.14
var uram_out_basic_return:=false
var uram_trade_last_strike:=-INF
var uram_trade_pending_hit:=-INF
var uram_trade_at:=-INF
var uram_trade_feet:Dictionary={}
var uram_display_cuff:BoneAttachment3D
var uram_display_shield:MeshInstance3D
var uram_display_cuff_rest:=Transform3D.IDENTITY
var uram_hidden_stock_shield:=false

func _hide_uram_display_cuff()->void:
	if is_instance_valid(uram_display_shield):uram_display_shield.hide()
	if uram_hidden_stock_shield and not actors.is_empty() and is_instance_valid(actors[0].preview.shield):
		actors[0].preview.shield.show()
	uram_hidden_stock_shield=false

func _seat_uram_display_cuff(p,weight:float,idle_seat:Vector3)->void:
	var physical:MeshInstance3D=p.shield
	if weight<=.0001 or not physical.visible:return
	var sk:Skeleton3D=p.skeleton
	var index:=sk.find_bone("forearm.L")
	if index<0:return
	var forearm:Transform3D=sk.global_transform*sk.get_bone_global_pose(index)
	if not is_instance_valid(uram_display_cuff):
		uram_display_cuff=BoneAttachment3D.new()
		uram_display_cuff.bone_name="forearm.L"
		sk.add_child(uram_display_cuff)
		uram_display_shield=MeshInstance3D.new()
		uram_display_shield.mesh=physical.mesh
		uram_display_shield.cast_shadow=physical.cast_shadow
		uram_display_cuff.add_child(uram_display_shield)
		var n:Vector3=p.camera.global_basis.z.normalized()
		var vx:=Vector3.UP.cross(n).normalized()
		var center:=forearm.origin.lerp(bone_world(0,"hand.L"),.23)+n*.055
		uram_display_cuff_rest=forearm.affine_inverse()*Transform3D(Basis(vx,n.cross(vx),n),center)
	# The visible copy follows Skeleton3D bone updates; the original stays
	# available to every collision query at its unchanged transform.
	var current:=forearm.affine_inverse()*Transform3D(physical.global_basis,idle_seat)
	var target:=uram_display_cuff_rest
	uram_display_shield.transform=Transform3D(current.basis.orthonormalized().slerp(target.basis.orthonormalized(),weight).orthonormalized(),current.origin.lerp(target.origin,weight))
	uram_display_cuff.on_skeleton_update()
	physical.hide()
	uram_hidden_stock_shield=true
	uram_display_shield.show()

func mark_uram_outgoing_contact(at:float)->void:
	uram_trade_last_strike=at
	if at-uram_trade_pending_hit<=.018:
		_start_uram_trade_display(uram_trade_pending_hit)

func maybe_mark_uram_trade(at:float,key:String,age:float)->bool:
	var close_strike:=key=="attack" and age>=.23 and age<=.45
	var early_return:=key=="walk" and uram_out_basic_return and age<=.17
	if not close_strike and not early_return:return false
	uram_trade_pending_hit=at
	if at-uram_trade_last_strike<=(.19 if close_strike else .60):
		_start_uram_trade_display(at)
		return true
	return false

func _start_uram_trade_display(at:float)->void:
	uram_trade_at=at
	uram_trade_feet=uram_displayed_feet.duplicate()
	# This one contact reaction has display priority over a backstep bridge.
	uram_out_started=-1.0;uram_out_bridge.clear()

func mark_uram_outgoing_recovery(from:String,to:String,at:float)->void:
	var hit:bool=from=="attack" and to in ["walk","idle"] and consumed[0]
	var returning:=from=="walk" and to=="idle" and uram_out_basic_return
	if not hit and not returning:return
	uram_out_basic_return=to=="walk"
	if uram_out_snapshot.is_empty():return
	uram_out_bridge=uram_out_snapshot.duplicate()
	uram_out_bridge_height=uram_out_height
	uram_return_contact_pose=uram_last_drawn_return.duplicate()
	uram_out_started=at
	uram_out_duration=.17 if to=="walk" else .14

func restore_uram_outgoing_display()->void:
	_hide_uram_display_cuff()
	if uram_out_restore.is_empty() and uram_out_props.is_empty():return
	var p=actors[0].preview
	var sk:Skeleton3D=p.skeleton
	if uram_out_stock_position.is_finite():
		p.pivot.position=uram_out_stock_position
		uram_out_stock_position=Vector3.INF
	for joint in uram_out_restore:
		var saved:Array=uram_out_restore[joint]
		sk.set_bone_pose_position(joint,saved[0])
		sk.set_bone_pose_rotation(joint,saved[1])
	sk.force_update_all_bone_transforms()
	for prop in uram_out_props:
		if is_instance_valid(prop):prop.global_transform=uram_out_props[prop]
	uram_out_restore.clear()
	uram_out_props.clear()

func present_uram_outgoing(at:float,key:String,age:float)->void:
	if not uram_forest_pair:return
	var p=actors[0].preview
	var sk:Skeleton3D=p.skeleton
	if key not in ["attack","walk","idle","run"] or (not uram_intake_restore.is_empty() and key!="walk"):
		if key not in ["walk","idle"]:
			uram_out_started=-1.0;uram_out_bridge.clear()
			uram_out_basic_return=false
		return
	var trade_age:=at-uram_trade_at
	var trade_weight:=smoothstep(0.0,.047,trade_age)*(1.0-smoothstep(.08,.21,trade_age))
	if uram_out_started>=0.0 and key in ["walk","idle"] and uram_intake_restore.is_empty() and trade_weight<=.0001:
		var carry:=1.0-smoothstep(0.0,uram_out_duration,at-uram_out_started)
		if carry>.0001:
			uram_out_stock_position=p.pivot.position
			p.pivot.position.y=lerpf(p.pivot.position.y,uram_out_bridge_height,carry)
			for joint in uram_out_bridge:
				var from:Array=uram_out_bridge[joint]
				var position:=sk.get_bone_pose_position(joint)
				var rotation:=sk.get_bone_pose_rotation(joint)
				uram_out_restore[joint]=[position,rotation]
				sk.set_bone_pose_position(joint,position.lerp(from[0],carry))
				sk.set_bone_pose_rotation(joint,rotation.slerp(from[1],carry))
			if uram_return_contact_pose.has("pelvis"):
				# Old joint blend was local; it lost the previous rendered rig's
				# solved position when the native animation switched. Maintain
				# the visible continuity relative to the unchanged physics body.
				sk.force_update_all_bone_transforms()
				var target:Vector3=bodies[0].position+uram_return_contact_pose.pelvis
				var offset:=((target-bone_world(0,"pelvis"))*carry).limit_length(.65)
				p.pivot.global_position+=offset
				sk.force_update_all_bone_transforms()
				for label in ["foot.R","foot.L"]:
					if not uram_return_contact_pose.has(label):continue
					var index:=sk.find_bone(label)
					if index<0:continue
					var transform:=sk.get_bone_global_pose(index)
					var goal:Vector3=sk.to_local(bodies[0].position+uram_return_contact_pose[label])
					transform.origin=transform.origin.lerp(goal,carry*.88)
					sk.set_bone_global_pose(index,transform)
		else:
			uram_out_started=-1.0;uram_out_bridge.clear()
	if trade_weight>.0001:
		# Just the head and shoulder receive the impact. Preserve the committed
		# strike and its clock, while keeping an extra footstep out of the pose.
		for entry in [["spine",.075],["head",.105]]:
			var joint:=sk.find_bone(entry[0])
			if joint<0:continue
			var q:=sk.get_bone_pose_rotation(joint)
			uram_out_restore[joint]=[sk.get_bone_pose_position(joint),q]
			sk.set_bone_pose_rotation(joint,q*Quaternion(Vector3.RIGHT,-float(entry[1])*trade_weight))
		sk.force_update_all_bone_transforms()
		for label in uram_trade_feet:
			var joint:=sk.find_bone(label)
			if joint<0:continue
			var source:=sk.get_bone_global_pose(joint)
			var anchor:Vector3=sk.to_local(bodies[0].position+uram_trade_feet[label])
			uram_out_restore[joint]=[sk.get_bone_pose_position(joint),sk.get_bone_pose_rotation(joint)]
			source.origin.x=lerpf(source.origin.x,anchor.x,trade_weight)
			source.origin.z=lerpf(source.origin.z,anchor.z,trade_weight)
			sk.set_bone_global_pose(joint,source)
	for prop in [p.club,p.shield]:
		if is_instance_valid(prop):uram_out_props[prop]=prop.global_transform
	sk.force_update_all_bone_transforms()
	# Reuse the authored grip and full normalization after the final bone evaluation.
	p.update_equipment()
	if is_instance_valid(p.shield):
		var wrist:=bone_world(0,"hand.L")
		var forearm:=bone_world(0,"forearm.L")
		var inward:Vector3=(bone_world(0,"spine")-wrist).normalized()
		var weight:float=smoothstep(.03,.105,age) if key=="attack" else (1.0-smoothstep(.10,.23,age) if key=="walk" else 0.0)
		var idle_seat:Vector3=wrist.lerp(forearm,.28)+inward*.12+p.shield.global_basis.z.normalized()*.035
		p.shield.global_position=idle_seat
		_seat_uram_display_cuff(p,weight,idle_seat)
	if key=="attack":_aim_uram_club(age)
	if key in ["attack","walk"]:
		uram_out_height=p.pivot.position.y
		uram_out_snapshot.clear()
		for joint in sk.get_bone_count():
			uram_out_snapshot[joint]=[sk.get_bone_pose_position(joint),sk.get_bone_pose_rotation(joint)]

func _keep_uram_feet_anchored(sk:Skeleton3D)->void:
	var inv:=sk.global_transform.affine_inverse()
	for joint in uram_planted_feet:
		sk.set_bone_global_pose(joint,inv*uram_planted_feet[joint])
		sk.force_update_all_bone_transforms()

func _aim_uram_forest_guard(sk:Skeleton3D,toward:Vector3,age:float,armed:bool)->void:
	# The tall deer hits higher than a boar. Bring the visible shield arm into
	# that lane while guarding; the exact same swept quad still decides contact.
	var weight:=1.0 if armed else 0.0
	if weight<=.001:return
	var palm:=sk.find_bone("hand.L")
	var elbow:=sk.find_bone("forearm.L")
	var shoulder:=sk.find_bone("upper.L")
	if palm<0 or elbow<0 or shoulder<0:return
	var target_world:=bodies[0].position+toward*(.22 if forest_guard_close_brace else .48)+Vector3.UP*(1.21 if forest_guard_close_brace else 1.32)
	var destination:=sk.to_local(target_world)
	for pass_index in 5:
		for joint in [elbow,shoulder,elbow]:
			var pivot:=sk.get_bone_global_pose(joint)
			var current:=sk.get_bone_global_pose(palm).origin-pivot.origin
			var desired:=destination-pivot.origin
			if current.length_squared()<.00001 or desired.length_squared()<.00001:continue
			var turn:=Quaternion.IDENTITY.slerp(Quaternion(current.normalized(),desired.normalized()),weight*.68)
			pivot.basis=Basis(turn)*pivot.basis
			sk.set_bone_global_pose(joint,pivot)
			sk.force_update_all_bone_transforms()

static func uram_floor_visible_age(age:float,contact:float,duration:float)->float:
	if contact<0. or age<=contact:return age
	var since:=age-contact
	if since<=URAM_FLOOR_HOLD:return contact
	var rest:=maxf(.001,duration-contact)
	var resume:=smoothstep(0.,1.,clampf((since-URAM_FLOOR_HOLD)/rest,0.,1.))
	return contact+rest*resume

static func uram_ground_screen_mark(cam:Camera3D,tip:Vector3,ground_y:float)->Vector3:
	# Orthographic stage: cast through a point just underneath the apparent
	# club tip, not directly down from the raised club at its physical x/z.
	var p:=cam.unproject_position(tip)+Vector2(0.,8.)
	var origin:=cam.project_ray_origin(p)
	var ray:=cam.project_ray_normal(p)
	if absf(ray.y)<.001:return Vector3(tip.x,ground_y,tip.z)
	return origin+ray*((ground_y-origin.y)/ray.y)

static func weight_uram_floor_pose(p,age:float)->void:
	# A small shoulder and upper-body compression: no root movement or foot offsets.
	var lead:=smoothstep(.58,.80,age)*(1.-smoothstep(.85,1.14,age))
	var press:=smoothstep(.74,URAM_FLOOR_CONTACT,age)*(1.-smoothstep(.89,1.19,age))
	var sk:Skeleton3D=p.skeleton
	var torso:=sk.find_bone("spine")
	if torso>=0:
		sk.set_bone_pose_rotation(torso,sk.get_bone_pose_rotation(torso)*Quaternion(Vector3.RIGHT,.095*lead+.035*press))
		sk.set_bone_pose_position(torso,sk.get_bone_pose_position(torso)+Vector3(0.,-.023,0.)*press)
	var shoulder:=sk.find_bone("upper.R")
	if shoulder>=0:
		sk.set_bone_pose_rotation(shoulder,sk.get_bone_pose_rotation(shoulder)*Quaternion(Vector3.RIGHT,.07*press))
	sk.force_update_all_bone_transforms()

static func aim_uram_floor_club(p,axis:Vector3,age:float,ground_y:=0.0)->void:
	var amount:=smoothstep(URAM_FLOOR_CONTACT-.10,URAM_FLOOR_CONTACT,age)*(1.-smoothstep(URAM_FLOOR_CONTACT+.085,URAM_FLOOR_CONTACT+.43,age))
	if amount<=.001 or axis.length_squared()<.1:return
	var sk:Skeleton3D=p.skeleton
	var hand:=sk.global_transform*sk.get_bone_global_pose(p.hand_bone)
	var grip:Vector3=hand*p.grip_in_hand
	var rel:Vector3=hand*p.tip_in_hand-grip
	if rel.length_squared()<.005:return
	var length:=.99
	var down:=minf(maxf(.0,grip.y-ground_y-.015)*.50,length*.62)
	var target:Vector3=axis*sqrt(maxf(.002,length*length-down*down))-Vector3.UP*down
	var rotate:=Basis(Quaternion.IDENTITY.slerp(Quaternion(rel.normalized(),target.normalized()),amount))
	# Pose the hand around the measured wrapped handle before attaching the prop.
	# A single grip transform controls both the knuckles and the club every frame.
	var basis:=rotate*hand.basis
	var posed:=Transform3D(basis,grip-basis*p.grip_in_hand)
	sk.set_bone_global_pose(p.hand_bone,sk.global_transform.affine_inverse()*posed)
	sk.force_update_all_bone_transforms()
	p.update_equipment()


func _aim_uram_club(age:float)->void:
	# Late aim lowers the fully visible club around its grip, not the hurt volume.
	var weight:=smoothstep(.18,.285,age)*(1.0-smoothstep(.32,.46,age)) if uram_forest_pair else smoothstep(.17,.249,age)*(1.0-smoothstep(.30,.43,age))
	if weight<=0.0:return
	var p=actors[0].preview
	var club:MeshInstance3D=p.club
	var sk:Skeleton3D=p.skeleton
	var grip:Vector3=sk.global_transform*sk.get_bone_global_pose(p.hand_bone)*p.grip_in_hand
	var from:=club.global_basis.x.normalized()
	var head:=bone_world(1,"head")
	var target:Vector3=(head.lerp(weapon_point(1),.42)-Vector3.UP*.12 if uram_forest_pair else head+Vector3.UP*.15)-grip
	if target.length()<.15:return
	var desired:=target.normalized()
	var axis:=from.cross(desired)
	if axis.length_squared()<.0001:return
	var angle:=minf(1.40 if uram_forest_pair else .64,from.angle_to(desired))*weight
	var turn:=Basis(axis.normalized(),angle)
	var tr:=club.global_transform
	tr=Transform3D(turn*tr.basis,grip+turn*(tr.origin-grip))
	club.global_transform=tr
const SAEBOM_GAP:=3.7
const SAEBOM_DEER_APPROACH_GAP:=1.98
const SLING_SKIN_RADIUS:=.066
const MotionTiming=preload("res://scripts/motion_timing.gd")
var saebom_pair:=false
var local_melee_polish:=false
var bom_close:=false
var bom_shove:=false
var bom_near_skill:=false
var knife_beat:=0
const Knife=preload("res://scripts/duel_saebom_stone_knife.gd")
var bom_hop:=0.
var bom_prev:=0.
var bom_dir:=Vector3.ZERO
static func saebom_close_at(gap:float,latched:bool,enter:float,leave:float)->bool:
	return gap<=(leave if latched else enter)
static func saebom_hop_envelope(p:float)->float:
	return smoothstep(0.,.26,p)*(1.-smoothstep(.79,1.,p))
static func saebom_hop_pose(actor,p:float,strength:float)->void:
	var rig=actor.preview
	var preload_lift:=smoothstep(0.,.08,p)*(1.-smoothstep(.08,.14,p))
	var landing:=smoothstep(.26,.32,p)*(1.-smoothstep(.33,.43,p))
	var launch:=sin(PI*clampf((p-.08)/.24,0.,1.))
	var return_lift:=sin(PI*clampf((p-.80)/.19,0.,1.))
	rig.pivot.position.y+=strength*(.16*launch+.085*return_lift-.038*(preload_lift+landing))
static func saebom_shove_pose(actor,p:float,target:Vector3=Vector3.INF)->void:
	actor.resident_sample("guard",clampf(p,0.,.99)*actor.span("guard")*.74)
	var sk:Skeleton3D=actor.preview.skeleton
	var pulse:=smoothstep(.15,.43,p)*(1.-smoothstep(.57,.92,p))
	for pair in [["upper.R",-.58],["forearm.R",.72]]:
		var j:=sk.find_bone(pair[0])
		if j>=0:sk.set_bone_pose_rotation(j,sk.get_bone_pose_rotation(j)*Quaternion(Vector3.RIGHT,float(pair[1])*pulse))
	sk.force_update_all_bone_transforms()
	if target!=Vector3.INF:_aim_saebom_palm(sk,target,pulse)

static func _aim_saebom_palm(sk:Skeleton3D,target:Vector3,pulse:float)->void:
	if pulse<=.01:return
	var palm:=sk.find_bone("hand.R")
	if palm<0:return
	var destination:=sk.to_local(target+Vector3.UP*.05)
	var elbow:=sk.get_bone_parent(palm)
	var upper:=sk.find_bone("upper.R")
	for pass_index in 4:
		for joint in [elbow,upper,elbow]:
			if joint<0:continue
			var pivot:=sk.get_bone_global_pose(joint)
			var current:=sk.get_bone_global_pose(palm).origin-pivot.origin
			var desired:=destination-pivot.origin
			if current.length_squared()<.00001 or desired.length_squared()<.00001:continue
			var align:=Quaternion(current.normalized(),desired.normalized())
			var turn:=Quaternion.IDENTITY.slerp(align,pulse*.65)
			pivot.basis=Basis(turn)*pivot.basis
			sk.set_bone_global_pose(joint,pivot)
			sk.force_update_all_bone_transforms()
var projectile:Dictionary={}
var projectile_releases:Array[Dictionary]=[]
var projectile_mesh:MeshInstance3D
var basic_rope_empty:=false
var embedded_stone:MeshInstance3D
var embedded_stone_visible:=true
var sling_visual_previous:=Vector3.ZERO

func _setup_projectile()->void:
	var mesh:=SphereMesh.new()
	mesh.radius=SLING_SKIN_RADIUS;mesh.height=SLING_SKIN_RADIUS*2
	mesh.radial_segments=9;mesh.rings=5
	var skin:=StandardMaterial3D.new()
	skin.albedo_color=Color("8d7766");skin.roughness=.73
	mesh.material=skin
	projectile_mesh=MeshInstance3D.new()
	projectile_mesh.name="SaebomFlightStone";projectile_mesh.mesh=mesh;projectile_mesh.hide()
	scene.add_child(projectile_mesh)
	for model in actors[0].preview.pivot.find_children("*","MeshInstance3D",true,false):
		var label:=String(model.name).to_lower()
		if "large stone" in label or "large_stone" in label:
			embedded_stone=model
			embedded_stone_visible=embedded_stone.visible
			break

func sling_point()->Vector3:
	return bone_world(0,"sling_stone")

static func sling_release_seconds(key:String)->float:
	# The heavy release is the pinned authored 3.566667s curve event, not .63 of the cast.
	if key=="skill":return 3.566667/MotionTiming.rate("saebom","sling_heavy")
	if key=="attack":return .48/MotionTiming.rate("saebom","basic_attack")
	return INF

func _restore_sling_stone()->void:
	if is_instance_valid(embedded_stone):embedded_stone.visible=embedded_stone_visible

func _end_projectile()->void:
	projectile.clear()
	if is_instance_valid(projectile_mesh):projectile_mesh.hide()

func _projectile_step(lab,delta:float,old_hurt:Dictionary,old_origin:Vector3,prior_age:float)->Dictionary:
	if not lab.rules.living():
		_end_projectile()
		return {}
	var begin_fraction:=0.0
	var key:String=lab.motion[0]
	var mark:=INF if (key=="attack" and bom_shove) or knife_skill_active(key) else sling_release_seconds(key)
	var age:float=lab.age[0]
	if lab.approach_active:return {}
	if key=="attack" and not bom_shove and not consumed[0] and age>.125 and age<mark:basic_rope_empty=false
	if key in ["skill","chain"]:basic_rope_empty=false
	if (key not in ["attack","skill"] or not consumed[0]) and not basic_rope_empty:_restore_sling_stone()
	elif is_instance_valid(embedded_stone):embedded_stone.hide()
	if not consumed[0] and mark!=INF and prior_age<=mark and age>=mark:
		begin_fraction=clampf((mark-prior_age)/maxf(.000001,age-prior_age),0,1)
		var point:=old_origin.lerp(sling_point(),begin_fraction)
		var target:=hurt_capsule(1)
		var aim:Vector3=target.a.lerp(target.b,.62)
		var heading:=aim-point
		var flight_speed:=15.0 if key=="skill" else 12.0
		var planar:=Vector3(heading.x,0,heading.z)
		var flight_time:=clampf(planar.length()/flight_speed,.075,.45)
		var velocity_planar:=planar.limit_length(flight_speed*flight_time)/flight_time
		# Aim only once. The airborne stone does not home, and reacts only to live intersections.
		var velocity:=velocity_planar+Vector3.UP*(heading.y/flight_time+1.9*flight_time)
		projectile={"position":point,"velocity":velocity,"motion":key,"action":action_id[0],"flight_age":0.0,"release_age":mark,"release_time":lab.rules.elapsed-delta+delta*begin_fraction}
		if key=="attack":basic_rope_empty=true
		projectile_releases.append({"position":point,"motion":key,"action":action_id[0],"time":projectile.release_time,"attack_age":mark})
		consumed[0]=true
		if is_instance_valid(embedded_stone):embedded_stone.hide()
		projectile_mesh.position=point
		projectile_mesh.show()
	if projectile.is_empty():return {}
	var dt:=delta*(1.0-begin_fraction)
	if dt<.000001:return {}
	var previous:Vector3=projectile.position
	var velocity:Vector3=projectile.velocity
	var down:=Vector3.DOWN*3.8
	var next:=previous+velocity*dt+down*dt*dt*.5
	var target:=hurt_capsule(1)
	var shift:Vector3=(target.a+target.b-old_hurt.a-old_hurt.b)*(.5*(1.0-begin_fraction))
	var from:=previous+shift
	var t:=capsule_hit(from,next,target.a,target.b,float(target.radius)+SLING_SKIN_RADIUS)
	if t!=INF:
		var axis:Vector3=target.b-target.a
		var local_probe:=from.lerp(next,t)
		var nearest:Vector3=target.a+axis*clampf((local_probe-target.a).dot(axis)/maxf(.000001,axis.length_squared()),0,1)
		var point:=nearest+nearest.direction_to(local_probe)*float(target.radius)
		var elapsed:=float(projectile.flight_age)+dt*t
		var hit:={"side":0,"kind":"projectile","motion":projectile.motion,"point":point,"probe":local_probe,"hurt":target.duplicate(),"weapon_from":from,"weapon_to":next,"normal":velocity.normalized(),"action":projectile.action,"time":float(projectile.release_time)+elapsed,"attack_age":float(projectile.release_age)+elapsed,"active_from":float(projectile.release_age),"active_to":float(projectile.release_age)+.50}
		_end_projectile()
		return hit
	projectile.position=next
	projectile.velocity=velocity+down*dt
	projectile.flight_age=float(projectile.flight_age)+dt
	projectile_mesh.position=next
	if next.y<.03 or float(projectile.flight_age)>.50:_end_projectile()
	return {}
