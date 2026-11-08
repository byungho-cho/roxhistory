class_name ActorMovement
extends RefCounted
## All walking actors use the same speed, step limiting and collision motion.
static func speed()->float:return float(DemoConfig.get_data().move_speed)
static func direction_to(from:Vector2,to:Vector2,delta:float,factor:float=1.0)->Vector2:
	return (to-from).limit_length(speed()*factor*delta)/maxf(.001,speed()*factor*delta)
static func move(body:CharacterBody2D,direction:Vector2,factor:float=1.0)->void:
	body.velocity=direction.limit_length()*speed()*factor
	body.move_and_slide()
