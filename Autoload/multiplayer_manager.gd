extends Node

const SERVER_PORT = 8080
const SERVER_IP = "127.0.0.1"

var multiplayer_scene = preload("res://Game/player.tscn")

var spawn_node : Node = null
var client_id : int = 0

func become_host() -> void:
	spawn_node = get_tree().get_current_scene().get_node("players")
	
	var server_peer = ENetMultiplayerPeer.new()
	server_peer.create_server(SERVER_PORT)
	
	multiplayer.multiplayer_peer = server_peer
	
	multiplayer.peer_connected.connect(_add_player_to_game)
	multiplayer.peer_disconnected.connect(_del_player)
	
	_add_player_to_game(1)
	
func join_as_player() -> void:
	var client_peer = ENetMultiplayerPeer.new()
	client_peer.create_client(SERVER_IP, SERVER_PORT)
	
	multiplayer.multiplayer_peer = client_peer
	
func game_entered_as_server() -> void:
	spawn_node = get_tree().get_current_scene().get_node("players")
	
	_add_player_to_game(1)
	_add_player_to_game(client_id)
	
func close_network() -> void:
	pass
	
func _add_player_to_game(id : int):
	var new_player = multiplayer_scene.instantiate()
	
	if id != 1:
		client_id = id
	
	new_player.player_id = id
	new_player.name = str(id)
	
	spawn_node.add_child(new_player, true)
	
func _del_player(id : int):
	pass
