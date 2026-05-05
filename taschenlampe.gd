extends Node3D

var light_on: bool = false

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	
	if Input.is_action_just_pressed("LightON") and $ProgressBar.value > 0:
		rpc("_server_toggle_light")   # sendet an authority node
		

@rpc("any_peer", "call_local") 
func _server_toggle_light():
	# nur Node-Eigentümer erlaubt Toggle
	if not is_multiplayer_authority():
		return
	
	light_on = !light_on
	rpc("_client_set_light", light_on)


@rpc("call_local")
func _client_set_light(new_state: bool):
	light_on = new_state

	if light_on:
		$SpotLight3D.light_energy = 16
		%LightONSound.play()
	else:
		$SpotLight3D.light_energy = 0
		%LightOFFSound.play()


func _physics_process(delta: float) -> void:
	if light_on:
		$ProgressBar.value -= 0.05

	if $ProgressBar.value <= 0 and light_on:
		light_on = false
		$SpotLight3D.light_energy = 0
