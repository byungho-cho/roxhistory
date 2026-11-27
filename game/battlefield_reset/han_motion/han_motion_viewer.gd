extends Control
class LateGripTick extends Node:
	var update_grip: Callable
	func _process(_delta: float) -> void:
		update_grip.call()

const BASE := "res://assets/characters/han-meshy-motion/"
var field
var model_dir := ""
var src: Skeleton3D
var rig: Skeleton3D
var ap: AnimationPlayer
var library: AnimationLibrary
var ages: Array[Dictionary] = []
var elapsed := 0.0
var bind_delta: Array[Basis] = []
var hip_ratio := 1.0
var dest_bind: Array[Transform3D] = []
var last_idle := ""
var ground_mesh:MeshInstance3D
func glb(name: String) -> Node3D:
	var gd := GLTFDocument.new()
	var gs := GLTFState.new()
	if gd.append_from_file(ProjectSettings.globalize_path(name) if name.begins_with("res://") else model_dir.path_join(name),gs) != OK:
		return null
	return gd.generate_scene(gs) as Node3D
func skeleton(n: Node) -> Skeleton3D:
	var a := n.find_children("*","Skeleton3D",true,false)
	return a[0] as Skeleton3D if not a.is_empty() else null
func measure(root_model: Node3D) -> AABB:
	var result := AABB()
	var valid := false
	for child: MeshInstance3D in root_model.find_children("*","MeshInstance3D",true,false):
		if not child.mesh:
			continue
		var a := root_model.global_transform.affine_inverse()*child.global_transform*child.get_aabb()
		result = result.merge(a) if valid else a
		valid = true
	return result
func reel_phase(label:String)->void:
	var index:=label.left(2).to_int()
	reel_back_carry=index>=1 and index<=8
	field.status_line.text=label

func _ready() -> void:
	if duel_binding:
		set_process(false)
		return
	var scene := load("res://battlefield_reset/first_hunt.tscn") as PackedScene
	field=scene.instantiate()
	add_child(field)
	var old: Node3D = field.han.get_child(0)
	field.han_anim.stop()
	src=skeleton(old)
	var old_box := measure(old)
	old.hide()
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var actor := (load("res://battlefield_reset/han_motion/Han-Battle-Ultra-Rigged-12k.glb") as PackedScene).instantiate() as Node3D
	if not actor or not src:
		printerr("FAIL cannot load old/new rig"); push_error("Han motion viewer operation failed"); return
	field.han.add_child(actor)
	rig=skeleton(actor)
	var extant := actor.find_children("*","AnimationPlayer",true,false)
	for p: AnimationPlayer in extant:
		p.stop()
		p.active=false
	if not rig:
		printerr("FAIL no new skeleton"); push_error("Han motion viewer operation failed"); return
	var new_box := measure(actor)
	if old_box.size.y<.01 or new_box.size.y<.01:
		printerr("FAIL missing model bounds"); push_error("Han motion viewer operation failed"); return
	var top := actor.to_local(rig.to_global(rig.get_bone_global_rest(rig.find_bone("head_end")).origin)).y
	var heel := actor.to_local(rig.to_global(rig.get_bone_global_rest(rig.find_bone("LeftToeBase")).origin)).y
	if top<.2 or top>5.0:
		printerr("FAIL model-unit normalization: ",top,", ",heel); push_error("Han motion viewer operation failed"); return
	var factor := old.scale.x*old_box.size.y/(top-maxf(heel-.022,0.0))
	actor.scale *= factor
	actor.position.y=-maxf(heel-.022,0.0)*actor.scale.y
	print("PASS world-unit normalization: ",top,", ",heel,", ",factor)
	var sh := src.find_bone("hips")
	var nh := rig.find_bone("Hips")
	if sh<0 or nh<0:
		printerr("FAIL missing hips"); push_error("Han motion viewer operation failed"); return
	hip_ratio=absf(rig.get_bone_global_rest(nh).origin.y)/maxf(.001,absf(src.get_bone_global_rest(sh).origin.y))
	print("PASS geometry ",old_box, " -> ",new_box,", factor ",actor.scale.x,", hips ratio ",hip_ratio,", bones ",rig.get_bone_count())
	ap=AnimationPlayer.new()
	actor.add_child(ap)
	library=(load("res://battlefield_reset/han_motion/han-action-library.res") as AnimationLibrary).duplicate(true) as AnimationLibrary
	ap.add_animation_library("",library)
	field.field.msaa_3d=Viewport.MSAA_4X
	custom_filter(actor)
	ground_mesh=actor.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
	make_blade()
	if not install_grip_shape(actor): printerr("FAIL grip shape"); push_error("Han motion viewer operation failed"); return
	var grip_tick := LateGripTick.new()
	grip_tick.update_grip=sync_basic_grip
	grip_tick.process_priority=1000
	add_child(grip_tick)
	if not make_back_mount():
		printerr("FAIL cannot select back mount"); push_error("Han motion viewer operation failed"); return
	field.han_anim=ap
	field.paint.draw.connect(draw_effect)
	field.set_process(false)
	field.exit_requested.connect(func():exited.emit())
	field._reset()
	field.body_line.hide()
	for control in field.find_children("*","Button",true,false):
		for link in control.pressed.get_connections():
			if link.callable == field.request_exit:
				control.text="1:1로"
				break
	_build_motion_picker()
	setup_ok=true
	await _pick(1)
func custom_filter(actor:Node3D) -> void:
	for mesh in actor.find_children("*","MeshInstance3D",true,false):
		for i in range(mesh.get_surface_override_material_count()):
			var original = mesh.get_active_material(i)
			if not original is StandardMaterial3D:continue
			var m := original.duplicate() as StandardMaterial3D
			for entry in ["albedo_texture","normal_texture","roughness_texture","metallic_texture"]:
				var tex:Texture2D=m.get(entry)
				if not tex:continue
				var im:=tex.get_image()
				if not im:continue
				print("QA image ",entry," ",im.get_size()," mip=",im.has_mipmaps()," base filter ",m.texture_filter)
				if not im.has_mipmaps():
					if im.is_compressed():im.decompress()
					im.generate_mipmaps(entry=="normal_texture")
					m.set(entry,ImageTexture.create_from_image(im))
			m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mesh.set_surface_override_material(i,m)

var blade: Node3D
var hand_index := -1
var hand_local_basis := Basis.IDENTITY
var hand_local_offset := Vector3.ZERO
var qa_buttons: Array[Button] = []
var carry_blend:=1.0
var back_bone := -1
var back_offset := Vector3.ZERO
var back_basis := Basis.IDENTITY
var last_mount := ""
var reel_back_carry := true
var drawing := false
const LOW_GRIP := Vector3(0.,-.337,0.)*.90
var grip_enabled := false
var palm_local := Vector3.ZERO
var vfx_age := 1.0
var vfx_id := 0
var float_text := ""
var float_foe := true
var automated := true
var approach := false
var busy := false
var replay = []
var basics := 0

func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, tint: Color, sides := 8) -> void:
	var piece := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.radial_segments = sides
	cylinder.rings = 0
	cylinder.top_radius = radius * .93
	cylinder.bottom_radius = radius
	cylinder.height = a.distance_to(b)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = .88
	cylinder.material = mat
	piece.mesh = cylinder
	parent.add_child(piece)
	piece.position = (a+b)*.5
	piece.quaternion=Quaternion(Vector3.UP,(b-a).normalized())

