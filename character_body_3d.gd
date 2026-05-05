extends CharacterBody3D

var speed
const WALK_SPEED = 3
const SPRINT_SPEED = 4
const JUMP_VELOCITY = 2.5
const SENSITIVITY = 0.004
@export var rotation_speed := 3.5

var footstep_can_play := true
var footstep_landed

#bob variables
const BOB_FREQ = 3.5
const BOB_AMP = 0.08
var t_bob = 0.0

#fov variables
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 9.8
var mouse_lock = true

@onready var head = $head
@onready var camera = $head/Camera3D
@onready var Augen = $MeshInstance3D/MeshInstance3D
@onready var Augen2 = $MeshInstance3D/MeshInstance3D2


@rpc("call_local")



func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	if not is_multiplayer_authority(): return
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.current = true

	

func _unhandled_input(event):
	if not is_multiplayer_authority(): return

	if event is InputEventMouseMotion and mouse_lock:
		# Körper rotieren (links/rechts)
		rotate_y(-event.relative.x * SENSITIVITY)

		# Kopf/Kamera rotieren (hoch/runter)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))

func _physics_process(delta):
	if not is_multiplayer_authority(): return
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	if Input.is_action_just_pressed("exit"):
		mouse_lock = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if Input.is_action_just_pressed("LightON"):
		mouse_lock = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


	
	# Handle Sprint.
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)
	
	# Head bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	
	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	
	move_and_slide()

	if not footstep_landed and is_on_floor():
		%JUMPAudio3D.play()
	elif footstep_landed and not is_on_floor():
		%JUMPAudio3D.play()
	footstep_landed = is_on_floor()

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	
	var footstep_threshold = -BOB_AMP + 0.002
	if pos.y > footstep_threshold:
		footstep_can_play = true
	elif pos.y < footstep_threshold and footstep_can_play:
		footstep_can_play = false 
		%FootStepAudio3D.play()
	
	return pos

func _process(delta):
	if not is_multiplayer_authority(): return
	
	var joy_id := 0
	var axis_x := Input.get_joy_axis(joy_id, 2)
	var axis_y := Input.get_joy_axis(joy_id, 3)

	if abs(axis_x) < 0.1:
		axis_x = 0
	if abs(axis_y) < 0.1:
		axis_y = 0

	# HORIZONTAL → Körper
	rotate_y(-axis_x * rotation_speed * delta)

	# VERTIKAL → Kamera
	var new_pitch = camera.rotation.x - axis_y * rotation_speed * delta
	new_pitch = clamp(new_pitch, deg_to_rad(-40), deg_to_rad(60))
	camera.rotation.x = new_pitch
