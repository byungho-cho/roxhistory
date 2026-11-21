extends RefCounted
## Presentation clocks only. Never writes Engine.time_scale or encounter rules.
var kind:=""
var age:=0.0
var zoom:=1.0
var initial_zoom:=1.0
var impact_at:=-1.0
var duration:=1.6
var entries:=0
func reset()->void:
	kind="";age=0;zoom=1;initial_zoom=1;impact_at=-1;entries=0
func chain_started(seconds:float)->void:
	initial_zoom=zoom;kind="chain";age=0;impact_at=-1;duration=seconds;entries+=1
func chain_contact()->void:
	if kind=="chain" and impact_at<0:impact_at=age
func parry_contact()->void:
	initial_zoom=zoom;kind="parry";age=0;impact_at=0;entries+=1
func advance(delta:float)->void:
	if kind.is_empty():return
	age+=delta
	if kind=="chain":
		var apex:=duration*.32;var crest:=duration*.40
		var release:=impact_at+.70 if impact_at>=0 else duration*.57
		if age<apex:zoom=lerpf(initial_zoom,1,smoothstep(0,apex,age))
		elif age<crest:zoom=lerpf(1,1.055,smoothstep(apex,crest,age))
		elif age<release:zoom=1.055
		else:zoom=lerpf(1.055,1,smoothstep(release,release+.65,age))
		if age>=release+.65:kind="";zoom=1
	else:
		if age<.06:zoom=lerpf(initial_zoom,1.045,smoothstep(0,.06,age))
		elif age<.14:zoom=1.045
		else:zoom=lerpf(1.045,1,smoothstep(.14,.49,age))
		if age>=.49:kind="";zoom=1
	zoom=clampf(zoom,1,1.055) # Absolute envelope, never stacked multipliers.
static func chain_pose(seconds:float,length:float)->float:
	var t:=seconds/maxf(.001,length)
	if t<.32 or t>=.47:return seconds
	if t<.40:return length*(.32+(t-.32)*.35)
	return length*lerpf(.348,.47,(t-.40)/.07)
static func parry_pose_ms(now:int,contact:int)->float:
	if contact<0:return now
	var elapsed:=float(now-contact)
	if elapsed<0 or elapsed>=160:return now
	return contact+elapsed*.3 if elapsed<80 else contact+24+(elapsed-80)*1.7
