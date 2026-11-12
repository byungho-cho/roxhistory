extends RefCounted

const CENTER := Vector2(480,250)
const PIVOT := Vector2(240,49.5)
const ALLY := Vector2(138.2,20.4)
const DEER := Vector2(293,7.875)
const CONTACT := [
	Vector4(1.04,0,110,32),Vector4(1.42,1,0,0),Vector4(1.68,.52,46,15),
	Vector4(2.04,1,0,0),Vector4(2.72,0,0,0),
]

static func choose(ground_id: String, forced: int, by_ground: Dictionary) -> int:
	if forced in [1,2]:
		return forced
	var configured := int(by_ground.get(ground_id,0))
	return configured if configured in [1,2] else randi_range(1,2)


static func contact(time: float) -> Vector4:
	for index in range(1,CONTACT.size()):
		var before: Vector4 = CONTACT[index-1]
		var after: Vector4 = CONTACT[index]
		if time<=after.x:
			return before.lerp(after,smoothstep(before.x,after.x,time))
	return CONTACT[-1]


static func render(screen: Control) -> void:
	var time: float = screen.arrival_elapsed
	var first: bool = screen.arrival_variant==1
	var finish: float = screen.arrival_duration
	var dock_end := finish-.35
	var dock := smoothstep(dock_end-1.15,dock_end,time)
	var reveal := smoothstep(dock_end,finish,time)
	screen.power_header.position = (CENTER-PIVOT).lerp(screen.match_home,dock)
	screen.power_header.scale = Vector2.ONE*lerpf(2.35,1.0,dock)
	screen.match_shade.modulate.a = smoothstep(.1,.5,time)*(1.0-dock)
	screen.match_details.modulate.a = reveal
	for part in [screen.header,screen.roster_edge,screen.placement_grid,screen.footer_left,screen.footer_right]:
		part.modulate.a = reveal
	var left := smoothstep(.28,1.02,time)
	var right := smoothstep(.38,1.12,time)
	var pose := Vector4.ZERO if first else contact(time)
	screen.prep_ally_portrait.position = ALLY+Vector2(-225*(1.0-left),0)+Vector2(51,3.5)*pose.y
	screen.match_deer.position = DEER+Vector2(225*(1.0-right),0)+Vector2(-51.5,10.125)*pose.y
	screen.prep_ally_portrait.modulate.a = left
	screen.match_deer.modulate.a = right

	var vs_root: Control = screen.match_vs.root
	var letters: Control = screen.match_vs.letter_layer
	var vs_progress := smoothstep(.83,1.58,time) if first else smoothstep(2.08,2.62,time)
	letters.modulate.a = vs_progress
	letters.scale = Vector2.ONE*lerpf(2.75 if first else 1.5,1.0,vs_progress)
	letters.position.y = -165*(1.0-vs_progress)/vs_root.scale.x if first else 0.0
	var cross := smoothstep(1.34,1.98,time)
	for index in 2:
		var spear: TextureRect = screen.match_vs.spears[index]
		var direction := -1.0 if index==0 else 1.0
		var entrance := left if index==0 else right
		var offset := Vector2(direction*195*(1.0-cross),130*(1.0-cross)-17.5*sin(PI*cross))
		if not first:
			offset = Vector2(direction*(225*(1.0-entrance)+pose.z),pose.w)
		spear.position = Vector2.ONE*-18+offset/vs_root.scale.x
		spear.modulate.a = cross if first else entrance
	var second_hit := not first and time>=2.04
	var impact_start := 1.98 if first else (2.04 if second_hit else 1.42)
	screen.show_match_impact(1 if second_hit else 0,time-impact_start)
