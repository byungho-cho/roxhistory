extends SceneTree
const Accent=preload("res://scripts/battle_presentation_accent.gd")
const HeadHUD=preload("res://scripts/battle_head_hud.gd")
const Trial=preload("res://scripts/parry_trial.gd")
var checks:=0
var failures:=0
var lab
func _initialize():call_deferred("run")
func check(ok:bool,why:String):
	checks+=1
	if not ok:failures+=1;push_error(why)
func run():
	var accent=Accent.new()
	accent.chain_started(1.6)
	var previous:=-1.0
	for i in 200:
		var time:=float(i)/120
		var pose=Accent.chain_pose(time,1.6)
		check(pose>=previous,"pose clock is monotonic")
		if time>=.752:check(is_equal_approx(pose,time),"normal pose time restored before contact")
		previous=pose
	accent.advance(.7);check(is_equal_approx(accent.zoom,1.055),"chain peak is5.5 percent")
	accent.chain_contact();accent.advance(.69);check(is_equal_approx(accent.zoom,1.055),"hold through21 frames")
	accent.parry_contact();accent.advance(.06);check(is_equal_approx(accent.zoom,1.045),"parry replaces rather than multiplies zoom")
	accent.advance(.5);check(accent.zoom==1 and accent.kind.is_empty(),"one return to normal")
	for offset in [-321,-320,-30,-29]:
		var trial=Trial.new(0);trial.parry(trial.impact+offset)
		check((trial.outcome=="성공")== (offset>=-320 and offset<=-30),"original parry window "+str(offset))
		if trial.outcome=="성공":
			check(trial.boar_hp==82 and trial.stun_end==trial.input+1350,"original parry damage and stun")
	for t in [0,80,160,200]:check(Accent.parry_pose_ms(1000+t,1000)<=1000+t,"presentation never advances future parry pose")
	var headers:Array=[]
	for i in 4:headers.append(HeadHUD.create(root,str(i),i<3))
	for point in [Vector2(0,0),Vector2(480,200),Vector2(960,540)]:
		HeadHUD.layout(headers,[point,point,point,point],Rect2(8,70,944,350))
		for i in 4:
			var rect:Rect2=Rect2(headers[i].panel.position,HeadHUD.SIZE)
			check(Rect2(8,70,944,350).encloses(rect),"head stays in safe bounds")
			for j in range(i):check(not rect.intersects(Rect2(headers[j].panel.position,HeadHUD.SIZE)),"four clustered headers never overlap")
	for head in headers:head.panel.queue_free()
	lab=load("res://scenes/hunt_duel_lab.tscn").instantiate();root.add_child(lab);lab.set_process(false);await process_frame
	for key in ["attack","skill","chain","miss"]:
		lab.reset_round();lab.advance(lab.APPROACH_END+.00001);lab.next_attack=[999.0,999.0]
		if key=="miss":lab.shared_world.bodies[1].position+=Vector3(0,0,10)
		lab.rules.sp=3;lab._act(0,"chain" if key=="miss" else key);lab.next_attack=[999.0,999.0]
		var emitted:=false;var max_zoom:=1.0
		for i in 480:
			lab.advance(1.0/120);max_zoom=maxf(max_zoom,lab.accent.zoom)
			emitted=emitted or lab.fx.any(func(fx):return fx.name=="han_chain_impact")
		check(emitted==(key=="chain"),"provided contact impact only on actual chain hit: "+key)
		check(lab.rules.hp[1]==({"attack":89,"skill":73,"chain":62,"miss":100}[key]),"authoritative damage unchanged: "+key)
		if key in ["attack","skill"]:check(max_zoom==1,"no new accent on basic/general")
		else:check(max_zoom>1.054 and max_zoom<=1.055001,"chain zoom bounded")
		check(lab.accent.zoom==1,"camera returned after event: "+key)
	check(Engine.time_scale==1,"no global time scaling")
	lab.queue_free();await process_frame;await process_frame
	print("D0071 presentation: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