func make_blade() -> void:

	var hand := rig.find_bone("RightHand")
	var finger := rig.find_bone("RightHandMiddle1")
	if finger<0:
		for b in range(rig.get_bone_count()):
			if rig.get_bone_parent(b)==hand:
				finger=b
				break
	var rest := rig.get_bone_global_rest(hand).basis.orthonormalized()
	var axis := rest.inverse()*Vector3.UP
	var f := Vector3.ZERO
	if finger>=0:
		f=rig.get_bone_rest(finger).origin
		f= f.normalized() if f.length()>.01 else Vector3.ZERO
	if f!=Vector3.ZERO:
		axis=(axis-f*axis.dot(f)).normalized()
	blade=Node3D.new()
	field.han.add_child(blade)
	hand_local_offset=f*.052 if f!=Vector3.ZERO else rest.inverse() * (rig.get_bone_global_rest(hand).origin-rig.get_bone_global_rest(rig.find_bone("RightForeArm")).origin).normalized()*.033
	hand_index=hand
	hand_local_basis=Basis(Quaternion(Vector3.UP,axis))
	rod(blade,Vector3(0,-.40,0),Vector3(0,.215,0),.022,Color("7b5134"))
	for i in range(31):
		var a:=float(i)*.72
		var b:=float(i+1)*.72
		var ay:=lerpf(-.40,.205,float(i)/31.)
		var by:=lerpf(-.40,.205,float(i+1)/31.)
		rod(blade,Vector3(sin(a)*.024,ay,cos(a)*.024),Vector3(sin(b)*.024,by,cos(b)*.024),.004,Color("b98958"),5)
	for i in range(11):
		var a:=float(i)*.58
		var b:=float(i+1)*.58
		rod(blade,Vector3(sin(a)*.030,.145+i*.008,cos(a)*.030),Vector3(sin(b)*.030,.153+i*.008,cos(b)*.030),.007,Color("aa7546"),5)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := [Vector3(.017,.185,.02),Vector3(.059,.255,.026),Vector3(.065,.333,.025),Vector3(.044,.415,.018),Vector3(.002,.505,.002)]
	var points: Array[Vector3]=[]
	for i in range(rows.size()):
		var ring: Vector3=rows[i]
		for j in range(8):
			var q:=TAU*j/8.
			var y:= ring.y + (sin(float(i*4+j)*5.11)*.008 if i<4 else 0.)
			points.append(Vector3(cos(q)*ring.x,y,sin(q)*ring.z))
	for i in range(rows.size()-1):
		for j in range(8):
			var a:=i*8+j
			var b:=i*8+((j+1)%8)
			for inds in [[a,b,b+8],[a,b+8,a+8]]:
				var v:=.31+.08*sin(float(a)*21.0+float(inds[1]))+.03*cos(float(j))
				for k in inds:
					st.set_color(Color(v*1.23,v*.99,v*.87))
					st.add_vertex(points[k])
	st.generate_normals()
	var stone := MeshInstance3D.new()
	stone.name="LongFlintBlade"
	stone.mesh=st.commit()
	var m:=StandardMaterial3D.new()
	m.vertex_color_use_as_albedo=true
	m.roughness=.85
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	stone.material_override=m
	blade.add_child(stone)
	print("PASS equipment attached to ","RightHand"," axis ",axis," palm ",f)

func make_back_mount() -> bool:
	back_bone=rig.find_bone("Spine2")
	if back_bone<0: back_bone=rig.find_bone("Spine1")
	if back_bone<0: back_bone=rig.find_bone("Spine")
	var rh:=rig.find_bone("RightArm")
	var lh:=rig.find_bone("LeftArm")
	var foot:=rig.find_bone("LeftFoot")
	var toe:=rig.find_bone("LeftToeBase")
	if min(min(back_bone,rh),min(lh,min(foot,toe)))<0: return false
	var chest:=rig.get_bone_global_rest(back_bone)
	var inv:=chest.basis.orthonormalized().inverse()
	var right:=rig.get_bone_global_rest(rh).origin-rig.get_bone_global_rest(lh).origin
	right.y=0.0
	right=right.normalized()
	var forward:=right.cross(Vector3.UP).normalized()
	var toes:=rig.get_bone_global_rest(toe).origin-rig.get_bone_global_rest(foot).origin
	if forward.dot(toes)<0.0: forward=-forward
	back_offset=inv*(-forward*.174-Vector3.UP*.16)
	var up_axis:=(-Vector3.UP*.79-right*.61).normalized()
	var face_axis:=forward
	back_basis=Basis(inv*(up_axis.cross(face_axis)),inv*up_axis,inv*face_axis).orthonormalized()
	print("PASS back mount ",rig.get_bone_name(back_bone)," offset=",back_offset," forward=",forward)
	return true

func wait_for(seconds:float) -> void:
	await get_tree().create_timer(seconds).timeout

func start_interactive() -> void:
	if field.phase==3:
		field._reset()
		return
	if not busy and field.phase==0:
		await enter_battle()
		field.set_process(true)

func enter_battle() -> void:
	busy = true
	field.set_process(false)
	field._start_or_retry()
	field.status_line.text = "1-1 첫 사냥  ·  전투 한결 Ultra"
	var d_start:Vector3=field.deer.position
	var h_start:Vector3=field.han.position
	var gap:Vector3=d_start-h_start
	var unit:=gap.normalized()
	var distance:=maxf(0.,gap.length()-1.14)
	var h_end:=h_start+unit*(distance*.70)
	var d_end:=d_start-unit*(distance*.30)
	var h_near:=h_end-unit*.28
	var timeline:=0.
	for part in [["walk_native",.90,h_start.lerp(h_end,.30),d_start.lerp(d_end,.34),.18],
			["run_native",.79,h_near,d_start.lerp(d_end,.77),.16],
			["decel",.40,h_end,d_end,.15]]:
		var clip: Animation = ap.get_animation(part[0])
		clip.loop_mode=Animation.LOOP_LINEAR if part[0]!="decel" else Animation.LOOP_NONE
		if automated and part[0]!="walk_native": reel_phase("07  달리기" if part[0]=="run_native" else "08  달리다 걷기(정지)")
		ap.play(part[0],part[4])
		var t:=create_tween().set_parallel()
		t.tween_property(field.han,"position",part[2],part[1]).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if part[0]=="decel" else Tween.EASE_IN_OUT)
		t.tween_property(field.deer,"position",part[3],part[1])
		timeline+=part[1]
		await t.finished
	field.han.position=h_end
	field.deer.position=d_end
	field._face()
	field.phase=2
	play_clip(field.han_anim,["ready_idle"],true)
	play_clip(field.deer_anim,["req046_idle","idle"],true)
	field._refresh()
	print("PASS actual 1-1 viewport and walk → run → decel/stop; separation ",field.han.position.distance_to(field.deer.position))
	busy = false

func draw_effect() -> void:
	if field.field.size.x < 2: return
	if vfx_age > .38: return
	var t:=clampf(vfx_age/.38,0.,1.)
	var c:Control=field.paint
	var target:Node3D = field.deer if float_foe else field.han
	var focus:Vector2=field.camera.unproject_position(target.position + Vector3(0,.75,0))
	var origin:Vector2=field.camera.unproject_position(field.han.position + Vector3(0,.90,0))
	var heading: float = origin.angle_to_point(focus)
	var colors := [Color("ffdd93"),Color("ffe191"),Color("9cd6ff"),Color("ffbc62")]
	var col:Color=colors[vfx_id]
	var fade:=1.-t
	if vfx_id==2 or vfx_id==3:
		var center:=origin.lerp(focus,smoothstep(0.,.68,t))
		var theta:=heading+(-.54 if vfx_id==2 else .43)
		var radius:=(25. if vfx_id==2 else 46.)+t*10.
		c.draw_arc(center,radius,theta-1.0,theta+1.0,32,Color(col,.21*fade),13.,true)
		c.draw_arc(center,radius,theta-1.0,theta+1.0,32,Color(col,.91*fade),3.,true)
	for i in range(6):
		var d:=Vector2.from_angle(float(i)*TAU/6.+.17)
		var k:=lerpf(6.,33.,t)
		c.draw_line(focus+d*k*.62,focus+d*k,Color(col,fade),2.4,true)
	var font:Font=field.theme.default_font
	var origin_text:=focus+Vector2(-14.,-27.-t*33.)
	c.draw_string_outline(font,origin_text,float_text,HORIZONTAL_ALIGNMENT_LEFT,-1.,22,5,Color("#27180e"))
	c.draw_string(font,origin_text,float_text,HORIZONTAL_ALIGNMENT_LEFT,-1.,22,col)

func effect(n:int, foe:bool, delta:int) -> void:
	vfx_age=0.
	vfx_id=n
	float_foe=foe
	float_text="−%d" % delta
	field.impact_pulse=.35
	field.last_target=1 if foe else 0
	field._refresh()
	field.status_line.text="1-1 첫 사냥  ·  "+(["사슴 반격","평타","2SP 테스트","3SP 테스트"][n])
	replay.append([n,delta,field.han_hp,field.deer_hp])
	print("PASS contact ",n," damage ",delta," HP ",field.han_hp,"/",field.deer_hp)

