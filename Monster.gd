extends CharacterBody3D

enum State { ROAMING, CHASING }

@export var roaming_radius: float = 100.0
@export var roaming_delay: float = 2.0
@export var speed: float = 3.0
@export var chase_speed: float = 3.5
@export var vision_range: float = 10.0
var chasing_stop_distance: float = 11.0

@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var monster_mesh: Node3D = $MeshInstance3D

@onready var spawn: Marker3D = $"../Spawn" # Spawn Marker für Respawn

# Shader Overlay
@export_node_path("ColorRect") var shader_overlay_path
var shader_material: ShaderMaterial
var intensity: float = 0.0

var players: Array = []   # Liste aller Spieler
var player: Node3D = null # Aktuell verfolgter Spieler
var current_state: State = State.ROAMING
var roam_timer: float = 0.0
var last_position: Vector3
var stuck_timer: float = 0.0

func _ready():
	# Shader laden
	var overlay_node := $"../ColorRect"
	shader_material = overlay_node.material as ShaderMaterial

	# Navigation vorbereiten
	nav_agent.target_desired_distance = 0.5
	set_new_roam_target()
	roam_timer = roaming_delay

	# Alle Spieler erfassen
	players = get_tree().get_nodes_in_group("player")
	get_tree().connect("node_added", Callable(self, "_on_node_added"))

func _on_node_added(node):
	if node.is_in_group("player") and not players.has(node):
		players.append(node)

func _physics_process(delta):
	if players.size() == 0:
		# Prüfen, ob Spieler vorhanden sind
		players = get_tree().get_nodes_in_group("player")
		if players.size() == 0:
			return

	# Nächsten Spieler auswählen
	var closest_player: Node3D = null
	var min_dist = INF
	for p in players:
		var dist = global_transform.origin.distance_to(p.global_transform.origin)
		if dist < min_dist:
			min_dist = dist
			closest_player = p
	player = closest_player

	# --- GRAVITY ---
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	match current_state:
		State.ROAMING:
			roam_timer -= delta
			if nav_agent.is_navigation_finished() or roam_timer <= 0:
				set_new_roam_target()
				roam_timer = roaming_delay
			check_player_in_range()
			move_to_target(speed, delta)
		State.CHASING:
			var nav_map = nav_agent.get_navigation_map()
			var safe_target = NavigationServer3D.map_get_closest_point(nav_map, player.global_transform.origin)
			nav_agent.set_target_position(safe_target)
			move_to_target(chase_speed, delta)
			check_player_in_range()

	# --- Anti-Stuck-System ---
	if last_position:
		if global_transform.origin.distance_to(last_position) < 0.01 and velocity.length() > 0.1:
			stuck_timer += delta
		if stuck_timer > 1.5:
			print("NPC steckt fest, neue Zielsuche")
			if current_state == State.ROAMING:
				set_new_roam_target()
			elif current_state == State.CHASING:
				var nav_map = nav_agent.get_navigation_map()
				var safe_target = NavigationServer3D.map_get_closest_point(nav_map, player.global_transform.origin)
				nav_agent.set_target_position(safe_target)
			stuck_timer = 0.0
		else:
			stuck_timer = 0.0
	last_position = global_transform.origin

	# --- Shader-Effekt je nach Nähe ---
	var distance: float = global_transform.origin.distance_to(player.global_transform.origin)
	var target_intensity: float = clamp(1.0 - (distance / 20.0), 0.0, 1.0)
	intensity = lerp(intensity, target_intensity, delta * 5.0)
	if shader_material:
		shader_material.set_shader_parameter("ghost_strength", intensity * 0.5)
		shader_material.set_shader_parameter("blur_strength", intensity * 3)
		shader_material.set_shader_parameter("noise_strength", intensity * 0.16)
		shader_material.set_shader_parameter("vignette_strength", intensity * 0.8)
		shader_material.set_shader_parameter("flicker_strength", intensity * 0.05)

	# --- Blickrichtung des Monsters ---
	if monster_mesh:
		match current_state:
			State.ROAMING:
				if velocity.length() > 0.1:
					var dir = Vector3(velocity.x, 0, velocity.z).normalized()
					if dir.length() > 0.1:
						var target_rot = atan2(dir.x, dir.z)
						var current_rot = monster_mesh.rotation.y
						monster_mesh.rotation.y = lerp_angle(current_rot, target_rot, delta * 3.0)
			State.CHASING:
				if player:
					var to_player = player.global_transform.origin - global_transform.origin
					to_player.y = 0
					if to_player.length() > 0.1:
						var target_rotation = atan2(to_player.x, to_player.z)
						var current_rotation = monster_mesh.rotation.y
						monster_mesh.rotation.y = lerp_angle(current_rotation, target_rotation, delta * 5.0)

	# --- Unheimliches Zittern beim Verfolgen ---
	if current_state == State.CHASING and monster_mesh:
		var shake_strength = 0.02
		var random_offset = Vector3(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		monster_mesh.position = random_offset
	else:
		if monster_mesh:
			monster_mesh.position = Vector3.ZERO

func set_new_roam_target():
	var nav_map = nav_agent.get_navigation_map()
	var new_target: Vector3
	var tries = 0
	while true:
		var random_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		new_target = global_transform.origin + random_dir * roaming_radius
		if new_target.distance_to(global_transform.origin) > 8.0:
			var closest_point = NavigationServer3D.map_get_closest_point(nav_map, new_target)
			if closest_point.distance_to(new_target) < 1.0:
				break
		tries += 1
		if tries > 10:
			print("Kein gültiges Roaming-Ziel gefunden.")
			return
	print("Neues Roaming-Ziel:", new_target)
	nav_agent.set_target_position(new_target)

func move_to_target(move_speed: float, delta: float):
	if nav_agent.is_navigation_finished():
		velocity.x = 0
		velocity.z = 0
	else:
		var next_pos = nav_agent.get_next_path_position()
		var dir = (next_pos - global_transform.origin)
		dir.y = 0
		if dir.length() > 0:
			dir = dir.normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed

	move_and_slide()

func check_player_in_range():
	if player == null:
		return
	var dist = global_transform.origin.distance_to(player.global_transform.origin)
	match current_state:
		State.ROAMING:
			if dist < vision_range:
				print("Spieler entdeckt! Wechsle zu CHASING.")
				current_state = State.CHASING
		State.CHASING:
			if dist > chasing_stop_distance:
				print("Spieler verloren. Wechsle zu ROAMING.")
				current_state = State.ROAMING

# --- Respawn beim Marker ---
func respawn():
	if spawn:
		global_transform.origin = spawn.global_transform.origin
		velocity = Vector3.ZERO
		print("Spieler respawned an Marker")


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body == player:
		print("Spieler berührt von Monster!")
		respawn()
		#this doesnt really work rn so you have to figure it on your own :/
