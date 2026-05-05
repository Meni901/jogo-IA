extends Node3D

@onready var raycast = $Camera3D/RayCast3D
@onready var hand = $hand

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta):
	
	var object = raycast.get_collider()
	if raycast.is_colliding():
		if object.is_in_group("pickable"):
			if Input.is_action_pressed("Interact"):
				object.global_position = hand.global_position
				object.global_rotation = hand.global_rotation
				object.collision_layer = 2
				object.linear_velocity = Vector3(0.1, 3, 0.1)
				
	