var grip_worst := 0.0
var grip_samples := 0
var max_grip_error := 0.0
var max_09_grip_error := 0.0
func sync_basic_grip() -> void:
	if not is_instance_valid(blade) or not grip_enabled or drawing or reel_back_carry: return
	if field.active_attacker!=0 or String(ap.current_animation)!="clear_basic": return
	rig.force_update_all_bone_transforms()
	var wrist := bone_world(hand_index)
	var palm := wrist.origin+wrist.basis.orthonormalized()*palm_local
	var old_gap := (blade.global_transform*Vector3(0.,-.337,0.)).distance_to(palm)
	grip_worst=maxf(grip_worst,old_gap)
	var original := blade.global_basis.orthonormalized()
	var shoulder:=bone_world(rig.find_bone("RightArm")).origin
	var height_weight:=smoothstep(.05,.24,wrist.origin.y-shoulder.y)
	var prep_weight:=1.-smoothstep(.23,.36,ap.current_animation_position)
	var forward:Vector3=field.deer.global_position-field.han.global_position
	forward.y=0.
	var lift:=(forward.normalized()*.94+Vector3.UP*.56).normalized()
	var corrected_axis:=original.y.lerp(lift,height_weight*prep_weight*.90).normalized()
	var orient:=Basis(Quaternion(original.y,corrected_axis))*original
	palm += palm_clearance(orient.y)*(1.-smoothstep(0.,.09,ap.current_animation_position))
	blade.global_transform=Transform3D(orient.scaled(Vector3.ONE*.90),palm-orient*LOW_GRIP)
	var gap := (blade.global_transform*Vector3(0.,-.337,0.)).distance_to(palm)
	max_grip_error=maxf(max_grip_error,gap)
	grip_samples+=1
	if grip_samples%6==0: print("QA basic grip before ",old_gap," after ",gap," windup ",height_weight*prep_weight)
	if gap>.001: printerr("FAIL late basic grip alignment")

func basic() -> void:
	field.attack_gate=0.0
	field._press_attack()
	var sent := false
	while field.active_attacker>=0:
		field._process(1.0/30.)
		if field.contact_done and not sent:
			effect(1,true,5)
			sent=true
		await get_tree().create_timer(1./30.).timeout
	print("QA basic grip max pre-render lag ",grip_worst," over ",grip_samples," frames")
	basics+=1
	field._refresh()

func skill(n:int) -> void:
	if busy or field.phase!=2 or field.active_attacker!=-1 or field.deer_hp<=0: return
	busy=true
	field.set_process(false)
	var key:="sp2" if n==2 else "sp3"
	var clip:=ap.get_animation(key)
	ap.play(key,.14)
	field.status_line.text="1-1 첫 사냥  ·  %dSP 테스트" % n
	field.attack_button.disabled=true
	var contact:=clip.length*(.50 if n==2 else .59)
	await wait_for(contact)
	var dmg:=mini(field.deer_hp,2)
	field.deer_hp-=dmg
	field.landed_hits+=1
	if n==3:
		effect(n,true,dmg)
		deer_slow_hit()
	else:
		play_clip(field.deer_anim,["hit_reaction"])
		effect(n,true,dmg)
	await wait_for(maxf(.22,clip.length-contact))
	play_clip(ap,["ready_idle"],true)
	play_clip(field.deer_anim,["req046_idle","idle"],true)
	if field.deer_hp<=0: field.phase=3
	field._refresh()
	field.elapsed=0.
	if not automated: field.set_process(true)
	busy=false

func lose_interactive() -> void:
	if busy or field.phase!=2 or field.active_attacker!=-1: return
	busy=true
	field.set_process(false)
	field.han_hp=3
	field._refresh()
	field.attack_gate=0.
	field._begin_attack(1)
	var sent:=false
	while field.active_attacker>=0:
		field._process(1./30.)
		if field.contact_done and not sent:
			effect(0,false,3)
			sent=true
		await get_tree().create_timer(1./30.).timeout
	ap.play("dead",.18)
	await wait_for(ap.get_animation("dead").length+.5)
	field._refresh()
	busy=false

func exact_ground() -> float:
	rig.force_update_all_bone_transforms()
	if not is_instance_valid(ground_mesh): return _story_support()
	var baked:=ground_mesh.bake_mesh_from_current_skeleton_pose()
	if baked==null or baked.get_surface_count()==0: return _story_support()
	var y:=INF
	for i in range(baked.get_surface_count()):
		var verts:PackedVector3Array=baked.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
		for v in verts: y=minf(y,(ground_mesh.global_transform*v).y)
	return y if is_finite(y) else _story_support()

func grounded_stand(t:float,anchor:Vector3,floor_level:float) -> void:
	ap.seek(t,true)
	field.han.position=anchor
	var correction:=clampf(floor_level-_story_support(),-.90,.90)
	field.han.position.y+=correction
	if Engine.get_process_frames()%15==0: print("QA measured rise ground correction ",correction)

func deer_slow_hit() -> void:
	var dp:AnimationPlayer=field.deer_anim
	var length:=play_clip(dp,["hit_reaction"])
	if length<=0.: return
	dp.advance(0.)
	dp.pause()
	var elapsed:=0.
	var time:=0.
	while time<length-.001:
		dp.seek(minf(time,length-.001),true)
		await get_tree().create_timer(1./30.).timeout
		elapsed+=1./30.
		time+=lerpf(.055,1.,smoothstep(0.,.72,elapsed))/30.
	print("QA 3SP deer hit speed .055 to 1.0, duration ",elapsed)

func prepare_local_hit_sample(key: String, t:float) -> void:
	ap.play(key,0.0)
	ap.advance(0.)
	ap.pause()
	ap.seek(t,true)
	rig.force_update_all_bone_transforms()

func number_13() -> void:
	reel_phase("13  일반 피격")
	print("QA isolated normal hit begin frame=",Engine.get_process_frames())
	var swing:=play_clip(field.deer_anim,["req046_basic_attack","attack"])
	var contact:=13.0/30.0
	await wait_for(contact)
	var anchor:Vector3=field.han.position
	var base:Array[Transform3D]=[]
	for i in range(rig.get_bone_count()): base.append(rig.get_bone_pose(i))
	var a:=ap.get_animation("normal_179")
	a.loop_mode=Animation.LOOP_NONE
	prepare_local_hit_sample("normal_179",0.)
	var end:=a.length
	var deer_idle:=false
	print("QA same-frame contact and #179 start frame=",Engine.get_process_frames())
	for f in range(ceili(end*30.)+1):
		var t:=minf(float(f)/30.,end)
		ap.seek(minf(t,end-.003),true)
		var w:=smoothstep(0.,.09,t)*(1.-smoothstep(maxf(.1,end-.22),end,t))
		for i in range(rig.get_bone_count()):
			var p:=rig.get_bone_pose(i)
			if rig.get_bone_name(i)=="Hips":
				p.origin.x=base[i].origin.x
				p.origin.z=base[i].origin.z
			rig.set_bone_pose(i,base[i].interpolate_with(p,w))
		field.han.position=anchor
		rig.force_update_all_bone_transforms()
		if not deer_idle and t>=maxf(.1,swing-contact):
			play_clip(field.deer_anim,["req046_idle","idle"],true)
			deer_idle=true
		await get_tree().create_timer(1./30.).timeout
	await wait_for(.35)
	print("PASS isolated Meshy #179 normal hit; end frame=",Engine.get_process_frames())

func number_14() -> void:
	reel_phase("14  큰 피격")
	print("QA isolated heavy hit begin frame=",Engine.get_process_frames())
	var swing:=play_clip(field.deer_anim,["req046_basic_attack","attack"])
	var contact:=13.0/30.0
	await wait_for(contact)
	var anchor:Vector3=field.han.position
	var base:Array[Transform3D]=[]
	for i in range(rig.get_bone_count()): base.append(rig.get_bone_pose(i))
	var a:=ap.get_animation("heavy_173")
	a.loop_mode=Animation.LOOP_NONE
	prepare_local_hit_sample("heavy_173",.72)
	var end:=1.03
	var deer_idle:=false
	print("QA source #173 span ",a.length," sampled range .72 to 1.55 only; contact frame=",Engine.get_process_frames())
	for f in range(ceili(end*30.)+1):
		var t:=minf(float(f)/30.,end)
		ap.seek(minf(.72+t*1.20,1.55),true)
		var w:=smoothstep(0.,.08,t)*(1.-smoothstep(.57,end,t))
		for i in range(rig.get_bone_count()):
			var p:=rig.get_bone_pose(i)
			if rig.get_bone_name(i)=="Hips":
				p.origin.x=base[i].origin.x
				p.origin.z=base[i].origin.z
			rig.set_bone_pose(i,base[i].interpolate_with(p,w))
		field.han.position=anchor
		rig.force_update_all_bone_transforms()
		if not deer_idle and t>=maxf(.1,swing-contact):
			play_clip(field.deer_anim,["req046_idle","idle"],true)
			deer_idle=true
		await get_tree().create_timer(1./30.).timeout
	await wait_for(.35)
	print("PASS isolated Meshy #173 first strike only; end frame=",Engine.get_process_frames())

