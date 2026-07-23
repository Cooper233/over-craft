extends Node

const PORT := 12345
const MAX_PLAYERS := 4

var _last_scene: Node

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(_delta: float) -> void:
	var current = get_tree().current_scene
	if current == _last_scene:
		return
	_last_scene = current
	if current is LevelControllerBase:
		_on_level_loaded(current)

func _on_level_loaded(level: LevelControllerBase) -> void:
	if multiplayer.is_server():
		level.spawn_player(1, level.get_spawn_position(0))
	else:
		_rpc_map_ready.rpc_id(1)

func _spawn_for_peer(level: LevelControllerBase, peer_id: int) -> void:
	var pos = level.get_spawn_position(peer_id - 1)
	level.spawn_player(peer_id, pos)
	_rpc_spawn_player.rpc_id(peer_id, peer_id, pos)

func _sync_existing(level: LevelControllerBase, for_peer: int) -> void:
	for player in level.get_players():
		if player.player_owner_id != for_peer:
			_rpc_spawn_player.rpc_id(for_peer, player.player_owner_id, player.global_position)

func host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		push_error("Failed to create server: %d" % err)
		return
	multiplayer.multiplayer_peer = peer

func join(address: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		push_error("Failed to connect: %d" % err)
		return
	multiplayer.multiplayer_peer = peer

@rpc("any_peer", "reliable")
func _rpc_map_ready() -> void:
	var sender = multiplayer.get_remote_sender_id()
	var level = get_tree().current_scene as LevelControllerBase
	if not level:
		return
	_spawn_for_peer(level, sender)
	_sync_existing(level, sender)

@rpc("authority", "reliable")
func _rpc_spawn_player(for_peer: int, pos: Vector2) -> void:
	var level = get_tree().current_scene as LevelControllerBase
	if level:
		level.spawn_player(for_peer, pos)

func _on_peer_connected(peer_id: int) -> void:
	pass

func _on_peer_disconnected(peer_id: int) -> void:
	var level = get_tree().current_scene as LevelControllerBase
	if level:
		level.remove_player(peer_id)

func _on_server_disconnected() -> void:
	SceneLoader.load_scene("res://scenes/lobby.tscn")
