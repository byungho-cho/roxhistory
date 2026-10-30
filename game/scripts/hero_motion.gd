class_name HeroMotion
extends RefCounted

# A single cycle owns the visible downswing and the impact/audio event.
const CYCLE := 1.0/1.8
const CONTACT := CYCLE*0.5
static func stroke(seconds: float) -> float:
	var t := fposmod(seconds,CYCLE)/CYCLE
	if t < 0.28: return -smoothstep(0.0,0.28,t)*0.35
	if t < 0.5: return lerpf(-0.35,1.0,smoothstep(0.28,0.5,t))
	return 1.0-smoothstep(0.5,1.0,t)

# Stance travels backwards linearly; the returning foot has a separate lift arc.
static func step(phase: float, side: float) -> Vector2:
	var t := fposmod(phase/TAU+(0.5 if side < 0 else 0.0),1.0)
	if t < 0.5: return Vector2(lerpf(0.24,-0.24,t*2.0),0.0)
	var swing := (t-0.5)*2.0
	return Vector2(lerpf(-0.24,0.24,smoothstep(0,1,swing)),sin(swing*PI)*0.095)