func align_rest_legs(weight:float) -> float:
	var pelvis:=bone_world(rig.find_bone("Hips")).origin
	var chest:=bone_world(rig.find_bone("Spine")).origin
	var left_ankle:=bone_world(rig.find_bone("LeftFoot")).origin
	var ankle:=bone_world(rig.find_bone("RightFoot")).origin
	var body:=pelvis-chest
	body.y=0.
	var v:=ankle-pelvis
	var flat:=Vector3(v.x,0.,v.z)
	if body.length()<.11 or flat.length()<.2: return 0.
	var turn:=clampf(flat.normalized().signed_angle_to(body.normalized(),Vector3.UP)*.36,-.19,.19)*weight
	var goal:=pelvis+v.rotated(Vector3.UP,turn)
	goal.y=ankle.y
	if goal.distance_to(left_ankle)>.14: plant_leg("Right",goal)
	return turn
func number_15() -> void:
	reel_phase("15  큰 타격 → 넉다운")
	print("QA isolated impact knock begin frame=",Engine.get_process_frames())
	var swing:=play_clip(field.deer_anim,["req046_basic_attack","attack"])
	var contact:=13.0/30.0
	await wait_for(contact)
	print("QA single strike contact frame=",Engine.get_process_frames())
	var anchor:Vector3=field.han.position
	var away:Vector3=(anchor-field.deer.position).normalized()
	var hip:=rig.find_bone("Hips")
	var left0:=bone_world(rig.find_bone("LeftFoot")).origin
	var right0:=bone_world(rig.find_bone("RightFoot")).origin
	var max_comp:=0.
	var base_rot:Array[Quaternion]=[]
	var base_pos:Array[Vector3]=[]
	for j in range(rig.get_bone_count()):
		base_rot.append(rig.get_bone_pose_rotation(j))
		base_pos.append(rig.get_bone_pose_position(j))
	var impact:Array[Quaternion]=[]
	prepare_local_hit_sample("gahui_impact",.38)
	for j in range(rig.get_bone_count()):
		impact.append(rig.get_bone_pose_rotation(j))
	var upper: Array[String]=["Spine","Spine01","Spine02","neck","Head","LeftShoulder","RightShoulder","LeftArm","RightArm","LeftForeArm","RightForeArm","LeftHand","RightHand"]
	var ca:=ap.get_animation("knock_190")
	ca.loop_mode=Animation.LOOP_NONE
	var start:=.72
	var length:=ca.length-start
	prepare_local_hit_sample("knock_190",start)
	var hp0:=rig.get_bone_pose_position(hip)
	var deer_reset:=false
	var cap:=floori((length+.48)*30.)
	for f in range(cap):
		var age:=float(f)/30.
		var fall:=maxf(age-.025,0.)
		ap.seek(minf(start+fall,ca.length-.005),true)
		var w:=smoothstep(.015,.20,age)
		var punch:=.80*smoothstep(0.,.043,age)*(1.-smoothstep(.13,.31,age))
		for j in range(rig.get_bone_count()):
			var rp:=rig.get_bone_pose_rotation(j)
			var pp:=rig.get_bone_pose_position(j)
			if j==hip:
				pp=Vector3(base_pos[j].x,base_pos[j].y+pp.y-hp0.y,base_pos[j].z)
			var q:=base_rot[j].slerp(rp,w)
			if rig.get_bone_name(j) in upper: q=q.slerp(impact[j],punch)
			rig.set_bone_pose_rotation(j,q)
			rig.set_bone_pose_position(j,base_pos[j].lerp(pp,w))
		field.han.position=anchor+away*(.31*(1.-pow(1.-clampf(age/.34,0.,1.),2.2)))
		rig.force_update_all_bone_transforms()
		if age<.49:
			for entry in [["Left",left0],["Right",right0]]:
				var side:String=entry[0]
				var fixed:Vector3=entry[1]
				var a:=bone_world(rig.find_bone(side+"Foot")).origin
				var lifted:=maxf(0.,a.y-fixed.y)
				var lock_amt:float=(1.-smoothstep(.21,.47,age))*(1.-smoothstep(.035,.13,lifted))*.88
				var goal:=a.lerp(Vector3(fixed.x,a.y,fixed.z),lock_amt)
				max_comp=maxf(max_comp,goal.distance_to(a))
				if lock_amt>.002: plant_leg(side,goal)
		if age>1.90:
			var rest_yaw:=align_rest_legs(smoothstep(1.90,2.48,age))
			if f==cap-1: print("QA resting leg yaw degrees ",rad_to_deg(rest_yaw))
		if not deer_reset and age>=maxf(.1,swing-contact):
			play_clip(field.deer_anim,["req046_idle","idle"],true)
			deer_reset=true
		await get_tree().create_timer(1./30.).timeout
	print("QA maximum planted-foot correction ",max_comp); print("PASS one strike into knockdown with fixed field anchor; end frame=",Engine.get_process_frames())

func bone_world(i:int) -> Transform3D:
	return rig.global_transform*rig.get_bone_global_pose(i)

func aim_bone(i:int,child:int,target:Vector3) -> void:
	var pose:=rig.get_bone_global_pose(i)
	var from:=(rig.get_bone_global_pose(child).origin-pose.origin).normalized()
	var to:=(rig.to_local(target)-pose.origin).normalized()
	if from.length_squared()<.01 or to.length_squared()<.01: return
	var q:=Quaternion(from,to)
	var want:=Basis(q)*pose.basis.orthonormalized()
	var parent:=rig.get_bone_parent(i)
	var par:=rig.get_bone_global_pose(parent).basis.orthonormalized() if parent>=0 else Basis.IDENTITY
	rig.set_bone_pose_rotation(i,(par.inverse()*want).get_rotation_quaternion().normalized())
	rig.force_update_all_bone_transforms()

func guide_hand(goal:Vector3, out:Vector3, forward:Vector3) -> float:
	var up:=rig.find_bone("RightArm")
	var low:=rig.find_bone("RightForeArm")
	var a:=bone_world(up).origin
	var b:=bone_world(low).origin
	var c:=bone_world(hand_index).origin
	var l1:=a.distance_to(b)
	var l2:=b.distance_to(c)
	var delta:=goal-a
	var u:=delta.normalized()
	var length:=clampf(delta.length(),absf(l1-l2)+.002,l1+l2-.003)
	var pole:=out*.86+Vector3.DOWN*.34+forward*.19
	var ortho:=(pole-u*pole.dot(u)).normalized()
	var along:=(l1*l1-l2*l2+length*length)/(2.0*length)
	var bend:=sqrt(maxf(.0,l1*l1-along*along))
	aim_bone(up,low,a+u*along+ortho*bend)
	aim_bone(low,hand_index,a+u*length)
	return bone_world(hand_index).origin.distance_to(goal)

func smooth_path(a:Vector3,b:Vector3,c:Vector3,t:float)->Vector3:
	return a.lerp(b,t).lerp(b.lerp(c,t),t)

func narrower_feet() -> float:
	var left:=rig.find_bone("LeftFoot")
	var right:=rig.find_bone("RightFoot")
	var a:=bone_world(left).origin
	var b:=bone_world(right).origin
	var mid:=(a+b)*.5
	var ga:=a.lerp(mid,.20)
	var gb:=b.lerp(mid,.20)
	ga.y=a.y
	gb.y=b.y
	plant_leg("Left",ga)
	plant_leg("Right",gb)
	var x:=bone_world(left).origin-bone_world(right).origin
	return Vector2(x.x,x.z).length()/maxf(.0001,Vector2(a.x-b.x,a.z-b.z).length())

