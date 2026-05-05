extends Node3D

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/PanelContainer/PanelContainer2/VBoxContainer/LineEdit
@onready var spawn_point = $Spawn

const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()

const Player = preload("res://CharacterWithJuice.tscn")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass




func _on_join_pressed() -> void:
	main_menu.hide()
	enet_peer.create_client("localhost", PORT)
	multiplayer.multiplayer_peer = enet_peer

	multiplayer.connected_to_server.connect(_on_client_connected)

func _on_client_connected():
	# Client spawnt sich selbst
	add_player(multiplayer.get_unique_id())



func _on_host_pressed() -> void:
	main_menu.hide()
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer

	# Host spawnt sich selbst
	add_player(multiplayer.get_unique_id())

	multiplayer.peer_connected.connect(add_player)
	
	#upnp_setup()      #Only use this if you have upnp enabled in yourt router ( On by default) for testing you should use #

func add_player(peer_id):
	var player = Player.instantiate()
	player.name = str(peer_id)

	# Wichtig!
	player.global_transform = spawn_point.global_transform

	add_child(player)



func upnp_setup():
	var upnp= UPNP.new()
	
	var discover_result = upnp.discover()
	
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Discover Failed! Error %s" % discover_result)
	
	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
		"UPNP Invalid Gateway!")
		
	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Port Mapping Failed! Error %s" % map_result)
	
	print("Succes! Join Addres: %s" % upnp.query_external_address())
