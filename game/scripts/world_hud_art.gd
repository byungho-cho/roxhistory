extends Node2D

func bind(owner_control:Control,world:Node2D)->void:
	world.add_child(self)
	owner_control.visibility_changed.connect(func():visible=owner_control.is_visible_in_tree())
	owner_control.tree_exiting.connect(func():
		if is_instance_valid(self):queue_free())

func place(world:Node2D,screen_at:Vector2,screen_scale:Vector2)->void:
	transform=world.get_global_transform_with_canvas().affine_inverse()*Transform2D(0.0,screen_scale,0.0,screen_at)