func plant_leg(side:String,target:Vector3) -> void:
	var top:=rig.find_bone(side+"UpLeg")
	var knee:=rig.find_bone(side+"Leg")
	var foot:=rig.find_bone(side+"Foot")
	var facing:=bone_world(foot).basis.orthonormalized()
	var h:=bone_world(top).origin
	var k:=bone_world(knee).origin
	var f:=bone_world(foot).origin
	var ab:=h.distance_to(k)
	var bc:=k.distance_to(f)
	var axis:=(target-h).normalized()
	var length:=clampf(target.distance_to(h),absf(ab-bc)+.002,ab+bc-.002)
	var pole:=k-h
	pole=(pole-axis*pole.dot(axis)).normalized()
	var along:=(ab*ab-bc*bc+length*length)/(2.*length)
	var bend:=sqrt(maxf(0.,ab*ab-along*along))
	aim_bone(top,knee,h+axis*along+pole*bend)
	aim_bone(knee,foot,h+axis*length)
	var k_basis:=bone_world(knee).basis.orthonormalized()
	rig.set_bone_pose_rotation(foot,(k_basis.inverse()*facing).get_rotation_quaternion().normalized())
	rig.force_update_all_bone_transforms()

func ready_blade_axis() -> Vector3:
	var delta: Vector3 = field.deer.global_position-field.han.global_position if is_instance_valid(field.deer) else field.han.global_basis.z
	delta.y=0.0
	return (Vector3.UP*.72+delta.normalized()*.66).normalized()

func align_wrist_to_grip(weapon_basis: Basis, weight: float) -> void:
	var fore := bone_world(rig.get_bone_parent(hand_index)).basis.orthonormalized()
	var natural := bone_world(hand_index).basis.orthonormalized()
	var held_axis := weapon_basis.y.normalized()
	var modeled_axis := (natural*hand_local_basis.y).normalized()
	if held_axis.dot(modeled_axis)<0.0: held_axis=-held_axis
	var turn := Quaternion(modeled_axis,held_axis)
	var limited := Quaternion.IDENTITY.slerp(turn,minf(.62,deg_to_rad(32.0)/maxf(.001,turn.get_angle()))*weight)
	var aligned := Basis(limited)*natural
	rig.set_bone_pose_rotation(hand_index,(fore.inverse()*aligned).get_rotation_quaternion().normalized())
	rig.force_update_all_bone_transforms()

func palm_clearance(axis: Vector3) -> Vector3:
	var away: Vector3 = -field.camera.global_basis.z.normalized()
	var across := away-axis*away.dot(axis)
	return across.normalized()*.042 if across.length_squared()>.001 else Vector3.ZERO

var grip_mesh: MeshInstance3D
func install_grip_shape(actor: Node3D) -> bool:
	grip_mesh=actor.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
	var src_mesh := grip_mesh.mesh as ArrayMesh
	if src_mesh == null or src_mesh.get_surface_count()!=1: return false
	var geo:=src_mesh.surface_get_arrays(0)
	var verts:PackedVector3Array=geo[Mesh.ARRAY_VERTEX]
	var norms:PackedVector3Array=geo[Mesh.ARRAY_NORMAL]
	var tangents:PackedFloat32Array=geo[Mesh.ARRAY_TANGENT]
	var joints:PackedInt32Array=geo[Mesh.ARRAY_BONES]
	var weights:PackedFloat32Array=geo[Mesh.ARRAY_WEIGHTS]
	var deltas:=PackedVector3Array()
	var nd:=PackedVector3Array()
	var td:=PackedFloat32Array()
	deltas.resize(verts.size())
	nd.resize(norms.size())
	td.resize(tangents.size())
	var hand:=rig.find_bone("RightHand")
	var bind_id:=-1
	for j in range(grip_mesh.skin.get_bind_count()):
		if grip_mesh.skin.get_bind_name(j)==&"RightHand" or grip_mesh.skin.get_bind_bone(j)==hand:
			bind_id=j
			break
	if bind_id<0: return false
	var frame:=rig.get_bone_global_rest(hand)
	var inv:=frame.affine_inverse()
	var stride:=int(joints.size()/verts.size())
	var points:=0
	var extent_min:=Vector3.ONE*1000.
	var extent_max:=-extent_min
	for i in range(verts.size()):
		var hand_weight:=0.0
		for k in range(stride):
			if joints[i*stride+k]==bind_id: hand_weight+=weights[i*stride+k]
		if hand_weight<.45: continue
		var local:=inv*(verts[i]*100.)
		extent_min=extent_min.min(local)
		extent_max=extent_max.max(local)
		if local.y<6.5 or local.y>28. or absf(local.z)>12. or absf(local.x)>13.: continue
		var thumb:=smoothstep(2.8,7.0,-local.x)
		var distal:=smoothstep(7.1,18.4,local.y)
		var curl:=2.03*distal*(1.-.66*thumb)
		var pivot:=Vector3(local.x,8.0,-.30)
		var turn:=Basis(Vector3.RIGHT,curl)
		var moved:=pivot+turn*(local-pivot)
		moved.x+=thumb*distal*2.9
		moved.z+=thumb*distal*1.2
		deltas[i]=(frame*moved*.01-verts[i])*hand_weight
		var rotated:=frame.basis*turn*frame.basis.inverse()
		nd[i]=((rotated*norms[i]).normalized()-norms[i])*hand_weight
		if td.size()>0:
			var t:=i*4
			var old:=Vector3(tangents[t],tangents[t+1],tangents[t+2])
			var change:Vector3=(rotated*old-old)*hand_weight
			td[t]=change.x
			td[t+1]=change.y
			td[t+2]=change.z
		points+=1
	print("QA right hand local extent: ",extent_min," to ",extent_max,"; curl vertices=",points)
	if points<25: return false
	var shape:=[]
	shape.resize(Mesh.ARRAY_MAX)
	shape[Mesh.ARRAY_VERTEX]=deltas
	shape[Mesh.ARRAY_NORMAL]=nd
	if td.size()>0: shape[Mesh.ARRAY_TANGENT]=td
	var corrected:=ArrayMesh.new()
	corrected.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_RELATIVE
	corrected.add_blend_shape("HoldRight")
	corrected.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,geo,[shape])
	corrected.surface_set_material(0,src_mesh.surface_get_material(0))
	grip_mesh.mesh=corrected
	print("PASS right hand only grip shape; original skeleton unchanged")
	return true

func prepare_draw() -> void:
	drawing=true
	var palm_rest:=rig.get_bone_global_rest(hand_index)
	var fore_rest:=rig.get_bone_global_rest(rig.find_bone("RightForeArm"))
	palm_local=palm_rest.basis.orthonormalized().inverse()*(palm_rest.origin-fore_rest.origin).normalized()*.067
	var clip:=ap.get_animation("meshy_draw222")
	var contact:=.73
	var cut:=1.78
	var finish_axis:Vector3=ready_blade_axis()
	var finish_basis:=Basis(Quaternion(Vector3.UP,finish_axis))
	ap.play("meshy_draw222")
	ap.advance(0.)
	ap.pause()
	ap.seek(contact,true)
	rig.force_update_all_bone_transforms()
	var chest_at:=bone_world(back_bone)
	var chest_basis:=chest_at.basis.orthonormalized()
	var wrist_at:=bone_world(hand_index)
	var palm_at:=wrist_at.origin+wrist_at.basis.orthonormalized()*palm_local
	var grip_at:=chest_at.origin+chest_basis*(back_offset+back_basis*LOW_GRIP)
	var adjust:Vector3=(palm_at-grip_at).limit_length(.115)
	back_offset+=chest_basis.inverse()*adjust
	var grabbed_basis:=chest_basis*back_basis
	var count:=int(round(cut*30.))
	var gap:=0.
	for frame in range(count+1):
		var t:=minf(frame/30.,cut)
		grip_mesh.set_blend_shape_value(0,smoothstep(contact-.025,contact+.17,t))
		ap.seek(t,true)
		rig.force_update_all_bone_transforms()
		var chest:=bone_world(back_bone)
		var b:=chest.basis.orthonormalized()
		var w:=bone_world(hand_index)
		var p:=w.origin+w.basis.orthonormalized()*palm_local
		var base:=chest.origin+b*back_offset
		var grip:=base+b*back_basis*LOW_GRIP
		if t<contact:
			blade.global_transform=Transform3D((b*back_basis).scaled(Vector3.ONE*.90),base)
		else:
			if gap==0.: gap=p.distance_to(grip)
			var arm:=rig.find_bone("RightArm")
			var left:=rig.find_bone("LeftArm")
			if t<contact+.13:
				var out:=(bone_world(arm).origin-bone_world(left).origin).normalized()
				var forward:=out.cross(Vector3.UP).normalized()
				if forward.dot(rig.global_basis.z)<0.: forward=-forward
				var hold:=grip.lerp(p,smoothstep(contact,contact+.13,t))
				guide_hand(hold-w.basis.orthonormalized()*palm_local,out,forward)
				rig.force_update_all_bone_transforms()
				w=bone_world(hand_index)
				p=w.origin+w.basis.orthonormalized()*palm_local
			var lift:=smoothstep(contact+.10,1.22,t)
			var clearance_axis:Vector3=(Vector3.UP*.62-field.han.global_basis.z*.72).normalized()
			var lift_basis:=Basis(Quaternion(Vector3.UP,clearance_axis))
			var align:=smoothstep(1.17,cut,t)
			var orient:=Basis(grabbed_basis.get_rotation_quaternion().slerp(lift_basis.get_rotation_quaternion(),lift).slerp(finish_basis.get_rotation_quaternion(),align))
			align_wrist_to_grip(orient,smoothstep(contact,contact+.18,t))
			w=bone_world(hand_index)
			p=w.origin+w.basis.orthonormalized()*palm_local
			blade.global_transform=Transform3D(orient.scaled(Vector3.ONE*.90),p+palm_clearance(orient.y)*smoothstep(1.16,cut,t)-orient*LOW_GRIP)
			if (blade.global_transform*Vector3(0.,-.337,0.)).distance_to(p+palm_clearance(orient.y)*smoothstep(1.16,cut,t))>.001:
				printerr("FAIL blade origin no longer coincides with palm")
			if absf(t-contact)<.035: print("QA 222 handoff gap ",p.distance_to(grip))
		await get_tree().create_timer(1./30.).timeout
	var from: Array[Transform3D]=[]
	for i in range(rig.get_bone_count()):
		from.append(Transform3D(Basis(rig.get_bone_pose_rotation(i)).scaled_local(rig.get_bone_pose_scale(i)),rig.get_bone_pose_position(i)))
	ap.play("ready_idle")
	ap.advance(0.)
	ap.pause()
	for f in range(60):
		var t:=f/30.
		ap.seek(fmod(.83+t,ap.get_animation("ready_idle").length),true)
		narrower_feet()
		if f<11:
			var mix:=smoothstep(0.,.34,t)
			for i in range(rig.get_bone_count()):
				var dest:=Transform3D(Basis(rig.get_bone_pose_rotation(i)).scaled_local(rig.get_bone_pose_scale(i)),rig.get_bone_pose_position(i))
				var q:=from[i].interpolate_with(dest,mix)
				rig.set_bone_pose_position(i,q.origin)
				rig.set_bone_pose_rotation(i,q.basis.orthonormalized().get_rotation_quaternion())
				rig.set_bone_pose_scale(i,q.basis.get_scale())
		rig.force_update_all_bone_transforms()
		align_wrist_to_grip(finish_basis,1.0)
		var w:=bone_world(hand_index)
		var p:=w.origin+w.basis.orthonormalized()*palm_local
		var target := p+palm_clearance(finish_basis.y)
		blade.global_transform=Transform3D(finish_basis.scaled(Vector3.ONE*.90),target-finish_basis*LOW_GRIP)
		max_09_grip_error=maxf(max_09_grip_error,(blade.global_transform*Vector3(0.,-.337,0.)).distance_to(target))
		await get_tree().create_timer(1./30.).timeout
	grip_enabled=true
	drawing=false
	carry_blend=1.
	reel_back_carry=false
	print("PASS Meshy 222 source ",clip.length," / retained ",cut," / native 1x then Idle 10")

func _process(delta:float) -> void:
	vfx_age += delta
	if is_instance_valid(blade) and hand_index>=0 and not drawing:
		var pose:=rig.get_bone_global_pose(hand_index)
		var hand_world:=rig.global_transform*pose
		var hand_basis:=hand_world.basis.orthonormalized()
		var palm_world:=hand_world.origin + hand_basis*hand_local_offset*.86
		var name:=String(ap.current_animation)
		carry_blend=move_toward(carry_blend,1. if name in ["ready_idle","idle","walk_native","run_native","decel"] else 0.,delta*7.)
		var carry_axis:Vector3=ready_blade_axis()
		var swing_basis:=hand_basis*hand_local_basis
		var target_basis:=Basis(Quaternion(Vector3.UP,carry_axis))
		var mixed:=swing_basis.get_rotation_quaternion().slerp(target_basis.get_rotation_quaternion(),carry_blend)
		var stowed: bool = reel_back_carry if automated else field.phase < 2
		if stowed:
			var chest:=rig.global_transform*rig.get_bone_global_pose(back_bone)
			var chest_basis:=chest.basis.orthonormalized()
			blade.global_transform=Transform3D((chest_basis*back_basis).scaled(Vector3.ONE*.90),chest.origin+chest_basis*back_offset)
		else:
			var held_position:=palm_world
			if grip_enabled:
				held_position=hand_world.origin+hand_basis*palm_local+palm_clearance(Basis(mixed).y)-Basis(mixed)*LOW_GRIP
			blade.global_transform=Transform3D(Basis(mixed).scaled(Vector3.ONE*.90),held_position)
		var mount := ("back:" if stowed else "hand:")+name
		if mount!=last_mount:
			last_mount=mount
			print("QA mount ",mount," frame=",Engine.get_process_frames())
	if is_instance_valid(field):
		for b: Button in qa_buttons:
			b.visible=field.phase==2 and not automated
			b.disabled=busy or field.active_attacker!=-1
	if is_instance_valid(field) and is_instance_valid(field.paint):
		if not field.is_processing(): field.impact_pulse=maxf(0.,field.impact_pulse-delta)
		field.paint.queue_redraw()
	if is_instance_valid(field) and is_instance_valid(field.start_button):
		field.start_button.hide()
		field.attack_button.hide()

func play_clip(player: AnimationPlayer, options: Array[String], looping := false) -> float:
	return field._play(player,options,looping)

func story_preview() -> void:
	var origin:Vector3=field.han.position
	var floor_y:=_story_support()
	var toward:Vector3=(origin-field.deer.position).normalized()
	field.status_line.text="특수 연출 · 날아감 → 착지 → 일어서기"
	ap.play("story_fly")
	ap.advance(0.0)
	ap.pause()
	var clock:=0.0
	reel_phase("18  날아감 · 착지 · 일어서기")
	var took_off:=false
	var landed:=false
	var down_shown:=false
	while clock < STORY_FLY_SECONDS:
		var motion_time := story_flight_clock(clock)
		var air := clampf(motion_time / .58, 0.0, 1.0)
		var retreat := story_flight_retreat(motion_time)
		var height := story_flight_height(motion_time)
		field.han.position=origin+toward*retreat
		ap.seek(minf(.16+minf(motion_time,.58)*1.20,ap.get_animation("story_fly").length-.01),true)
		field.han.position.y+=clampf(floor_y+height-_story_support()-.20*smoothstep(.43,.60,motion_time),-.9,1.05)
		if motion_time>=.80 and not down_shown:
			down_shown=true
		if height>.1 and not took_off:
			took_off=true
			print("PASS story fly arc")
		if air>=1.0 and not landed:
			landed=true
			print("PASS story grounded landing and short slide")
		await get_tree().create_timer(1./30.).timeout
		clock+=1.0/30.0
	var anchor:Vector3=field.han.position
	anchor.y=origin.y
	ap.play("story_stand",.25)
	var up_time:=0.0
	while up_time<ap.get_animation("story_stand").length:
		field.han.position=anchor
		field.han.position.y+=clampf(floor_y-_story_support()-.23*(1.-smoothstep(.2,1.24,up_time)),-.9,.9)
		await get_tree().create_timer(1./30.).timeout
		up_time+=1.0/30.0
	field.han.position=anchor
	await wait_for(.30)
	play_clip(ap,["ready_idle"],true)
	if took_off and landed and field.han.position.distance_to(anchor)<.001:
		print("PASS story stand-up followed by idle with fixed ground anchor")
	else:
		printerr("FAIL story chain")
		push_error("Han motion viewer operation failed")
	await wait_for(.65)

const STORY_FLY_SECONDS := 1.99

static func story_flight_clock(time: float) -> float:
	var ramp := minf(time, 1.5)
	return .01 * ramp + .99 * ramp * ramp / 3.0 + maxf(0.0, time - 1.5)

static func story_flight_retreat(motion_time: float) -> float:
	var air := clampf(motion_time / .58, 0.0, 1.0)
	return 1.30 * (1.0 - pow(1.0 - air, 1.28)) + .15 * smoothstep(.58, .80, motion_time)

static func story_flight_height(motion_time: float) -> float:
	var air := clampf(motion_time / .58, 0.0, 1.0)
	return .52 * 4.0 * air * (1.0 - air)

func _story_support() -> float:
	rig.force_update_all_bone_transforms()
	var lowest:=100.0
	for item in [["LeftFoot",.07],["RightFoot",.07],["LeftLeg",.08],["RightLeg",.08],["LeftHand",.04],["RightHand",.04],["LeftArm",.12],["RightArm",.12],["Hips",.14],["Head",.13]]:
		var idx:=rig.find_bone(item[0])
		if idx>=0:
			var y:=rig.to_global(rig.get_bone_global_pose(idx).origin).y-float(item[1])
			lowest=minf(lowest,y)
	return lowest

var reel_tag: Label
func ordinary_preview() -> void:
	field.attack_gate=0.0
	field._begin_attack(1)
	var seen:=false
	while field.active_attacker>=0:
		field._process(1./30.)
		if field.contact_done and not seen:
			seen=ap.current_animation=="hit_reaction"
			if seen: effect(0,false,3)
		await get_tree().create_timer(1./30.).timeout
	if not seen or field.han_hp!=17:
		printerr("FAIL actual ordinary hit dispatch"); push_error("Han motion viewer operation failed"); return
	print("PASS deer contact fired ordinary hit without changing 3 HP damage")

func recenter_talk(clip: Animation) -> void:
	var hip_idx := rig.find_bone("Hips")
	if hip_idx < 0: return
	var before := rig.get_bone_pose_position(hip_idx)
	for i in range(clip.get_track_count()):
		if clip.track_get_type(i) != Animation.TYPE_POSITION_3D: continue
		if String(clip.track_get_path(i).get_subname(0)) != "Hips": continue
		var start: Vector3 = clip.track_get_key_value(i,0)
		var offset := Vector3(before.x-start.x,0.0,before.z-start.z)
		for k in range(clip.track_get_key_count(i)):
			var p: Vector3 = clip.track_get_key_value(i,k)
			clip.track_set_key_value(i,k,p+offset)
		var corrected: Vector3 = clip.track_get_key_value(i,0)
		print("QA talk first-key horizontal jump before/after: ",offset.length()," / ",Vector2(before.x-corrected.x,before.z-corrected.z).length())
		return

func motion_only(key: String, label: String) -> void:
	reel_phase(label)
	var clip:=ap.get_animation(key)
	if key == "talk": recenter_talk(clip)
	clip.loop_mode=Animation.LOOP_NONE
	ap.play(key,.10)
	await wait_for(clip.length)

func full_cinematic_3sp() -> void:
	busy=true
	field.set_process(false)
	field.attack_button.disabled=true
	var curtain:=ColorRect.new()
	curtain.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var fg:Node=field.field.get_parent()
	field.add_child(curtain)
	field.move_child(curtain,fg.get_index())
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.color=Color(0,0,0,0)
	var span:=ap.get_animation("sp3").length
	ap.play("sp3",0.)
	ap.advance(0.)
	ap.pause()
	var hit:=false
	print("QA full cinematic start frame=",Engine.get_process_frames())
	for i in range(ceili(cinematic_duration(span) * 30.0) + 1):
		var t:=i/30.
		curtain.color.a = cinematic_dim_alpha(t)
		var clip_t:=cinematic_motion_time(t)
		ap.seek(minf(clip_t,span-.001),true)
		rig.force_update_all_bone_transforms()
		if not hit and clip_t>=span*.59:
			hit=true
			var dmg:=mini(field.deer_hp,2)
			field.deer_hp-=dmg
			field.landed_hits+=1
			effect(3,true,dmg)
			deer_slow_hit()
			print("QA full cinematic impact frame=",Engine.get_process_frames())
		await get_tree().create_timer(1./30.).timeout
	curtain.queue_free()
	play_clip(ap,["ready_idle"],true)
	play_clip(field.deer_anim,["req046_idle","idle"],true)
	if field.deer_hp<=0: field.phase=3
	field._refresh()
	field.elapsed=0.
	busy=false

static func cinematic_duration(clip_length: float) -> float:
	return 2.5 + clip_length - 1.08

static func cinematic_dim_alpha(time: float) -> float:
	var enter := clampf((time - .90) / 1.20, 0.0, 1.0)
	var leave := 1.0 - clampf((time - 2.57) / .76, 0.0, 1.0)
	return .55 * (.45 * enter + .55 * enter * enter) * leave * leave

static func cinematic_motion_time(t:float)->float:
	if t<=.9: return .5*t
	if t<=1.:
		var d:=t-.9
		return .45+.5*d-2.*d*d
	if t<=2.5:
		var d:=t-1.
		return .48+.1*d+.3*d*d*d/(1.5*1.5)
	return 1.08+(t-2.5)

const TITLES := ["일반 대기","듣기","말하기","화남","환호","걷기","달리기","달리다 걷기(정지)","전투 준비","평타","2SP","3SP","일반 피격","큰 피격","큰 타격 · 넉다운","일어서기","사망","날아감 · 착지 · 일어서기"]
var app
signal exited
var action_buttons:Array[Button]=[]
var group_buttons:Array[Button]=[]
var selected:=0
var group_index:=0
var setup_ok:=false

func _build_motion_picker() -> void:
	var panel:=PanelContainer.new()
	field.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left=18
	panel.offset_right=-18
	panel.offset_top=-118
	panel.offset_bottom=-18
	var margin:=MarginContainer.new()
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,6)
	panel.add_child(margin)
	var buttons:=VBoxContainer.new()
	buttons.add_theme_constant_override("separation",4)
	margin.add_child(buttons)
	var tabs:=HBoxContainer.new()
	tabs.alignment=BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(tabs)
	for g in 3:
		var tab:Button=field._button(tabs,["대기 · 이동 01–06","전투 동작 07–12","피격 · 특수 13–18"][g],_set_group.bind(g))
		tab.custom_minimum_size=Vector2(0,29)
		tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		group_buttons.append(tab)
	var row:=HBoxContainer.new()
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(row)
	for i in 18:
		var control:Button=field._button(row,"%02d %s"%[i+1,TITLES[i]],_pick.bind(i+1))
		control.name="HanMotion%02d"%(i+1)
		control.custom_minimum_size=Vector2(0,43)
		control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		control.add_theme_font_size_override("font_size",15)
		action_buttons.append(control)
	_set_group(0)

func _set_group(g:int) -> void:
	group_index=g
	for i in group_buttons.size():group_buttons[i].modulate=Color("#92c7ff") if i==g else Color.WHITE
	for i in action_buttons.size():action_buttons[i].visible=floori(float(i)/6.)==g

func _pick(id:int) -> void:
	if not setup_ok or busy:return
	busy=true
	selected=id
	for i in action_buttons.size():
		action_buttons[i].disabled=true
		action_buttons[i].modulate=Color("#ffad91") if i==id-1 else Color.WHITE
	field.set_process(false)
	field._reset()
	if id>=9:
		var delta:Vector3=field.deer.position-field.han.position
		var separation:=maxf(0.,delta.length()-1.14)
		field.han.position+=delta.normalized()*separation*.70
		field.deer.position-=delta.normalized()*separation*.30
		field._face()
		field.phase=2
		field._refresh()
	var label:="%02d  %s"%[id,TITLES[id-1]]
	reel_phase(label)
	match id:
		1:play_clip(ap,["idle_02_11"],true)
		2,3,4,5:await motion_only(["listen","talk","angry","cheer"][id-2],label)
		6,7,8:await _preview_travel(id)
		9:
			reel_back_carry=true
			await prepare_draw()
		10:
			busy=false
			await basic()
		11:
			busy=false
			await skill(2)
		12:await full_cinematic_3sp()
		13:await number_13()
		14:await number_14()
		15:await number_15()
		16:await _preview_stand()
		17:
			busy=false
			await lose_interactive()
		18:await story_preview()
	field.status_line.text=label
	for button in action_buttons:button.disabled=false
	busy=false

func _preview_travel(id:int) -> void:
	var key:String=["walk_native","run_native","decel"][id-6]
	var delta:Vector3=field.deer.position-field.han.position
	var period:=play_clip(ap,[key],id!=8)
	var tween:=create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if id==8 else Tween.EASE_IN_OUT)
	tween.tween_property(field.han,"position",field.han.position+delta.normalized()*[.85,1.40,.36][id-6],period)
	await tween.finished
	play_clip(ap,["idle_02_11"],true)

func _preview_stand() -> void:
	var anchor:Vector3=field.han.position
	var ground:=_story_support()
	var span:=ap.get_animation("story_stand").length
	ap.play("story_stand",0.)
	ap.advance(0.)
	ap.pause()
	for f in range(ceili(span*30.)):
		grounded_stand(minf(float(f)/30.,span-.003),anchor,ground)
		await get_tree().create_timer(1./30.).timeout
	field.han.position=anchor

var duel_binding:=false
var duel_model:Node3D
var duel_active_key:=""
var model_display_scale := 1.0
var donor_meshes: Dictionary = {}
var duel_gait_key := ""
var duel_gait_origin := Vector2.ZERO

const MODEL_TEST_SCALE := 1.58
const MODEL_TEST_CAMERA_SIZE := 7.0
const MODEL_TEST_VIEW_SIZE := Vector2i(960, 720)
const MODEL_TEST_DISPLAY_FACTOR := .46 / 1.5

# Clip phase and forward distance at the standard model scale, measured from
# the backward travel of each planted toe. Airborne sections continue the run.
const GAIT_TRAVEL := {
	"walk_native": [
		Vector2(0.0, 0.0), Vector2(.025, 0.0), Vector2(.225, .2786),
		Vector2(.300, .3982), Vector2(.350, .4710), Vector2(.675, .9298),
		Vector2(.775, 1.0876), Vector2(.825, 1.1634), Vector2(1.0, 1.4102),
	],
	"run_native": [
		Vector2(0.0, 0.0), Vector2(.050, 0.0), Vector2(.100, .1435),
		Vector2(.250, .4845), Vector2(.300, .5282), Vector2(.375, .7499),
		Vector2(.450, .9803), Vector2(.550, 1.3098), Vector2(.750, 1.7688),
		Vector2(.800, 1.8543), Vector2(.875, 2.0724), Vector2(.950, 2.3126),
		Vector2(1.0, 2.4759),
	],
	# Right toe supports the first part, then the left toe carries the walk-out.
	"decel": [
		Vector2(0.0, 0.0), Vector2(.1111, .1494), Vector2(.3333, .4954),
		Vector2(.4444, .6634), Vector2(.5000, .6963), Vector2(.6667, .8762),
		Vector2(.8889, 1.0981), Vector2(1.0, 1.2184),
	],
}

func gait_distance(key: String, time: float) -> float:
	var curve: Array = GAIT_TRAVEL[key]
	var cycles := time / ap.get_animation(key).length
	var phase := fposmod(cycles, 1.0)
	var distance: float = floorf(cycles) * curve.back().y
	for index in range(1, curve.size()):
		var from: Vector2 = curve[index - 1]
		var to: Vector2 = curve[index]
		if phase <= to.x:
			distance += lerpf(from.y, to.y, inverse_lerp(from.x, to.x, phase))
			break
	return distance * model_display_scale

func _gait_time(key: String, distance: float) -> float:
	var curve: Array = GAIT_TRAVEL[key]
	var phase_distance := fposmod(distance / model_display_scale, curve.back().y)
	for index in range(1, curve.size()):
		var from: Vector2 = curve[index - 1]
		var to: Vector2 = curve[index]
		if to.y > from.y and phase_distance <= to.y:
			var phase := lerpf(from.x, to.x, inverse_lerp(from.y, to.y, phase_distance))
			return phase * ap.get_animation(key).length
	return 0.0

func reset_duel_gait() -> void:
	duel_gait_key = ""

static func model_test_projection_ratio(camera: Camera3D, display_scale: float) -> float:
	var measured_height := camera.unproject_position(Vector3.UP).distance_to(camera.unproject_position(Vector3.ZERO)) * display_scale
	var preview_height := MODEL_TEST_VIEW_SIZE.y / MODEL_TEST_CAMERA_SIZE * MODEL_TEST_DISPLAY_FACTOR * MODEL_TEST_SCALE / sqrt(2.0)
	return preview_height / maxf(.001, measured_height)

func bind_duel(pivot:Node3D,other:Node3D,cam:Camera3D,display_scale := 1.0) -> bool:
	duel_binding=true
	field={"han":pivot,"deer":other,"camera":cam}
	var model:=load("res://battlefield_reset/han_motion/Han-Battle-Ultra-Rigged-12k.glb") as PackedScene
	if model==null:return false
	var original:=pivot.find_children("*","MeshInstance3D",true,false)
	duel_model=model.instantiate() as Node3D
	pivot.add_child(duel_model)
	rig=skeleton(duel_model)
	if rig==null:
		duel_model.queue_free()
		return false
	var top:=duel_model.to_local(rig.to_global(rig.get_bone_global_rest(rig.find_bone("head_end")).origin)).y
	var heel:=duel_model.to_local(rig.to_global(rig.get_bone_global_rest(rig.find_bone("LeftToeBase")).origin)).y
	model_display_scale = display_scale
	var factor := 1.58 * model_display_scale / maxf(.2, top - maxf(heel - .022, 0.0))
	duel_model.scale*=factor
	duel_model.position.y=-maxf(heel-.022,0.)*factor
	for p:AnimationPlayer in duel_model.find_children("*","AnimationPlayer",true,false):
		p.stop()
		p.active=false
	ap=AnimationPlayer.new()
	ap.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	duel_model.add_child(ap)
	library=(load("res://battlefield_reset/han_motion/han-action-library.res") as AnimationLibrary).duplicate(true) as AnimationLibrary
	ap.add_animation_library("",library)
	make_blade()
	install_grip_shape(duel_model)
	for mesh:MeshInstance3D in original:
		donor_meshes[mesh] = mesh.visible
		mesh.hide()
	return true

func restore_duel_donor() -> void:
	for mesh: MeshInstance3D in donor_meshes:
		if is_instance_valid(mesh):
			mesh.visible = donor_meshes[mesh]
	donor_meshes.clear()
	if is_instance_valid(duel_model):
		duel_model.hide()
		duel_model.queue_free()
	if is_instance_valid(blade):
		blade.hide()
		blade.queue_free()

func show_duel_motion(move:String,clock:float,duration:float,alive:bool,ground_position := Vector3.INF) -> void:
	if not is_instance_valid(duel_model):return
	var key: String = {
		"idle": "ready_idle", "walk": "walk_native", "run": "run_native",
		"attack": "clear_basic", "skill": "sp2", "chain": "sp3",
		"hit": "normal_179", "heavy_hit": "heavy_173", "death": "dead",
	}.get(move, "ready_idle")
	if not alive:
		key = "dead"
	var span := ap.get_animation(key).length
	var gait := key in ["ready_idle", "walk_native", "run_native"]
	var start := .72 if key == "heavy_173" else 0.0
	var time := fposmod(clock, span) if gait else lerpf(start, span, clampf(clock / maxf(.001, duration), 0.0, 1.0))
	if GAIT_TRAVEL.has(key) and ground_position.is_finite():
		var ground := Vector2(ground_position.x, ground_position.z)
		if duel_gait_key != key:
			duel_gait_key = key
			duel_gait_origin = ground
		time = _gait_time(key, duel_gait_origin.distance_to(ground))
	else:
		reset_duel_gait()
	sample_han_clip(key,time,gait)

func capture_han_pose(key: String, time: float) -> Array[Transform3D]:
	sample_han_clip(key, time, true)
	var pose: Array[Transform3D] = []
	for joint in rig.get_bone_count():
		pose.append(rig.get_bone_pose(joint))
	return pose

func sample_han_clip(key: String, time: float, ready_grip := false, previous_pose: Array[Transform3D] = [], blend := 1.0) -> void:
	var span := ap.get_animation(key).length
	if duel_active_key!=key:
		duel_active_key=key
		ap.play(key,0.)
	ap.seek(minf(span-.00001,time),true)
	if blend < 1.0:
		for joint in previous_pose.size():
			rig.set_bone_pose(joint, previous_pose[joint].interpolate_with(rig.get_bone_pose(joint), blend))
	rig.force_update_all_bone_transforms()
	var hand:=bone_world(hand_index)
	var basis:=hand.basis.orthonormalized()*hand_local_basis
	if ready_grip:basis=Basis(Quaternion(Vector3.UP,ready_blade_axis()))
	var palm := hand.origin + hand.basis.orthonormalized() * palm_local * model_display_scale
	var weapon_basis := basis.scaled(Vector3.ONE * (.90 * model_display_scale))
	blade.global_transform = Transform3D(weapon_basis, palm + palm_clearance(basis.y) * model_display_scale - weapon_basis * LOW_GRIP)
